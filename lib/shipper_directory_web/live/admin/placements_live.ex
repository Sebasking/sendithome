defmodule ShipperDirectoryWeb.Admin.PlacementsLive do
  @moduledoc "Sell and manage sponsored placements (sold offline, recorded here)."
  use ShipperDirectoryWeb, :live_view

  alias ShipperDirectory.{Directory, Leads}
  alias ShipperDirectory.Directory.{Destinations, Placement}
  alias ShipperDirectory.Discovery.Metros

  @impl true
  def mount(_params, _session, socket) do
    today = Date.utc_today()

    {:ok,
     socket
     |> assign(
       page_title: "Placements",
       noindex: true,
       companies: Enum.map(Directory.published_companies!(), &{&1.name, &1.id}),
       metros: Enum.map(Metros.all(), &{&1.name, &1.slug}),
       destinations: [
         {"Every route from the metro", ""} | Enum.map(Destinations.all(), &{&1.name, &1.slug})
       ],
       form:
         to_form(
           %{
             "starts_on" => Date.to_iso8601(today),
             "ends_on" => Date.to_iso8601(Date.add(today, 30))
           },
           as: :placement
         )
     )
     |> load()}
  end

  @impl true
  def handle_event("create", %{"placement" => params}, socket) do
    attrs = %{
      company_id: params["company_id"],
      metro: params["metro"],
      destination: blank_to_nil(params["destination"]),
      starts_on: params["starts_on"],
      ends_on: params["ends_on"],
      price_cents: dollars_to_cents(params["price"]),
      notes: blank_to_nil(params["notes"])
    }

    case Directory.create_placement(attrs) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Placement created") |> load()}

      {:error, error} ->
        {:noreply,
         socket
         |> assign(form: to_form(params, as: :placement))
         |> put_flash(:error, Leads.error_message(error))}
    end
  end

  def handle_event("end", %{"id" => id}, socket) do
    id |> Directory.get_placement!() |> Directory.end_placement!()
    {:noreply, load(socket)}
  end

  defp load(socket), do: assign(socket, placements: Directory.list_placements!())

  defp state(placement) do
    today = Date.utc_today()

    cond do
      Date.compare(placement.starts_on, today) == :gt -> "Upcoming"
      Date.compare(placement.ends_on, today) == :lt -> "Ended"
      true -> "Active"
    end
  end

  defp dollars_to_cents(value) do
    case Float.parse(value || "") do
      {dollars, _} -> round(dollars * 100)
      :error -> 0
    end
  end

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value

  @impl true
  def render(assigns) do
    assigns = assign(assigns, max: Placement.max_per_slot())

    ~H"""
    <Layouts.app flash={@flash} admin>
      <.header>
        Sponsored placements
        <:subtitle>
          Shown in a labeled "Sponsored" block above the results on matching route pages and searches. Max {@max} per slot.
        </:subtitle>
      </.header>

      <.form for={@form} id="placement-form" phx-submit="create" class="grid gap-x-4 sm:grid-cols-3">
        <.input
          field={@form[:company_id]}
          type="select"
          label="Company"
          options={@companies}
          prompt="Choose…"
          required
        />
        <.input
          field={@form[:metro]}
          type="select"
          label="Metro"
          options={@metros}
          prompt="Choose…"
          required
        />
        <.input field={@form[:destination]} type="select" label="Destination" options={@destinations} />
        <.input field={@form[:starts_on]} type="date" label="Starts" required />
        <.input field={@form[:ends_on]} type="date" label="Ends" required />
        <.input field={@form[:price]} type="number" step="0.01" min="0" label="Price paid ($)" />
        <div class="sm:col-span-2">
          <.input field={@form[:notes]} label="Notes (invoice #, contact)" />
        </div>
        <div class="flex items-end pb-2">
          <.button class="btn btn-primary w-full">Add placement</.button>
        </div>
      </.form>

      <.table id="placements" rows={@placements} row_id={&"placement-#{&1.id}"}>
        <:col :let={p} label="Company">{p.company.name}</:col>
        <:col :let={p} label="Slot">
          {Metros.name(p.metro)} → {if p.destination,
            do: Destinations.name(p.destination),
            else: "all routes"}
        </:col>
        <:col :let={p} label="Dates">
          {Calendar.strftime(p.starts_on, "%b %d")} – {Calendar.strftime(p.ends_on, "%b %d, %Y")}
        </:col>
        <:col :let={p} label="Price">{Leads.format_price(p.price_cents)}</:col>
        <:col :let={p} label="State">{state(p)}</:col>
        <:action :let={p}>
          <button :if={state(p) == "Active"} phx-click="end" phx-value-id={p.id} class="btn btn-xs">
            End now
          </button>
        </:action>
      </.table>
    </Layouts.app>
    """
  end
end
