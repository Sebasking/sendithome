defmodule ShipperDirectoryWeb.RouteController do
  use ShipperDirectoryWeb, :controller

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Directory.RoutePages
  alias ShipperDirectoryWeb.NotFoundError

  def index(conn, _params) do
    routes = RoutePages.available()

    render(conn, :index,
      by_metro: routes |> Enum.group_by(& &1.metro_name) |> Enum.sort_by(&elem(&1, 0)),
      page_title: "Barrel shipping routes",
      meta_description:
        "Every Caribbean barrel shipping route in our directory, from New York, New Jersey, Florida, Connecticut, and Boston.",
      canonical_url: url(~p"/ship-barrel")
    )
  end

  def show(conn, %{"route" => slug}) do
    {metro, destination} =
      case RoutePages.parse(slug) do
        {:ok, metro, destination} -> {metro, destination}
        :error -> raise NotFoundError
      end

    companies = Directory.search_companies!(%{metro: metro, destination: destination})
    if companies == [], do: raise(NotFoundError)

    route = RoutePages.build(metro, destination, length(companies))
    available = RoutePages.available()

    render(conn, :show,
      route: route,
      companies: companies,
      same_origin: Enum.filter(available, &(&1.metro == metro and &1.destination != destination)),
      same_destination:
        Enum.filter(available, &(&1.destination == destination and &1.metro != metro)),
      page_title: "Ship a barrel from #{route.metro_name} to #{route.destination_name}",
      meta_description:
        "#{length(companies)} barrel #{if length(companies) == 1, do: "shipper", else: "shippers"} from #{route.metro_name} to #{route.destination_name}, each with a verified website. Compare and contact them directly.",
      canonical_url: url(~p"/ship-barrel/#{route.slug}")
    )
  end
end
