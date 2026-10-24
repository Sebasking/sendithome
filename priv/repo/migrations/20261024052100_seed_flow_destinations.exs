defmodule ShipperDirectory.Repo.Migrations.SeedFlowDestinations do
  @moduledoc "The five destinations on the first screen of the QR flow, in launch order."

  use Ecto.Migration

  @destinations [
    {"jm", "jamaica", "Jamaica", 10},
    {"gy", "guyana", "Guyana", 20},
    {"tt", "trinidad-and-tobago", "Trinidad & Tobago", 30},
    {"bb", "barbados", "Barbados", 40},
    {"ht", "haiti", "Haiti", 50}
  ]

  def up do
    for {code, slug, name, sort_order} <- @destinations do
      execute(fn ->
        repo().query!(
          """
          INSERT INTO destinations (code, slug, name, sort_order)
          VALUES ($1, $2, $3, $4)
          ON CONFLICT (code) DO NOTHING
          """,
          [code, slug, name, sort_order]
        )
      end)
    end
  end

  def down do
    execute(fn ->
      repo().query!("DELETE FROM destinations WHERE code = ANY($1)", [
        Enum.map(@destinations, &elem(&1, 0))
      ])
    end)
  end
end
