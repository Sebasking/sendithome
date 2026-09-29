defmodule ShipperDirectoryWeb.PageController do
  use ShipperDirectoryWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
