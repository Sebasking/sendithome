defmodule ShipperDirectory.Directory.Changes.ApplyOutreachOutcome do
  @moduledoc """
  Guards and side effects for logging an outreach event.

  Guards (compliance, spec section 8):
    * no outreach to companies on the suppression list (`do_not_contact`)
    * SMS/WhatsApp only after the company opted in (TCPA), with the
      opt-in itself recordable on any channel

  Side effects on the company:
    * any touch moves `prospect` → `contacted`
    * `not_interested` → `declined`, `customer` → `customer`,
      `do_not_contact` → `do_not_contact`
    * `opted_in_messaging` records the consent timestamp and note
  """
  use Ash.Resource.Change

  alias ShipperDirectory.Directory

  @messaging_channels [:sms, :whatsapp]

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.before_action(&guard/1)
    |> Ash.Changeset.after_action(fn _changeset, event ->
      company = Directory.get_company!(event.company_id)
      {:ok, _} = apply_outcome(company, event)
      {:ok, event}
    end)
  end

  defp guard(changeset) do
    company = Directory.get_company!(Ash.Changeset.get_attribute(changeset, :company_id))
    channel = Ash.Changeset.get_attribute(changeset, :channel)
    outcome = Ash.Changeset.get_attribute(changeset, :outcome)

    cond do
      company.status == :do_not_contact ->
        Ash.Changeset.add_error(changeset,
          field: :company_id,
          message: "is on the do-not-contact list"
        )

      channel in @messaging_channels and is_nil(company.messaging_consent_at) and
          outcome != :opted_in_messaging ->
        Ash.Changeset.add_error(changeset,
          field: :channel,
          message:
            "SMS/WhatsApp needs the company's prior opt-in (TCPA). Call, email, or visit instead."
        )

      true ->
        changeset
    end
  end

  defp apply_outcome(company, event) do
    updates =
      %{}
      |> put_status(company.status, event.outcome)
      |> put_consent(event)

    if updates == %{},
      do: {:ok, company},
      else: Directory.record_outreach_result(company, updates)
  end

  defp put_status(updates, _status, :do_not_contact),
    do: Map.put(updates, :status, :do_not_contact)

  defp put_status(updates, _status, :customer), do: Map.put(updates, :status, :customer)

  defp put_status(updates, status, :not_interested) when status in [:prospect, :contacted],
    do: Map.put(updates, :status, :declined)

  defp put_status(updates, :prospect, _outcome), do: Map.put(updates, :status, :contacted)
  defp put_status(updates, _status, _outcome), do: updates

  defp put_consent(updates, %{outcome: :opted_in_messaging} = event) do
    Map.merge(updates, %{
      messaging_consent_at: DateTime.utc_now(),
      messaging_consent_note: event.notes || "Opted in via #{event.channel}"
    })
  end

  defp put_consent(updates, _event), do: updates
end
