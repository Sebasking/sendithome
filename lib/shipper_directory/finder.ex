defmodule ShipperDirectory.Finder do
  @moduledoc """
  The QR sticker onboarding flow: destination, then timing (only in the
  Christmas season), then filtered results. Results come from
  `Company.directory_search`; this module adds the area fallback and the
  single sponsored slot.

  Regular results are always ordered by name. Sponsorship decides only who
  fills the one featured card, never the order of the rest.
  """

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Directory.Normalize

  defp config(key), do: Application.fetch_env!(:shipper_directory, :finder)[key]

  def thin_threshold, do: config(:thin_results_threshold)
  def suggest_shipper_url, do: config(:suggest_shipper_url)
  def christmas_cutoff_display_date, do: config(:christmas_cutoff_display_date)

  @doc "Whether `today` is inside the configured Christmas window (inclusive)."
  def christmas_season?(today \\ Date.utc_today()) do
    Date.compare(today, config(:christmas_window_start)) != :lt and
      Date.compare(today, config(:christmas_window_end)) != :gt
  end

  @doc "Active destinations in screen-1 order."
  def destinations, do: Directory.active_destinations!()

  @doc "The active sticker source for a code, or nil."
  def sticker_source(nil), do: nil

  def sticker_source(code) do
    case Directory.get_active_sticker_source(String.downcase(code)) do
      {:ok, source} -> source
      _ -> nil
    end
  end

  @doc """
  Results for a destination (a `Destination` or nil for all), an area slug
  (or nil) and `when` (`:christmas` or `:any`).

  When fewer than `thin_threshold/0` shippers serve the area, the area is
  dropped (`area_fallback?: true`). Returns the sponsored shipper (or nil),
  the regular shippers without it, and `count` covering both.
  """
  def search(destination, area, when_, today \\ Date.utc_today()) do
    args = %{destination_code: destination && destination.code, when: when_, on: today}

    {shippers, area_used} =
      with area when is_binary(area) <- area,
           in_area = Directory.directory_search!(Map.put(args, :area_slug, area)),
           true <- length(in_area) >= thin_threshold() do
        {in_area, area}
      else
        _ -> {Directory.directory_search!(args), nil}
      end

    sponsored = sponsored(shippers, area, destination, today)

    %{
      sponsored: sponsored,
      shippers:
        if(sponsored, do: Enum.reject(shippers, &(&1.id == sponsored.id)), else: shippers),
      count: length(shippers),
      area: area_used,
      area_fallback?: is_binary(area) and is_nil(area_used)
    }
  end

  # At most one: active placements for the sticker's area and this
  # destination (or all destinations), whose shipper is already in the
  # filtered results. Several eligible sponsors take turns by day of year.
  defp sponsored(_shippers, nil, _destination, _today), do: nil

  defp sponsored(shippers, area, destination, today) do
    by_id = Map.new(shippers, &{&1.id, &1})
    slug = destination && destination.slug

    area
    |> Directory.active_placements!(slug, today)
    |> Enum.filter(&(is_nil(&1.destination) or &1.destination == slug))
    |> Enum.map(& &1.company_id)
    |> Enum.filter(&Map.has_key?(by_id, &1))
    |> Enum.uniq()
    |> Enum.sort()
    |> case do
      [] -> nil
      ids -> Map.fetch!(by_id, Enum.at(ids, rem(Date.day_of_year(today), length(ids))))
    end
  end

  @doc """
  Where a contact channel leads for a company, or nil when the company has
  no usable number or website for it.
  """
  def contact_target(company, :call) do
    case Normalize.phone(company.phone) do
      nil -> nil
      digits -> "tel:+1" <> digits
    end
  end

  def contact_target(company, :whatsapp) do
    case whatsapp_digits(company.whatsapp_number) do
      nil -> nil
      digits -> "https://wa.me/" <> digits
    end
  end

  def contact_target(%{website_url: "http" <> _ = url}, :website), do: url
  def contact_target(_company, :website), do: nil

  # wa.me wants the full international number, digits only. Ten digits is
  # a US number without its country code.
  defp whatsapp_digits(nil), do: nil

  defp whatsapp_digits(number) do
    case String.replace(number, ~r/\D/, "") do
      <<digits::binary-size(10)>> -> "1" <> digits
      digits when byte_size(digits) in 11..15 -> digits
      _ -> nil
    end
  end
end
