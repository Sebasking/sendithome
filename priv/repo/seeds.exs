# Seeds the directory from priv/seed/shipper_seed_list.csv, then runs the
# presence checker so the 17 seed companies land as published, prospects,
# or in the review queue.
#
#     mix run priv/repo/seeds.exs
#
# Safe to rerun because the import dedupes. Set SKIP_PRESENCE_CHECK=1 when
# offline, or every site would be classified as dead.

alias ShipperDirectory.Directory
alias ShipperDirectory.Directory.Import.SeedCsv
alias ShipperDirectory.Directory.Presence

%{created: created, updated: updated} = SeedCsv.import!()
IO.puts("Seed CSV: #{created} created, #{updated} already present")

unless System.get_env("SKIP_PRESENCE_CHECK") do
  IO.puts("Running presence checks (this makes HTTP requests to each company site)...")

  Directory.list_companies!()
  |> Task.async_stream(&Presence.check/1, timeout: 60_000, max_concurrency: 8)
  |> Enum.map(fn {:ok, company} -> company end)
  |> Enum.sort_by(&{&1.status, &1.name})
  |> Enum.each(fn c ->
    IO.puts(
      "  #{String.pad_trailing(c.name, 40)} #{String.pad_trailing(to_string(c.presence_status), 13)} #{c.status}"
    )
  end)
end
