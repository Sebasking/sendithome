defmodule ShipperDirectoryWeb.PageController do
  use ShipperDirectoryWeb, :controller

  alias ShipperDirectory.Directory

  def home(conn, _params) do
    render(conn, :home, companies: Directory.published_companies!())
  end
end
