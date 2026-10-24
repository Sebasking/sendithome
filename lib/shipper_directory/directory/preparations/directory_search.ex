defmodule ShipperDirectory.Directory.Preparations.DirectorySearch do
  @moduledoc """
  The optional filters of `Company.directory_search`:

    * `destination_code`: an active destination's code (`jm`). Companies are
      tagged with canonical destination slugs, so the code is looked up first.
      Unknown codes and `other` add no filter.
    * `area_slug`: a metro slug (`queens`).
    * `when: :christmas`: only companies whose Christmas cutoff is on or after
      `on`. A nil cutoff is unknown, so it's excluded rather than guessed.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  alias ShipperDirectory.Directory

  @impl true
  def prepare(query, _opts, _context) do
    arg = &Ash.Query.get_argument(query, &1)

    query
    |> filter_destination(arg.(:destination_code))
    |> filter_area(arg.(:area_slug))
    |> filter_timing(arg.(:when), arg.(:on))
  end

  defp filter_destination(query, nil), do: query

  defp filter_destination(query, code) do
    case Directory.get_active_destination(code) do
      {:ok, %{slug: slug}} ->
        Ash.Query.filter(query, fragment("? = ANY(?)", ^slug, destination_slugs))

      _ ->
        query
    end
  end

  defp filter_area(query, nil), do: query

  defp filter_area(query, slug),
    do: Ash.Query.filter(query, fragment("? = ANY(?)", ^slug, metro_slugs))

  defp filter_timing(query, :christmas, on),
    do: Ash.Query.filter(query, christmas_cutoff_date >= ^on)

  defp filter_timing(query, _when, _on), do: query
end
