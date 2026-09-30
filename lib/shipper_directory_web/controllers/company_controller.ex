defmodule ShipperDirectoryWeb.CompanyController do
  use ShipperDirectoryWeb, :controller

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Directory.RoutePages
  alias ShipperDirectoryWeb.{DirectoryComponents, NotFoundError}

  # Only published companies have public pages. Prospects are private.
  def show(conn, %{"slug" => slug}) do
    company =
      case Directory.get_published_company(slug) do
        {:ok, company} -> company
        {:error, _} -> raise NotFoundError
      end

    routes =
      for m <- company.metro_slugs, d <- company.destination_slugs, do: RoutePages.build(m, d)

    location = DirectoryComponents.location(company)

    render(conn, :show,
      company: company,
      routes: routes,
      page_title: company.name,
      meta_description: meta_description(company, location),
      canonical_url: url(~p"/shippers/#{company.slug}"),
      json_ld: json_ld(company)
    )
  end

  defp meta_description(company, location) do
    where = if location, do: " (#{location})", else: ""

    to =
      case company.destinations do
        [] -> ""
        destinations -> " to " <> Enum.join(destinations, ", ")
      end

    "#{company.name}#{where}: Caribbean barrel and freight shipping#{to}."
  end

  defp json_ld(company) do
    %{
      "@context" => "https://schema.org",
      "@type" => "LocalBusiness",
      "name" => company.name,
      "url" => company.website_url,
      "telephone" => company.phone,
      "email" => company.email,
      "areaServed" => company.destinations,
      "address" =>
        if(company.city || company.address,
          do:
            %{
              "@type" => "PostalAddress",
              "streetAddress" => company.address,
              "addressLocality" => company.city,
              "addressRegion" => company.state,
              "addressCountry" => "US"
            }
            |> reject_nil()
        )
    }
    |> reject_nil()
  end

  defp reject_nil(map), do: map |> Enum.reject(fn {_, v} -> v in [nil, []] end) |> Map.new()
end
