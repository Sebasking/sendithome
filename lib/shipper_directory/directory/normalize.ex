defmodule ShipperDirectory.Directory.Normalize do
  @moduledoc """
  Normalization used for deduplication and for matching a website back to a
  company. Dedupe key = normalized phone, else normalized name + address.
  """

  @legal_suffixes ~w(llc inc incorporated corp corporation co company ltd limited)

  # Words too common among shippers to identify one on its own.
  @generic_words ~w(
    shipping shippers shipper freight cargo caribbean international intl
    enterprises enterprise services service moving overseas delivery and the
    of global logistics express trading forwarding forwarders forwarder lines
    line import export consolidators
  ) ++ @legal_suffixes

  @street_abbreviations %{
    "avenue" => "ave",
    "street" => "st",
    "place" => "pl",
    "road" => "rd",
    "boulevard" => "blvd",
    "drive" => "dr",
    "parkway" => "pkwy",
    "suite" => "ste",
    "east" => "e",
    "west" => "w",
    "north" => "n",
    "south" => "s"
  }

  @doc "10-digit US phone number, or nil."
  def phone(nil), do: nil

  def phone(value) do
    case String.replace(value, ~r/\D/, "") do
      <<"1", rest::binary-size(10)>> -> rest
      <<digits::binary-size(10)>> -> digits
      _ -> nil
    end
  end

  @doc "Lowercased alphanumeric words with `&` spelled out and legal suffixes dropped."
  def name(nil), do: nil

  def name(value) do
    value
    |> words()
    |> Enum.reject(&(&1 in @legal_suffixes))
    |> Enum.join(" ")
  end

  def name_key(name, address, city, state) do
    location = [address(address), text(city), text(state)] |> Enum.reject(&(&1 == ""))
    Enum.join([name(name) | location], "|")
  end

  @doc ~s(Street address with common words abbreviated: "35 ROGERS AVENUE" -> "35 rogers ave".)
  def address(nil), do: ""

  def address(value) do
    value
    |> words()
    |> Enum.map_join(" ", &Map.get(@street_abbreviations, &1, &1))
  end

  def dedupe_key(phone, name_key) do
    case phone(phone) do
      nil -> "name:" <> name_key
      digits -> "phone:" <> digits
    end
  end

  @doc """
  The words that identify a company by name. Falls back to every word of the
  name when all of them are generic (e.g. "Caribbean Shipping Freight").
  """
  def distinctive_tokens(name) do
    all = name |> name() |> String.split(" ", trim: true)

    case Enum.reject(all, &(&1 in @generic_words)) do
      [] -> all
      tokens -> tokens
    end
  end

  @doc ~s(Sorted distinctive tokens, e.g. "dennis" for "DENNIS SHIPPING CO., INC.".)
  def name_core(nil), do: nil
  def name_core(name), do: name |> distinctive_tokens() |> Enum.sort() |> Enum.join(" ")

  @doc "Lowercased, alphanumeric-only text with collapsed whitespace."
  def text(nil), do: ""
  def text(value), do: value |> words() |> Enum.join(" ")

  def slug(name), do: name |> words() |> Enum.join("-")

  defp words(value) do
    value
    |> String.downcase()
    |> String.replace("&", " and ")
    |> String.replace(~r/['’]/u, "")
    |> String.replace(~r/[^a-z0-9]+/, " ")
    |> String.split(" ", trim: true)
  end
end
