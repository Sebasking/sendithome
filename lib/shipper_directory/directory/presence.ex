defmodule ShipperDirectory.Directory.Presence do
  @moduledoc """
  Decides whether a company has a real online presence (spec section 5).

    * `:listed`: own site returns 2xx with real content that shows the
      company's name or phone (or the domain carries its name) and isn't parked.
    * `:dead_site`: DNS/connection failure, 404/410/5xx, a parked or
      placeholder page, or a `business.site` URL (Google shut that product down).
    * `:social_only`: only Facebook/Instagram/Yelp URLs.
    * `:none`: no URL at all.
    * `:needs_review`: ambiguous. The site doesn't match the company, or it
      blocked us (401/403/429).

  `classify/2` does the pure work (no DB), and `check/2` also records a
  `PresenceCheck` and moves the company along its lifecycle.
  """

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Directory.{Company, Normalize}

  @social_hosts ~w(facebook.com fb.com instagram.com yelp.com)
  @dead_hosts ~w(business.site)
  @parking_hosts ~w(sedoparking.com parkingcrew.net hugedomains.com afternic.com dan.com bodis.com above.com parklogic.com)

  @parked_phrases [
    "domain is for sale",
    "domain may be for sale",
    "buy this domain",
    "this domain is parked",
    "parked free",
    "domain parking",
    "is available for purchase",
    "hugedomains",
    "sedo domain parking",
    "inquire about this domain"
  ]

  @placeholder_phrases [
    "coming soon",
    "under construction",
    "welcome to nginx",
    "apache2 default page",
    "it works!",
    "future home of",
    "website is under maintenance",
    "account suspended",
    "this site can’t be reached"
  ]

  @min_content_chars 200
  # A placeholder phrase only counts in the <title> or on a page this short.
  # Real sites mention "coming soon" for features ("Shipping Calculator:
  # Coming Soon").
  @short_page_chars 1500
  @phone_regex ~r/\(?\b\d{3}\)?[\s.\-]?\d{3}[\s.\-]\d{4}\b/

  @doc "Runs the check, records a PresenceCheck, and updates the company."
  def check(%Company{} = company, opts \\ []) do
    result = classify(company, opts)
    now = DateTime.utc_now()

    Directory.create_presence_check!(
      result
      |> Map.take([
        :url,
        :http_status,
        :final_url,
        :is_parked,
        :is_placeholder,
        :has_contact_info,
        :has_ssl,
        :matches_company,
        :verdict,
        :reason
      ])
      |> Map.merge(%{company_id: company.id, checked_at: now})
    )

    company
    |> transition(result.verdict, result.reason)
    |> Map.put(:last_checked_at, now)
    |> then(&Directory.record_presence!(company, &1))
  end

  @doc """
  The new presence_status, status, and review_reason for a verdict. Only
  directory-side statuses move. CRM statuses (contacted, customer, declined,
  do_not_contact) are left alone.
  """
  def transition(%Company{hold_for_review: true} = company, verdict, reason) do
    %{
      presence_status: :needs_review,
      status: if(company.status == :published, do: :discovered, else: company.status),
      review_reason: "Held for review; checker says #{verdict}: #{reason}"
    }
  end

  def transition(%Company{status: status}, :listed, _reason) do
    %{
      presence_status: :listed,
      status: if(status in [:discovered, :verified, :prospect], do: :published, else: status),
      review_reason: nil
    }
  end

  def transition(%Company{status: status}, :needs_review, reason) do
    %{
      presence_status: :needs_review,
      status: if(status == :published, do: :discovered, else: status),
      review_reason: reason
    }
  end

  # No usable website: a lead for outreach, but only if there's a way to reach
  # it (phone, email, a claimed owner, or the social profile that made it social_only).
  def transition(%Company{status: status} = company, verdict, _reason)
      when verdict in [:dead_site, :social_only, :none] do
    directory_side? = status in [:discovered, :verified, :published]

    cond do
      directory_side? and verdict != :social_only and not contactable?(company) ->
        %{
          presence_status: verdict,
          status: :discovered,
          review_reason: "No website, phone, or email, so it can't be worked as a lead"
        }

      directory_side? ->
        %{presence_status: verdict, status: :prospect, review_reason: nil}

      true ->
        %{presence_status: verdict, status: status, review_reason: nil}
    end
  end

  defp contactable?(company) do
    company.owner_id != nil or Enum.any?([company.phone, company.email], &(&1 not in [nil, ""]))
  end

  @doc "Classifies a company's online presence. Only makes HTTP requests for an own-domain URL."
  def classify(%Company{} = company, opts \\ []) do
    base = %{
      url: company.website_url,
      http_status: nil,
      final_url: nil,
      is_parked: false,
      is_placeholder: false,
      has_contact_info: false,
      has_ssl: false,
      matches_company: false
    }

    socials = [company.facebook_url, company.instagram_url, company.yelp_url]

    cond do
      blank?(company.website_url) and Enum.any?(socials, &(not blank?(&1))) ->
        verdict(base, :social_only, "Only social/listing URLs, no own domain")

      blank?(company.website_url) ->
        verdict(base, :none, "No URL from any source")

      host_in?(company.website_url, @social_hosts) ->
        verdict(base, :social_only, "Website URL is a social/listing page")

      host_in?(company.website_url, @dead_hosts) ->
        verdict(base, :dead_site, "business.site pages were shut down by Google")

      true ->
        company.website_url |> fetch(opts) |> classify_response(company, base)
    end
  end

  defp classify_response({:error, reason}, _company, base) do
    verdict(base, :dead_site, "Request failed: #{format_error(reason)}")
  end

  defp classify_response({:ok, %{status: status} = resp}, company, base) do
    final_url = resp.final_url
    base = %{base | http_status: status, final_url: final_url, has_ssl: https?(final_url)}

    cond do
      status in [401, 403, 429] ->
        verdict(base, :needs_review, "HTTP #{status}: site blocked the checker, verify by hand")

      status >= 400 ->
        verdict(base, :dead_site, "HTTP #{status}")

      status not in 200..299 ->
        verdict(base, :needs_review, "Unexpected HTTP #{status}")

      host_in?(final_url, @social_hosts) ->
        verdict(base, :social_only, "Website redirects to a social/listing page")

      host_in?(final_url, @dead_hosts) ->
        verdict(base, :dead_site, "Redirects to business.site")

      true ->
        classify_page(resp.body, final_url, company, base)
    end
  end

  defp classify_page(body, final_url, company, base) do
    page = parse_page(body)
    lower = String.downcase(page.text)

    parked? =
      host_in?(final_url, @parking_hosts) or
        Enum.any?(@parked_phrases, &String.contains?(lower, &1))

    length = String.length(page.text)
    title = String.downcase(page.title)

    placeholder? =
      length < @min_content_chars or
        Enum.any?(@placeholder_phrases, fn phrase ->
          String.contains?(title, phrase) or
            (length < @short_page_chars and String.contains?(lower, phrase))
        end)

    matches? = matches_company?(company, page, final_url)

    base = %{
      base
      | is_parked: parked?,
        is_placeholder: placeholder?,
        has_contact_info: page.has_contact_info,
        matches_company: matches?
    }

    cond do
      parked? ->
        verdict(base, :dead_site, "Parked domain")

      placeholder? ->
        verdict(base, :dead_site, "Placeholder or empty page")

      not matches? ->
        verdict(base, :needs_review, "Page doesn't show the company's name or phone")

      true ->
        verdict(base, :listed, "Live site with company identity")
    end
  end

  @doc false
  def matches_company?(company, page, final_url) do
    tokens = Normalize.distinctive_tokens(company.name)
    page_words = page.text |> Normalize.text() |> String.split(" ") |> MapSet.new()
    host = final_url |> host() |> String.replace(~r/[^a-z0-9]/, "")

    phone_on_page? =
      case Normalize.phone(company.phone) do
        nil -> false
        digits -> String.contains?(page.digits, digits)
      end

    name_on_page? = tokens != [] and Enum.all?(tokens, &MapSet.member?(page_words, &1))
    name_in_host? = tokens != [] and String.contains?(host, Enum.join(tokens))

    phone_on_page? or name_on_page? or name_in_host?
  end

  defp parse_page(body) when is_binary(body) do
    case Floki.parse_document(body) do
      {:ok, doc} ->
        doc = Floki.filter_out(doc, "script, style, noscript")
        text = doc |> Floki.text(sep: " ") |> String.replace(~r/\s+/u, " ") |> String.trim()
        hrefs = doc |> Floki.attribute("a", "href") |> Enum.join(" ")

        %{
          text: text,
          title: doc |> Floki.find("title") |> Floki.text() |> String.trim(),
          digits: String.replace(text <> " " <> hrefs, ~r/\D/, ""),
          has_contact_info:
            Regex.match?(@phone_regex, text) or String.contains?(hrefs, ["mailto:", "tel:"])
        }

      _ ->
        parse_page("")
    end
  end

  defp parse_page(_), do: %{text: "", title: "", digits: "", has_contact_info: false}

  defp fetch(url, opts) do
    req_options =
      [
        url: url,
        redirect: true,
        max_redirects: 5,
        receive_timeout: 10_000,
        connect_options: [timeout: 10_000],
        retry: :transient,
        max_retries: 2,
        decode_body: false,
        headers: [user_agent: "ShipperDirectoryBot/0.1 (presence check)"]
      ]
      |> Keyword.merge(Application.get_env(:shipper_directory, :presence_req_options, []))
      |> Keyword.merge(Keyword.get(opts, :req_options, []))

    case req_options |> Req.new() |> Req.Request.run_request() do
      {final_request, %Req.Response{} = resp} ->
        {:ok,
         %{status: resp.status, body: resp.body, final_url: URI.to_string(final_request.url)}}

      {_request, exception} ->
        {:error, exception}
    end
  rescue
    e -> {:error, e}
  end

  defp format_error(%{reason: reason}), do: inspect(reason)
  defp format_error(%{__exception__: true} = e), do: Exception.message(e)
  defp format_error(other), do: inspect(other)

  defp verdict(base, verdict, reason), do: Map.merge(base, %{verdict: verdict, reason: reason})

  defp host(nil), do: ""

  defp host(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> String.downcase(host)
      _ -> ""
    end
  end

  defp host_in?(url, domains) do
    h = host(url)
    Enum.any?(domains, &(h == &1 or String.ends_with?(h, "." <> &1)))
  end

  defp https?(url), do: String.starts_with?(url || "", "https://")

  defp blank?(value), do: value in [nil, ""]
end
