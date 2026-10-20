defmodule ShipperDirectory.Discovery.GooglePlaces do
  @moduledoc """
  Looks a company up on Google Places (New) Text Search to learn whether
  Google lists a website for it.

  Google's terms allow storing only the place ID indefinitely, so Google's
  content (name, phone, address, website URL) is used in memory to pick the
  right place and is never persisted. We keep the place ID and our derived
  `google_has_website` flag. An admin then opens the place in Google Maps and
  enters the website by hand, and the presence checker verifies it.

  Requires `GOOGLE_PLACES_API_KEY`. The field mask includes `websiteUri` and
  `nationalPhoneNumber`, which bills at the Text Search Enterprise SKU.
  """

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Directory.{Company, Normalize, Presence}

  @url "https://places.googleapis.com/v1/places:searchText"
  @field_mask "places.id,places.displayName,places.nationalPhoneNumber,places.websiteUri,places.businessStatus"

  @doc "Maps link for a stored place ID (safe to show; no Google content stored)."
  def maps_url(place_id), do: "https://www.google.com/maps/place/?q=place_id:#{place_id}"

  @doc "Looks the company up and records the result. Returns `{:ok, company}` or `{:error, reason}`."
  def enrich(%Company{} = company) do
    with {:ok, places} <- search(query(company)) do
      {:ok, record!(company, best_match(company, places))}
    end
  end

  def query(company) do
    [company.name, company.address, company.city, company.state]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(", ")
  end

  def search(text_query) do
    case api_key() do
      nil ->
        {:error, :missing_api_key}

      key ->
        [
          url: @url,
          json: %{textQuery: text_query, pageSize: 5},
          headers: [{"x-goog-api-key", key}, {"x-goog-fieldmask", @field_mask}],
          retry: :transient
        ]
        |> Keyword.merge(Application.get_env(:shipper_directory, :google_places_req_options, []))
        |> Req.post()
        |> case do
          {:ok, %{status: 200, body: body}} -> {:ok, Map.get(body, "places", [])}
          {:ok, %{status: status, body: body}} -> {:error, {:http, status, body}}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  The place that is this company: same phone, or its display name contains
  all of the company's distinctive name words. Nil when nothing matches
  confidently.
  """
  def best_match(company, places) do
    phone = Normalize.phone(company.phone)
    tokens = Normalize.distinctive_tokens(company.name)

    Enum.find(places, &(phone && Normalize.phone(&1["nationalPhoneNumber"]) == phone)) ||
      Enum.find(places, fn place ->
        words = place |> get_in(["displayName", "text"]) |> Normalize.name() |> String.split(" ")
        tokens != [] and Enum.all?(tokens, &(&1 in words))
      end)
  end

  defp record!(company, nil) do
    company
    |> Presence.transition(:needs_review, "Not found on Google Maps, look it up by hand")
    |> Map.merge(%{google_checked_at: DateTime.utc_now()})
    |> then(&Directory.record_google!(company, &1))
  end

  defp record!(company, place) do
    has_website = place["websiteUri"] not in [nil, ""]
    {verdict, reason} = verdict(company, place, has_website)

    company
    |> transition(verdict, reason)
    |> Map.merge(%{
      google_place_id: place["id"],
      google_has_website: has_website,
      google_checked_at: DateTime.utc_now()
    })
    |> then(&Directory.record_google!(company, &1))
  end

  # A closed business leaves the directory and the prospect list until a
  # person reviews it, website or not. CRM statuses (contacted, ...) stay.
  defp transition(company, :closed, reason) do
    %{
      presence_status: :needs_review,
      status:
        if(company.status in [:published, :verified, :prospect],
          do: :discovered,
          else: company.status
        ),
      review_reason: reason
    }
  end

  # A company that already has a website is the presence checker's
  # business, so only the Google fields change.
  defp transition(%Company{website_url: url} = company, _verdict, _reason) when is_binary(url) do
    Map.take(company, [:presence_status, :status, :review_reason])
  end

  defp transition(company, verdict, reason), do: Presence.transition(company, verdict, reason)

  defp verdict(company, place, has_website) do
    socials? = Enum.any?([company.facebook_url, company.instagram_url, company.yelp_url])

    cond do
      place["businessStatus"] == "CLOSED_PERMANENTLY" ->
        {:closed, "Google Maps says permanently closed"}

      has_website ->
        {:needs_review, "Google Maps lists a website. Open it and enter the URL"}

      socials? ->
        {:social_only, "No website on Google Maps"}

      true ->
        {:none, "No website on Google Maps"}
    end
  end

  defp api_key, do: Application.get_env(:shipper_directory, :google_places_api_key)
end
