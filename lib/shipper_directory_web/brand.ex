defmodule ShipperDirectoryWeb.Brand do
  @moduledoc """
  The active logo variant and its asset paths.

  Two logo candidates ship side by side under `priv/static/images/brand/`:
  `a` (Line barrel) and `b` (Barrel pin). Pick one with
  `config :shipper_directory, :logo_variant, :a | :b`, or the `LOGO_VARIANT`
  env var at runtime.
  """
  use ShipperDirectoryWeb, :verified_routes

  @variants [:a, :b]

  def variants, do: @variants

  def logo_variant do
    case Application.get_env(:shipper_directory, :logo_variant, :b) do
      variant when variant in @variants -> variant
      other -> raise ArgumentError, "unknown :logo_variant #{inspect(other)}"
    end
  end

  @doc "Static path for `file` in the active variant's brand folder, e.g. `asset(\"mark.svg\")`."
  def asset(file), do: ~p"/images/brand/#{logo_variant()}/#{file}"

  @doc "Absolute path on disk for `file` in the active variant's brand folder."
  def asset_file(file) do
    Application.app_dir(:shipper_directory, [
      "priv/static/images/brand",
      "#{logo_variant()}",
      file
    ])
  end
end
