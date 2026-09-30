defmodule Mix.Tasks.Directory.CheckPresence do
  @shortdoc "Runs the presence check now for every company and prints the verdicts"
  @moduledoc """
  Runs the presence check synchronously for every company (or those whose
  slug is given) and prints a table for spot-checking.

      mix directory.check_presence
      mix directory.check_presence fcs-shipping-llc quality-one-international
  """
  use Mix.Task

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Directory.Presence

  @requirements ["app.start"]

  @impl Mix.Task
  def run(slugs) do
    Directory.list_companies!()
    |> Enum.filter(&(slugs == [] or &1.slug in slugs))
    |> Enum.sort_by(& &1.name)
    |> Task.async_stream(&Presence.check/1, timeout: 60_000, max_concurrency: 8)
    |> Enum.each(fn {:ok, company} ->
      Mix.shell().info(
        String.pad_trailing(company.name, 40) <>
          String.pad_trailing(to_string(company.presence_status), 14) <>
          String.pad_trailing(to_string(company.status), 12) <> (company.review_reason || "")
      )
    end)
  end
end
