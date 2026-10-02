defmodule ShipperDirectoryWeb.Owner.MyListingsLive do
  @moduledoc "A signed-in owner's claimed listings."
  use ShipperDirectoryWeb, :live_view

  alias ShipperDirectory.{Directory, Leads}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       companies: Directory.companies_owned_by!(socket.assigns.current_user.id),
       page_title: "My listings",
       noindex: true,
       price: Leads.price_cents()
     )}
  end

  @impl true
  def handle_event("toggle_leads", %{"company_id" => id} = params, socket) do
    company = Enum.find(socket.assigns.companies, &(&1.id == id))
    Directory.set_accepts_leads!(company, params["accepts_leads"] == "true")

    {:noreply,
     assign(socket, companies: Directory.companies_owned_by!(socket.assigns.current_user.id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        My listings
        <:subtitle>Signed in as {@current_user.email}</:subtitle>
        <:actions>
          <.link navigate={~p"/my/leads"} class="btn btn-sm">Quote requests</.link>
        </:actions>
      </.header>

      <ul class="divide-y divide-base-300 rounded-2xl border border-base-300">
        <li :for={company <- @companies} class="flex flex-wrap items-center gap-4 p-4">
          <div class="flex-1">
            <p class="font-medium">{company.name}</p>
            <p class="text-sm opacity-70">
              {if company.status == :published,
                do: "Listed in the directory",
                else: "Not listed: we couldn't verify your website"}
            </p>
          </div>
          <.link
            :if={company.status == :published}
            navigate={~p"/shippers/#{company.slug}"}
            class="btn btn-ghost btn-sm"
          >
            View
          </.link>
          <.link navigate={~p"/my/listings/#{company.slug}"} class="btn btn-primary btn-sm">
            Edit listing
          </.link>
          <form
            id={"leads-#{company.id}"}
            phx-change="toggle_leads"
            class="basis-full rounded-xl bg-base-200 p-3 text-sm"
          >
            <input type="hidden" name="company_id" value={company.id} />
            <input type="hidden" name="accepts_leads" value="false" />
            <label class="flex cursor-pointer items-start gap-3">
              <input
                type="checkbox"
                name="accepts_leads"
                value="true"
                checked={company.accepts_leads}
                class="toggle toggle-sm toggle-primary mt-0.5"
              />
              <span>
                <span class="font-medium">Receive quote requests</span>
                <span class="block opacity-70">
                  Customers can send you shipping requests from the directory. {if @price > 0,
                    do:
                      "Each request costs #{Leads.format_price(@price)}, billed monthly. Dispute any that aren't real customers.",
                    else: "Free during the beta."}
                </span>
              </span>
            </label>
          </form>
        </li>
      </ul>

      <p :if={@companies == []} class="opacity-70">
        You don't have any listings yet. Find your business in the directory and click "Claim this listing".
      </p>
    </Layouts.app>
    """
  end
end
