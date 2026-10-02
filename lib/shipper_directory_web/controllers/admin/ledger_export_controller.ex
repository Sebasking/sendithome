defmodule ShipperDirectoryWeb.Admin.LedgerExportController do
  use ShipperDirectoryWeb, :controller

  alias ShipperDirectory.Leads.Ledger

  def index(conn, params) do
    month = Ledger.parse_month(params["month"])
    label = Calendar.strftime(month, "%Y-%m")

    rows =
      Enum.map(Ledger.for_month(month), fn row ->
        [
          row.company.name,
          to_string(row.count),
          :erlang.float_to_binary(row.total_cents / 100, decimals: 2)
        ]
      end)

    csv = NimbleCSV.RFC4180.dump_to_iodata([["company", "leads", "total_usd"] | rows])

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="lead-ledger-#{label}.csv"))
    |> send_resp(200, csv)
  end
end
