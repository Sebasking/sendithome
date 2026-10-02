defmodule ShipperDirectoryWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use ShipperDirectoryWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  attr :admin, :boolean, default: false, doc: "admin pages get a wider layout and admin nav"
  attr :current_user, :map, default: nil, doc: "the signed-in listing owner, if any"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="border-b border-base-300 bg-base-100/80 backdrop-blur sticky top-0 z-10">
      <nav class="mx-auto max-w-6xl flex items-center gap-3 px-4 py-3 sm:gap-6 sm:px-6">
        <.link navigate={~p"/"} class="flex items-center gap-2 font-semibold tracking-tight">
          <span class="grid size-8 place-items-center rounded-lg bg-primary text-primary-content">
            <.icon name="hero-cube" class="size-5" />
          </span>
          <span class="hidden sm:inline">Caribbean Shipper Directory</span>
        </.link>
        <div class="ml-auto flex items-center gap-1 text-sm">
          <%= cond do %>
            <% @admin -> %>
              <.link navigate={~p"/admin"} class="btn btn-ghost btn-sm">Companies</.link>
              <.link navigate={~p"/admin/prospects"} class="btn btn-ghost btn-sm">Outreach</.link>
            <% @current_user -> %>
              <.link navigate={~p"/"} class="btn btn-ghost btn-sm hidden sm:inline-flex">
                Find a shipper
              </.link>
              <.link navigate={~p"/my/listings"} class="btn btn-ghost btn-sm">My listings</.link>
              <.link href={~p"/sign-out"} class="btn btn-ghost btn-sm">Sign out</.link>
            <% true -> %>
              <.link navigate={~p"/"} class="btn btn-ghost btn-sm">Find a shipper</.link>
              <.link navigate={~p"/ship-barrel"} class="btn btn-ghost btn-sm">Routes</.link>
          <% end %>
          <div class="hidden sm:block"><.theme_toggle /></div>
        </div>
      </nav>
    </header>

    <main class="px-4 py-10 sm:px-6 lg:px-8">
      <div class={["mx-auto space-y-4", if(@admin, do: "max-w-7xl", else: "max-w-6xl")]}>
        {render_slot(@inner_block)}
      </div>
    </main>

    <footer :if={!@admin} class="border-t border-base-300 py-8 text-sm opacity-70">
      <div class="mx-auto max-w-6xl px-4 sm:px-6 flex flex-wrap gap-x-6 gap-y-2">
        <span>Only shippers with a verified, working website are listed.</span>
        <.link navigate={~p"/ship-barrel"} class="link">All routes</.link>
        <.link :if={!@current_user} navigate={~p"/sign-in"} class="link">Shipper sign in</.link>
      </div>
    </footer>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
