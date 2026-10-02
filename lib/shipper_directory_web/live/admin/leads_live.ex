defmodule ShipperDirectoryWeb.Admin.LeadsLive do
  @moduledoc "Quote requests: disputes to resolve, the monthly invoice ledger, and recent leads."
  use ShipperDirectoryWeb, :live_view

  alias ShipperDirectory.{Directory, Leads}
  alias ShipperDirectory.Leads.Ledger

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Leads", noindex: true)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, socket |> assign(month: Ledger.parse_month(params["month"])) |> load()}
  end

  @impl true
  def handle_event("resolve", %{"id" => id, "accept" => accept}, socket) do
    id |> Directory.get_lead_delivery!() |> Directory.resolve_dispute!(accept == "true")
    {:noreply, socket |> put_flash(:info, "Dispute resolved") |> load()}
  end

  def handle_event("month", %{"month" => month}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/leads?#{[month: month]}")}
  end

  defp load(socket) do
    assign(socket,
      disputes: Directory.disputed_lead_deliveries!(),
      ledger: Ledger.for_month(socket.assigns.month),
      leads: Directory.recent_leads!()
    )
  end

  defp month_value(date), do: Calendar.strftime(date, "%Y-%m")

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} admin>
      <.header>
        Leads
        <:subtitle>
          Price per lead: {Leads.format_price(Leads.price_cents())} (LEAD_PRICE_CENTS)
        </:subtitle>
      </.header>

      <section :if={@disputes != []} class="space-y-2">
        <h2 class="font-semibold">Disputes</h2>
        <div
          :for={d <- @disputes}
          id={"dispute-#{d.id}"}
          class="flex flex-wrap items-center gap-3 rounded-xl border border-warning/40 p-3 text-sm"
        >
          <div class="flex-1">
            <strong>{d.company.name}</strong>
            disputes {d.lead.name} ({Leads.route_label(d.lead)}): "{d.dispute_reason}"
          </div>
          <button
            phx-click="resolve"
            phx-value-id={d.id}
            phx-value-accept="true"
            class="btn btn-xs btn-success"
          >
            Accept (credit)
          </button>
          <button phx-click="resolve" phx-value-id={d.id} phx-value-accept="false" class="btn btn-xs">
            Reject
          </button>
        </div>
      </section>

      <section class="space-y-2">
        <div class="flex flex-wrap items-end gap-3">
          <h2 class="font-semibold">Ledger</h2>
          <form id="month-form" phx-change="month">
            <input type="month" name="month" value={month_value(@month)} class="input input-sm" />
          </form>
          <.link
            href={~p"/admin/ledger.csv?#{[month: month_value(@month)]}"}
            class="btn btn-sm ml-auto"
          >
            <.icon name="hero-arrow-down-tray" /> CSV
          </.link>
        </div>
        <.table id="ledger" rows={@ledger} row_id={&"ledger-#{&1.company.id}"}>
          <:col :let={row} label="Company">{row.company.name}</:col>
          <:col :let={row} label="Leads">{row.count}</:col>
          <:col :let={row} label="Total">{Leads.format_price(row.total_cents)}</:col>
        </.table>
        <p :if={@ledger == []} class="text-sm opacity-60">Nothing billable this month.</p>
      </section>

      <section class="space-y-2">
        <h2 class="font-semibold">Recent requests</h2>
        <.table id="leads" rows={@leads} row_id={&"lead-#{&1.id}"}>
          <:col :let={lead} label="When">{Calendar.strftime(lead.inserted_at, "%b %d %H:%M")}</:col>
          <:col :let={lead} label="Consumer">{lead.name}</:col>
          <:col :let={lead} label="Route">{Leads.route_label(lead)}</:col>
          <:col :let={lead} label="Items">{Leads.items_label(lead)}</:col>
          <:col :let={lead} label="Sent to">
            <div :for={d <- lead.deliveries} class="text-xs">
              {d.company.name} <span class="opacity-60">({d.status})</span>
            </div>
          </:col>
        </.table>
      </section>
    </Layouts.app>
    """
  end
end
