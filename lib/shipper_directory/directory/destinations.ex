defmodule ShipperDirectory.Directory.Destinations do
  @moduledoc """
  Canonical destinations for search and SEO routes. Company destinations
  are free text ("T&T", "Trinidad & Tobago", "DR"), so each alias maps to
  one slug. A generic "Caribbean" maps to nothing, because a route page
  only lists companies that explicitly name the destination.
  """

  @destinations [
    {"jamaica", "Jamaica", ~w(jamaica ja)},
    {"guyana", "Guyana", ~w(guyana)},
    {"trinidad-and-tobago", "Trinidad & Tobago",
     ["trinidad", "tobago", "t&t", "t and t", "trinidad & tobago", "trinidad and tobago"]},
    {"barbados", "Barbados", ~w(barbados)},
    {"st-lucia", "St. Lucia", ["st. lucia", "st lucia", "saint lucia"]},
    {"grenada", "Grenada", ~w(grenada)},
    {"antigua", "Antigua & Barbuda", ["antigua", "antigua & barbuda", "antigua and barbuda"]},
    {"st-vincent", "St. Vincent & the Grenadines",
     ["st. vincent", "st vincent", "saint vincent", "svg", "st. vincent & the grenadines"]},
    {"st-kitts-and-nevis", "St. Kitts & Nevis",
     ["st. kitts", "st kitts", "nevis", "st. kitts & nevis"]},
    {"dominica", "Dominica", ~w(dominica)},
    {"dominican-republic", "Dominican Republic",
     ["dominican republic", "dr", "republica dominicana"]},
    {"haiti", "Haiti", ~w(haiti)},
    {"bahamas", "Bahamas", ["bahamas", "the bahamas"]},
    {"suriname", "Suriname", ~w(suriname)},
    {"belize", "Belize", ~w(belize)},
    {"cayman-islands", "Cayman Islands", ["cayman", "cayman islands", "grand cayman"]},
    {"puerto-rico", "Puerto Rico", ["puerto rico"]},
    {"panama", "Panama", ~w(panama)}
  ]

  @by_alias for {slug, _name, aliases} <- @destinations,
                alias <- aliases,
                into: %{},
                do: {alias, slug}

  def all, do: Enum.map(@destinations, fn {slug, name, _} -> %{slug: slug, name: name} end)
  def slugs, do: Enum.map(@destinations, &elem(&1, 0))

  def name(slug) do
    case List.keyfind(@destinations, slug, 0) do
      {_, name, _} -> name
      nil -> nil
    end
  end

  @doc ~s(Canonical slugs for free-text destinations: ["T&T", "Jamaica + more"] -> ["trinidad-and-tobago", "jamaica"].)
  def slugs_for(values) do
    values
    |> Enum.map(&(&1 |> String.downcase() |> String.trim()))
    |> Enum.map(&Map.get(@by_alias, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end
end
