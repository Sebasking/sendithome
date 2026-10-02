defmodule ShipperDirectoryWeb.DirectoryComponents do
  @moduledoc "Components shared by the public directory pages."
  use ShipperDirectoryWeb, :html

  alias ShipperDirectory.Discovery.Metros

  attr :company, :map, required: true

  def company_card(assigns) do
    ~H"""
    <article class="group flex flex-col rounded-2xl border border-base-300 bg-base-100 p-5 transition hover:-translate-y-0.5 hover:border-primary/40 hover:shadow-lg">
      <div class="flex items-start justify-between gap-3">
        <h3 class="text-lg font-semibold leading-snug">
          <.link navigate={~p"/shippers/#{@company.slug}"} class="hover:text-primary">
            {@company.name}
          </.link>
        </h3>
        <.fmc_badge company={@company} />
      </div>
      <p :if={location(@company)} class="mt-1 text-sm opacity-70">
        <.icon name="hero-map-pin-micro" class="size-4 -mt-0.5" /> {location(@company)}
      </p>
      <div :if={@company.destinations != []} class="mt-3 flex flex-wrap gap-1.5">
        <span
          :for={destination <- @company.destinations}
          class="rounded-full bg-base-200 px-2.5 py-0.5 text-xs font-medium"
        >
          {destination}
        </span>
      </div>
      <div :if={@company.services != []} class="mt-2 flex flex-wrap gap-1.5">
        <span
          :for={service <- @company.services}
          class="rounded-full border border-base-300 px-2.5 py-0.5 text-xs capitalize"
        >
          {service}
        </span>
      </div>
      <div class="mt-auto flex flex-wrap items-center gap-x-4 gap-y-2 pt-5 text-sm">
        <a
          :if={@company.phone}
          href={"tel:" <> String.replace(@company.phone, ~r/[^\d+]/, "")}
          class="inline-flex items-center gap-1 hover:text-primary"
        >
          <.icon name="hero-phone-micro" class="size-4" /> {@company.phone}
        </a>
        <a
          href={@company.website_url}
          target="_blank"
          rel="noopener"
          class="ml-auto inline-flex items-center gap-1 font-medium text-primary hover:underline"
        >
          Website <.icon name="hero-arrow-top-right-on-square-micro" class="size-4" />
        </a>
      </div>
    </article>
    """
  end

  attr :companies, :list, required: true

  def sponsored_block(assigns) do
    ~H"""
    <section :if={@companies != []} id="sponsored" class="space-y-3">
      <h2 class="text-xs font-semibold uppercase tracking-wide opacity-60">Sponsored</h2>
      <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <div :for={company <- @companies} class="relative">
          <span class="absolute right-3 -top-2 z-[1] rounded-full bg-warning px-2 py-0.5 text-[10px] font-semibold uppercase text-warning-content">
            Sponsored
          </span>
          <.company_card company={company} />
        </div>
      </div>
    </section>
    """
  end

  attr :company, :map, required: true

  def fmc_badge(assigns) do
    ~H"""
    <span
      :if={@company.fmc_license_no}
      class="shrink-0 rounded-md bg-info/15 px-2 py-0.5 text-xs font-medium text-info"
      title={"Licensed by the Federal Maritime Commission (license #{@company.fmc_license_no})"}
    >
      FMC licensed
    </span>
    """
  end

  attr :routes, :list, required: true
  attr :title, :string, required: true

  def route_links(assigns) do
    ~H"""
    <section :if={@routes != []} class="space-y-3">
      <h2 class="text-lg font-semibold">{@title}</h2>
      <ul class="flex flex-wrap gap-2">
        <li :for={route <- @routes}>
          <.link
            navigate={~p"/ship-barrel/#{route.slug}"}
            class="inline-block rounded-full border border-base-300 px-3 py-1 text-sm transition hover:border-primary hover:text-primary"
          >
            {route.metro_name} → {route.destination_name}
            <span :if={route.count} class="opacity-60">({route.count})</span>
          </.link>
        </li>
      </ul>
    </section>
    """
  end

  def location(company) do
    case {company.city, company.state} do
      {nil, nil} ->
        case company.metro_slugs do
          [] -> nil
          slugs -> Enum.map_join(slugs, ", ", &Metros.name/1)
        end

      {city, nil} ->
        city

      {nil, state} ->
        state

      {city, state} ->
        "#{city}, #{state}"
    end
  end
end
