defmodule ShipperDirectoryWeb.Admin.ProspectExportController do
  use ShipperDirectoryWeb, :controller

  alias ShipperDirectory.Directory

  @columns ~w(name phone email address city state origin_metros destinations presence_status status facebook_url yelp_url notes)a

  # Prospects are status prospect/contacted only, so do_not_contact is never exported.
  def index(conn, _params) do
    rows =
      Enum.map(Directory.prospects!(), fn company ->
        Enum.map(@columns, &format(Map.get(company, &1)))
      end)

    csv = NimbleCSV.RFC4180.dump_to_iodata([Enum.map(@columns, &to_string/1) | rows])

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header(
      "content-disposition",
      ~s(attachment; filename="prospects-#{Date.utc_today()}.csv")
    )
    |> send_resp(200, csv)
  end

  defp format(nil), do: ""
  defp format(list) when is_list(list), do: Enum.join(list, "; ")
  defp format(value), do: to_string(value)
end
