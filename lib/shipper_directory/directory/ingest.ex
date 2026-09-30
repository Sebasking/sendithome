defmodule ShipperDirectory.Directory.Ingest do
  @moduledoc """
  One path for every source (seed CSV, FMC, ...) to add or update a company.

  Matching, in order:
    1. A Sighting for the same `{source, external_id}`: the same company as last time.
    2. Normalized phone, or normalized name + address (the spec's dedupe key).
    3. Otherwise a new company. If one with the same distinctive name words
       exists (e.g. "Dennis Shipping" vs "DENNIS SHIPPING CO., INC."), and
       their states don't conflict, the new one is flagged as a possible
       duplicate for the admin to merge or dismiss.

  Updating an existing company only fills blank fields and unions the list
  fields. It never touches status, so excluded or do-not-contact companies
  stay that way.
  """

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Directory.Normalize

  @list_fields [:source, :origin_metros, :destinations]
  @fill_fields [:phone, :email, :address, :city, :state, :website_url, :fmc_license_no, :notes]

  @doc "Returns `{:created | :updated, company}`."
  def ingest!(attrs, source, external_id, raw_payload) do
    {result, company} =
      case find_existing(attrs, source, external_id) do
        nil -> {:created, create!(attrs)}
        existing -> {:updated, merge!(existing, attrs)}
      end

    Directory.record_sighting!(%{
      source: source,
      external_id: external_id,
      raw_payload: raw_payload,
      company_id: company.id
    })

    {result, company}
  end

  @doc "Record another source's sighting on a known company, filling blanks."
  def attach!(company, attrs, source, external_id, raw_payload) do
    company = merge!(company, attrs)

    Directory.record_sighting!(%{
      source: source,
      external_id: external_id,
      raw_payload: raw_payload,
      company_id: company.id
    })

    company
  end

  defp find_existing(attrs, source, external_id) do
    case Directory.get_sighting(source, external_id, load: [:company]) do
      {:ok, sighting} ->
        sighting.company

      _ ->
        phone = Normalize.phone(attrs[:phone])
        name_key = Normalize.name_key(attrs.name, attrs[:address], attrs[:city], attrs[:state])
        phone |> Directory.find_matching_companies!(name_key) |> List.first()
    end
  end

  defp create!(attrs) do
    attrs
    |> Map.put(:possible_duplicate_of_id, possible_duplicate_id(attrs))
    |> Map.put_new(:slug, unique_slug(attrs.name, attrs[:city]))
    |> Directory.create_company!()
  end

  defp possible_duplicate_id(attrs) do
    attrs.name
    |> Normalize.name_core()
    |> Directory.companies_by_name_core!()
    |> Enum.find(&(same_state?(&1, attrs) and not distinct_entities?(&1, attrs)))
    |> case do
      nil -> nil
      company -> company.id
    end
  end

  defp same_state?(company, attrs),
    do: is_nil(company.state) or is_nil(attrs[:state]) or company.state == attrs[:state]

  # Two fully specified records with different phones and different
  # addresses are separate businesses (e.g. two FMC licensees "Compass
  # Shipping" and "Compass Forwarding"). Only an under-specified record, like
  # a seed row with no phone, gets flagged.
  defp distinct_entities?(company, attrs) do
    differs? = fn a, b -> a not in [nil, ""] and b not in [nil, ""] and a != b end

    differs?.(company.normalized_phone, Normalize.phone(attrs[:phone])) and
      differs?.(Normalize.address(company.address), Normalize.address(attrs[:address]))
  end

  # FMC has companies with the same name in different cities.
  defp unique_slug(name, city) do
    base = Normalize.slug(name)

    [base, Normalize.slug("#{name} #{city}")]
    |> Enum.concat(Stream.map(2..50, &"#{base}-#{&1}"))
    |> Enum.find(&match?({:error, _}, Directory.get_company_by_slug(&1)))
  end

  def merge!(existing, attrs) do
    lists =
      Map.new(@list_fields, fn field ->
        {field, Enum.uniq(Map.get(existing, field) ++ Map.get(attrs, field, []))}
      end)

    blanks =
      for field <- @fill_fields,
          Map.get(existing, field) in [nil, ""],
          value = Map.get(attrs, field),
          value not in [nil, ""],
          into: %{},
          do: {field, value}

    Directory.update_company!(existing, Map.merge(lists, blanks))
  end
end
