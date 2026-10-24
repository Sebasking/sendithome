defmodule ShipperDirectory.Directory.Types.Metro do
  @moduledoc "An origin metro slug (`queens`), from `Discovery.Metros`. Values stay strings."
  alias ShipperDirectory.Discovery.Metros

  use Ash.Type.Enum, values: Metros.slugs()

  @impl true
  def label(slug), do: Metros.name(slug)

  # Name the valid slugs instead of Ash's bare "is invalid".
  @impl true
  def match(value) do
    with :error <- super(value) do
      {:error, message: "must be one of: " <> Enum.join(Metros.slugs(), ", ")}
    end
  end
end
