defmodule Mix.Tasks.Directory.GoogleLookup do
  @shortdoc "Looks up confirmed companies without a website on Google Places"
  @moduledoc """
  Runs the Google Places lookup now (not via Oban) for every confirmed
  company without a website that hasn't been looked up yet. Needs
  GOOGLE_PLACES_API_KEY.

      mix directory.google_lookup
      mix directory.google_lookup --limit 10
  """
  use Mix.Task

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Discovery.GooglePlaces

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [limit: :integer])

    Directory.companies_needing_google_lookup!()
    |> Enum.take(opts[:limit] || 1_000_000)
    |> Enum.each(fn company ->
      case GooglePlaces.enrich(company) do
        {:ok, c} ->
          Mix.shell().info(
            "#{String.pad_trailing(c.name, 45)} #{c.google_has_website} #{c.review_reason}"
          )

        {:error, :missing_api_key} ->
          Mix.raise("GOOGLE_PLACES_API_KEY is not set")

        {:error, reason} ->
          Mix.shell().error("#{company.name}: #{inspect(reason)}")
      end
    end)
  end
end
