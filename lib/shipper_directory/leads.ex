defmodule ShipperDirectory.Leads do
  @moduledoc """
  Pay-per-lead quote requests (spec section 9.2).

  Who gets leads: only **published, claimed listings whose owner opted in**
  (`accepts_leads`), so nobody is billed without agreeing. The price comes
  from `config :shipper_directory, :lead_price_cents` and is fixed on each
  `LeadDelivery` when the lead is sent.

  Consent: the consumer picks the shippers (up to #{3}) before submitting,
  and the consent text naming exactly those shippers is built here, not
  taken from the form, and stored on the lead. Each request reaches only
  the shippers the consumer named.

  Abuse: a hidden honeypot field (bots fill it, and we pretend to accept),
  and at most 3 requests per email/phone per 24 hours.
  """

  alias ShipperDirectory.{Directory, Mailer, Repo}
  alias ShipperDirectory.Directory.{Company, Destinations, Normalize}
  alias ShipperDirectory.Discovery.Metros
  alias ShipperDirectory.Leads.Emails

  @max_companies 3
  @max_per_contact_per_day 3

  def max_companies, do: @max_companies
  def price_cents, do: Application.get_env(:shipper_directory, :lead_price_cents, 0)

  @doc "Companies that can receive leads, optionally for one route."
  def eligible(metro \\ nil, destination \\ nil) do
    Directory.lead_eligible_companies!(%{metro: metro, destination: destination})
  end

  def eligible?(%Company{status: :published, accepts_leads: true, owner_id: owner})
      when not is_nil(owner),
      do: true

  def eligible?(_company), do: false

  def consent_text(companies) do
    "By sending this request, I agree that #{names(companies)} may contact me by phone call, " <>
      "text message, or email about this shipment, including by automated means. " <>
      "Agreeing isn't a condition of any purchase."
  end

  @doc """
  Submits a quote request to the chosen companies. `params` has string keys
  for the Lead fields plus the `"website"` honeypot. Returns `{:ok, lead}`,
  `{:ok, :ignored}` for honeypot hits, or `{:error, reason}`.
  """
  def submit(params, company_ids, opts \\ []) do
    with :ok <- check_honeypot(params),
         {:ok, companies} <- load_companies(company_ids),
         :ok <- check_rate_limit(params) do
      create_and_send(params, companies, opts)
    end
  end

  defp create_and_send(params, companies, opts) do
    attrs =
      params
      |> Map.take(
        ~w(name email phone origin_metro destination barrels boxes other_items pickup_needed ship_by notes)
      )
      |> Map.reject(fn {_, v} -> v in [nil, ""] end)
      |> Map.put("consent_text", consent_text(companies))
      |> Map.put("source_path", opts[:source_path])

    case Repo.transaction(fn -> insert!(attrs, companies) end) do
      {:ok, {lead, deliveries}} ->
        notify(lead, deliveries, companies)
        {:ok, lead}

      {:error, error} ->
        {:error, error}
    end
  end

  defp insert!(attrs, companies) do
    case Directory.create_lead(attrs) do
      {:ok, lead} -> {lead, Enum.map(companies, &deliver!(lead, &1))}
      {:error, error} -> Repo.rollback(error)
    end
  end

  defp deliver!(lead, company) do
    Directory.create_lead_delivery!(%{
      lead_id: lead.id,
      company_id: company.id,
      price_cents: price_cents(),
      sent_to: to_string(company.owner.email)
    })
  end

  defp notify(lead, deliveries, companies) do
    by_id = Map.new(companies, &{&1.id, &1})

    for delivery <- deliveries do
      Mailer.deliver(Emails.new_lead(delivery, lead, by_id[delivery.company_id]))
    end

    if lead.email, do: Mailer.deliver(Emails.confirmation(lead, companies))
    :ok
  end

  defp check_honeypot(params) do
    if params["website"] in [nil, ""], do: :ok, else: {:ok, :ignored}
  end

  defp load_companies(ids) do
    ids = ids |> List.wrap() |> Enum.uniq()

    companies =
      ids
      |> Enum.map(&Directory.get_company/1)
      |> Enum.flat_map(fn
        {:ok, company} -> [company]
        _ -> []
      end)
      # The owner's email is where leads go. User has policies, and this is server-side.
      |> Ash.load!(:owner, authorize?: false)

    cond do
      ids == [] ->
        {:error, :no_companies}

      length(ids) > @max_companies ->
        {:error, :too_many_companies}

      length(companies) != length(ids) or not Enum.all?(companies, &eligible?/1) ->
        {:error, :ineligible_company}

      true ->
        {:ok, companies}
    end
  end

  defp check_rate_limit(params) do
    email = blank_to_nil(params["email"])
    phone = Normalize.phone(params["phone"])

    if is_nil(email) and is_nil(phone) do
      :ok
    else
      recent =
        Directory.recent_leads_from_contact!(%{
          email: email,
          phone: phone,
          since: DateTime.add(DateTime.utc_now(), -1, :day)
        })

      if length(recent) >= @max_per_contact_per_day, do: {:error, :rate_limited}, else: :ok
    end
  end

  def route_label(lead),
    do: "#{Metros.name(lead.origin_metro)} → #{Destinations.name(lead.destination)}"

  def items_label(lead) do
    [
      lead.barrels > 0 && "#{lead.barrels} #{if lead.barrels == 1, do: "barrel", else: "barrels"}",
      lead.boxes > 0 && "#{lead.boxes} #{if lead.boxes == 1, do: "box", else: "boxes"}",
      lead.other_items
    ]
    |> Enum.filter(& &1)
    |> Enum.join(", ")
  end

  def format_price(cents), do: "$" <> :erlang.float_to_binary(cents / 100, decimals: 2)

  defp names([one]), do: one.name

  defp names(companies),
    do:
      (companies |> Enum.drop(-1) |> Enum.map_join(", ", & &1.name)) <>
        " and " <> List.last(companies).name

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  def error_message(:no_companies), do: "Choose at least one shipper."
  def error_message(:too_many_companies), do: "Choose up to #{@max_companies} shippers."

  def error_message(:ineligible_company),
    do: "One of those shippers isn't taking requests right now."

  def error_message(:rate_limited),
    do: "You've sent several requests today. Please contact shippers directly."

  def error_message(%Ash.Error.Invalid{errors: errors}),
    do: Enum.map_join(errors, " ", &Exception.message/1)

  def error_message(_), do: "Something went wrong. Please try again."
end
