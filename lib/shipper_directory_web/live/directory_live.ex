defmodule ShipperDirectoryWeb.DirectoryLive do
  @moduledoc """
  Public home page: search published shippers by origin metro, destination,
  and service. Filters live in the URL (`/?from=brooklyn&to=guyana`), so
  every search is linkable.
  """
  use ShipperDirectoryWeb, :live_view

  import ShipperDirectoryWeb.DirectoryComponents

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Directory.{Destinations, RoutePages}
  alias ShipperDirectory.Directory.Types.Service
  alias ShipperDirectory.Discovery.Metros

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       metros: Enum.map(Metros.all(), &{&1.name, &1.slug}),
       destinations: Enum.map(Destinations.all(), &{&1.name, &1.slug}),
       services: Enum.map(Service.values(), &{&1 |> to_string() |> String.capitalize(), &1}),
       routes: RoutePages.available() |> Enum.take(12),
       page_title: "Find a Caribbean barrel shipper",
       meta_description:
         "Search Caribbean barrel and freight shippers in New York, New Jersey, Florida, Connecticut, and Boston. Every listed shipper has a verified, working website."
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = %{
      "from" => valid(params["from"], Metros.slugs()),
      "to" => valid(params["to"], Destinations.slugs()),
      "service" => valid(params["service"], Enum.map(Service.values(), &to_string/1))
    }

    companies =
      Directory.search_companies!(%{
        metro: filters["from"],
        destination: filters["to"],
        service: filters["service"]
      })

    {:noreply,
     assign(socket,
       filters: filters,
       form: to_form(filters, as: :search),
       companies: companies,
       canonical_url: canonical_url(filters)
     )}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    query =
      search |> Map.take(~w(from to service)) |> Enum.reject(fn {_, v} -> v in [nil, ""] end)

    {:noreply, push_patch(socket, to: ~p"/?#{query}")}
  end

  defp valid(value, allowed), do: if(value in allowed, do: value)

  # A from+to search has a dedicated SEO page, so that page is canonical.
  defp canonical_url(%{"from" => from, "to" => to, "service" => nil})
       when is_binary(from) and is_binary(to),
       do: url(~p"/ship-barrel/#{RoutePages.slug(from, to)}")

  defp canonical_url(_filters), do: url(~p"/")

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <section class="rounded-3xl bg-gradient-to-br from-primary/15 via-base-200 to-base-100 px-6 py-10 sm:px-10">
        <h1 class="max-w-2xl text-3xl font-bold tracking-tight sm:text-4xl">
          Ship a barrel home to the Caribbean
        </h1>
        <p class="mt-3 max-w-2xl text-base opacity-80">
          Find barrel and freight shippers near you. Every listed shipper has a working website we've checked.
        </p>

        <.form
          for={@form}
          id="search"
          phx-change="search"
          phx-submit="search"
          class="mt-6 grid gap-3 sm:grid-cols-3"
        >
          <.input
            field={@form[:from]}
            type="select"
            label="Shipping from"
            prompt="Anywhere"
            options={@metros}
          />
          <.input
            field={@form[:to]}
            type="select"
            label="Shipping to"
            prompt="Any destination"
            options={@destinations}
          />
          <.input
            field={@form[:service]}
            type="select"
            label="Service"
            prompt="Any service"
            options={@services}
          />
        </.form>
      </section>

      <section class="space-y-4 pt-4">
        <div class="flex items-baseline justify-between">
          <h2 class="text-xl font-semibold">
            {length(@companies)} {if length(@companies) == 1, do: "shipper", else: "shippers"}
          </h2>
          <.link
            :if={@filters != %{"from" => nil, "to" => nil, "service" => nil}}
            patch={~p"/"}
            class="text-sm link"
          >
            Clear filters
          </.link>
        </div>

        <div id="results" class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <.company_card :for={company <- @companies} company={company} />
        </div>

        <div
          :if={@companies == []}
          class="rounded-2xl border border-dashed border-base-300 p-10 text-center"
        >
          <p class="font-medium">No listed shippers match yet.</p>
          <p class="mt-1 text-sm opacity-70">
            Try a nearby area or "Any destination". We add shippers as we verify them.
          </p>
        </div>
      </section>

      <div class="pt-6">
        <.route_links routes={@routes} title="Popular routes" />
      </div>
    </Layouts.app>
    """
  end
end
