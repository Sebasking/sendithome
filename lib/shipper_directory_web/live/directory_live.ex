defmodule ShipperDirectoryWeb.DirectoryLive do
  @moduledoc """
  Public home page: search published shippers by origin metro, destination,
  and service. Filters live in the URL (`/?from=brooklyn&to=guyana`), so
  every search is linkable.
  """
  use ShipperDirectoryWeb, :live_view

  import ShipperDirectoryWeb.DirectoryComponents
  import ShipperDirectoryWeb.HeroComponents

  alias ShipperDirectory.{Directory, Placements}
  alias ShipperDirectory.Directory.{Destinations, RoutePages}
  alias ShipperDirectory.Directory.Types.Service
  alias ShipperDirectory.Discovery.Metros

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       metros: Enum.map(Metros.all(), &{&1.name, &1.slug}),
       destinations: Enum.map(Destinations.all(), &{&1.name, &1.slug}),
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

    {sponsored, organic} = Placements.split(companies, filters["from"], filters["to"])

    {:noreply,
     assign(socket,
       filters: filters,
       form: to_form(filters, as: :search),
       companies: organic,
       sponsored: sponsored,
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
      <%!-- Always light: the video's own background is the brand ground color. --%>
      <section
        id="hero"
        class="grid items-center gap-6 rounded-3xl bg-brand-ground px-5 py-7 text-brand-ink sm:px-8 md:grid-cols-[2fr_3fr] md:gap-10 md:px-10 md:py-12"
      >
        <div>
          <h1 class="text-3xl font-bold tracking-tight text-balance sm:text-4xl lg:text-5xl">
            Find your Caribbean shipper
          </h1>
          <p class="mt-3 text-lg text-brand-muted">
            Compare barrel shippers near you, from pickup to delivery back home.
          </p>
          <div class="mt-6 flex flex-wrap items-center gap-x-6 gap-y-3">
            <%!-- /start lives in the cookie-free flow session, so a full page load. --%>
            <.link
              href={~p"/start"}
              id="hero-find-shipper"
              class="group inline-flex min-h-12 items-center gap-2 rounded-xl bg-brand-primary px-6 text-lg font-semibold text-white shadow-sm transition hover:bg-brand-ink hover:shadow-md focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-primary active:scale-[0.98]"
            >
              Find a shipper
              <.icon
                name="hero-arrow-right"
                class="size-5 transition-transform group-hover:translate-x-0.5"
              />
            </.link>
            <.link
              href={~p"/shippers"}
              id="hero-browse-shippers"
              class="font-semibold text-brand-primary underline-offset-4 transition hover:text-brand-ink hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-primary"
            >
              Browse all shippers
            </.link>
          </div>
        </div>
        <div class="min-w-0">
          <.hero_video />
        </div>
      </section>

      <section class="rounded-2xl border border-base-300 bg-base-100 px-5 py-5 sm:px-8">
        <h2 class="text-sm font-semibold uppercase tracking-wide opacity-70">
          Search the directory
        </h2>
        <.form
          for={@form}
          id="search"
          phx-change="search"
          phx-submit="search"
          class="mt-3 grid gap-3 sm:grid-cols-2"
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
        </.form>
      </section>

      <.sponsored_block companies={@sponsored} />

      <section class="space-y-4 pt-4">
        <div class="flex items-baseline justify-between">
          <h2 class="text-xl font-semibold">
            {length(@companies) + length(@sponsored)} {if length(@companies) + length(@sponsored) == 1,
              do: "shipper",
              else: "shippers"}
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
          :if={@companies == [] and @sponsored == []}
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
