defmodule ShipperDirectoryWeb.Owner.LeadsLive do
  @moduledoc """
  Quote requests sent to the owner's listings. Owners track progress
  (contacted, booked, lost) and can dispute a lead that isn't a real
  customer. An admin accepts the dispute and credits it.
  """
  use ShipperDirectoryWeb, :live_view

  alias ShipperDirectory.{Directory, Leads}
  alias ShipperDirectory.Directory.Types.LeadDeliveryStatus

  @owner_statuses [:new, :contacted, :booked, :lost]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Quote requests", noindex: true, disputing: nil)
     |> load()}
  end

  @impl true
  def handle_event("set_status", %{"delivery_id" => id, "status" => status}, socket) do
    with {:ok, delivery} <- own_delivery(socket, id),
         status when status in @owner_statuses <- String.to_existing_atom(status) do
      Directory.owner_update_lead_delivery!(delivery, %{status: status})
    end

    {:noreply, load(socket)}
  end

  def handle_event("start_dispute", %{"id" => id}, socket) do
    {:noreply, assign(socket, disputing: id)}
  end

  def handle_event("dispute", %{"delivery_id" => id, "reason" => reason}, socket) do
    socket =
      case own_delivery(socket, id) do
        {:ok, delivery} when reason != "" ->
          Directory.owner_update_lead_delivery!(delivery, %{
            status: :disputed,
            dispute_reason: reason
          })

          put_flash(socket, :info, "Dispute sent. We'll review it.")

        _ ->
          put_flash(socket, :error, "Tell us why this lead isn't valid.")
      end

    {:noreply, socket |> assign(disputing: nil) |> load()}
  end

  defp own_delivery(socket, id) do
    case Enum.find(socket.assigns.deliveries, &(&1.id == id)) do
      nil -> :error
      delivery -> {:ok, delivery}
    end
  end

  defp load(socket) do
    assign(socket,
      deliveries: Directory.lead_deliveries_for_owner!(socket.assigns.current_user.id),
      statuses: Enum.map(@owner_statuses, &{LeadDeliveryStatus.description(&1), &1})
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        Quote requests
        <:subtitle>Customers who asked your business for a quote. Contact them quickly.</:subtitle>
      </.header>

      <div class="space-y-3">
        <article
          :for={d <- @deliveries}
          id={"delivery-#{d.id}"}
          class="rounded-2xl border border-base-300 p-4 space-y-2"
        >
          <div class="flex flex-wrap items-start justify-between gap-2">
            <div>
              <p class="font-semibold">{d.lead.name} · {Leads.route_label(d.lead)}</p>
              <p class="text-xs opacity-60">
                {Calendar.strftime(d.inserted_at, "%b %d, %H:%M")} · {d.company.name}
                <span :if={d.price_cents > 0}>· {Leads.format_price(d.price_cents)}</span>
              </p>
            </div>
            <%= if d.status in [:disputed, :credited] do %>
              <span class="badge">{LeadDeliveryStatus.description(d.status)}</span>
            <% else %>
              <form id={"status-#{d.id}"} phx-change="set_status">
                <input type="hidden" name="delivery_id" value={d.id} />
                <select name="status" class="select select-sm">
                  {Phoenix.HTML.Form.options_for_select(@statuses, to_string(d.status))}
                </select>
              </form>
            <% end %>
          </div>
          <dl class="grid gap-x-6 gap-y-1 text-sm sm:grid-cols-2">
            <div :if={d.lead.phone}>
              <dt class="inline opacity-60">Phone:</dt>
              <dd class="inline"><a href={"tel:" <> d.lead.phone} class="link">{d.lead.phone}</a></dd>
            </div>
            <div :if={d.lead.email}>
              <dt class="inline opacity-60">Email:</dt>
              <dd class="inline">
                <a href={"mailto:#{d.lead.email}"} class="link">{d.lead.email}</a>
              </dd>
            </div>
            <div>
              <dt class="inline opacity-60">Items:</dt>
              <dd class="inline">{Leads.items_label(d.lead)}</dd>
            </div>
            <div>
              <dt class="inline opacity-60">Pickup:</dt>
              <dd class="inline">
                {if d.lead.pickup_needed, do: "Needs pickup", else: "Will drop off"}
              </dd>
            </div>
            <div :if={d.lead.ship_by}>
              <dt class="inline opacity-60">Ship by:</dt>
              <dd class="inline">{Calendar.strftime(d.lead.ship_by, "%b %d")}</dd>
            </div>
          </dl>
          <p :if={d.lead.notes} class="text-sm opacity-80">{d.lead.notes}</p>

          <%= cond do %>
            <% @disputing == d.id -> %>
              <form id={"dispute-#{d.id}"} phx-submit="dispute" class="flex flex-wrap gap-2">
                <input type="hidden" name="delivery_id" value={d.id} />
                <input
                  name="reason"
                  placeholder="Why isn't this a real customer?"
                  class="input input-sm flex-1"
                  required
                />
                <button class="btn btn-sm">Send dispute</button>
              </form>
            <% d.status not in [:disputed, :credited] and d.price_cents > 0 -> %>
              <button phx-click="start_dispute" phx-value-id={d.id} class="link text-xs opacity-70">
                Not a real customer? Dispute this lead
              </button>
            <% true -> %>
          <% end %>
        </article>
      </div>

      <p :if={@deliveries == []} class="opacity-70">
        No quote requests yet. Turn on "Receive quote requests" on your listing to start getting them.
      </p>
    </Layouts.app>
    """
  end
end
