defmodule ShipperDirectoryWeb.Owner.MyListingsLive do
  @moduledoc "A signed-in owner's claimed listings."
  use ShipperDirectoryWeb, :live_view

  alias ShipperDirectory.Directory

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       companies: Directory.companies_owned_by!(socket.assigns.current_user.id),
       page_title: "My listings",
       noindex: true
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        My listings
        <:subtitle>Signed in as {@current_user.email}</:subtitle>
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
        </li>
      </ul>

      <p :if={@companies == []} class="opacity-70">
        You don't have any listings yet. Find your business in the directory and click "Claim this listing".
      </p>
    </Layouts.app>
    """
  end
end
