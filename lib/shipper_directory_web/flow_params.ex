defmodule ShipperDirectoryWeb.FlowParams do
  @moduledoc """
  Query params the QR flow carries untouched from step to step: the sticker
  source (`src`) and the UTM params, so a scan, its answers and its contact
  clicks can be attributed end to end (including the logo A/B test,
  `utm_content=logo_a|logo_b`). Values are trimmed and capped before
  they're linked or logged.
  """

  alias ShipperDirectoryWeb.Brand

  @utm ~w(utm_source utm_medium utm_campaign utm_content)

  @doc "The `src` and UTM params present in `params`, as a string-keyed map."
  def carry(params) do
    for key <- ["src" | @utm], value = clean(params[key]), into: %{}, do: {key, value}
  end

  @doc "A trimmed param capped at 100 characters, or nil when blank or not a string."
  def clean(value) when is_binary(value) do
    case value |> String.trim() |> String.slice(0, 100) do
      "" -> nil
      value -> value
    end
  end

  def clean(_value), do: nil

  @doc """
  Query params for a flow link: `carry` plus `extra` (nil values dropped),
  sorted so URLs are stable. Use with verified routes:
  `~p"/shippers?\#{query(carry, to: "jm")}"`.
  """
  def query(carry, extra \\ []) do
    extra
    |> Enum.reduce(carry, fn {key, value}, acc -> Map.put(acc, to_string(key), value) end)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.sort()
  end

  @doc "ScanEvent attributes for the carried params."
  def scan_attrs(carry) do
    %{
      source_code: carry["src"],
      utm_source: carry["utm_source"],
      utm_medium: carry["utm_medium"],
      utm_campaign: carry["utm_campaign"],
      utm_content: carry["utm_content"]
    }
  end

  @doc """
  The logo variant a visitor saw on their sticker, from the source or
  `utm_content`. Visitors who didn't come from a sticker (say, from the home
  page) get the site's own logo, so it doesn't change under them.
  """
  def logo_variant(%{logo_variant: variant}, _carry) when variant in [:a, :b], do: variant
  def logo_variant(_sticker, %{"utm_content" => "logo_a"}), do: :a
  def logo_variant(_sticker, %{"utm_content" => "logo_b"}), do: :b
  def logo_variant(_sticker, _carry), do: Brand.logo_variant()
end
