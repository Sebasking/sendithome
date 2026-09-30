defmodule ShipperDirectoryWeb.Admin.CompaniesLive do
  @moduledoc """
  Admin table: triage, review queue, duplicates, prospects, and published
  listings, plus the discovery controls.
  """
  use ShipperDirectoryWeb, :live_view

  require Ash.Query

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Directory.{Company, Merge, Presence}
  alias ShipperDirectory.Discovery.GooglePlaces
  alias ShipperDirectory.Workers.{FmcImportWorker, GoogleLookupWorker}

  @views [
    {"all", "All", :read},
    {"triage", "Triage", :triage_queue},
    {"review", "Review queue", :review_queue},
    {"duplicates", "Duplicates", :duplicate_queue},
    {"prospects", "Prospects", :prospects},
    {"published", "Published", :published}
  ]

  @crm_statuses ~w(prospect contacted customer declined do_not_contact)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       views: Enum.map(@views, fn {key, label, _} -> {key, label} end),
       crm_statuses: @crm_statuses,
       checking: MapSet.new()
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    view = if List.keymember?(@views, params["view"], 0), do: params["view"], else: "all"
    {:noreply, socket |> assign(view: view) |> load()}
  end

  @impl true
  def handle_event("recheck", %{"id" => id}, socket) do
    {:noreply, check_async(socket, Directory.get_company!(id))}
  end

  def handle_event("approve", %{"id" => id}, socket) do
    id |> Directory.get_company!() |> Directory.approve_listing!()
    {:noreply, socket |> put_flash(:info, "Published") |> load()}
  end

  def handle_event("reject", %{"id" => id}, socket) do
    id |> Directory.get_company!() |> Directory.reject_listing!()
    {:noreply, socket |> put_flash(:info, "Moved to prospects") |> load()}
  end

  def handle_event("set_status", %{"company_id" => id, "status" => status}, socket)
      when status in @crm_statuses do
    id |> Directory.get_company!() |> Directory.set_company_status!(status)
    {:noreply, load(socket)}
  end

  def handle_event("set_website", %{"company_id" => id, "website_url" => url}, socket) do
    case id |> Directory.get_company!() |> Directory.set_website(String.trim(url)) do
      {:ok, company} -> {:noreply, check_async(socket, company)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Couldn't save that URL")}
    end
  end

  def handle_event("confirm", %{"id" => id}, socket) do
    company = id |> Directory.get_company!() |> Directory.confirm_caribbean!()
    if is_nil(company.website_url), do: Oban.insert(GoogleLookupWorker.new(%{company_id: id}))
    {:noreply, load(socket)}
  end

  def handle_event("exclude", %{"id" => id}, socket) do
    id |> Directory.get_company!() |> Directory.exclude_company!()
    {:noreply, load(socket)}
  end

  def handle_event("merge", %{"id" => id}, socket) do
    duplicate = Directory.get_company!(id)
    keep = Directory.get_company!(duplicate.possible_duplicate_of_id)
    kept = Merge.merge!(keep, duplicate)
    {:noreply, socket |> put_flash(:info, "Merged into #{kept.name}") |> load()}
  end

  def handle_event("not_duplicate", %{"id" => id}, socket) do
    id |> Directory.get_company!() |> Directory.dismiss_duplicate!()
    {:noreply, load(socket)}
  end

  def handle_event("import_fmc", _params, socket) do
    {:ok, _job} = Oban.insert(FmcImportWorker.new(%{}))

    {:noreply,
     put_flash(
       socket,
       :info,
       "FMC import queued (NYC). It takes a minute; refresh to see results."
     )}
  end

  def handle_event("google_lookups", _params, socket) do
    count = length(GoogleLookupWorker.enqueue_pending())
    {:noreply, put_flash(socket, :info, "Queued #{count} Google lookups")}
  end

  @impl true
  def handle_async({:check, id}, result, socket) do
    socket = update(socket, :checking, &MapSet.delete(&1, id))

    socket =
      case result do
        {:ok, company} ->
          put_flash(socket, :info, "#{company.name}: #{company.presence_status}")

        {:exit, reason} ->
          put_flash(socket, :error, "Check failed: #{inspect(reason)}")
      end

    {:noreply, load(socket)}
  end

  defp check_async(socket, company) do
    socket
    |> update(:checking, &MapSet.put(&1, company.id))
    |> start_async({:check, company.id}, fn -> Presence.check(company) end)
  end

  defp load(socket) do
    {_, _, action} = List.keyfind(@views, socket.assigns.view, 0)

    companies =
      Company
      |> Ash.Query.for_read(action)
      |> Ash.Query.sort(:name)
      |> Ash.Query.load(:possible_duplicate_of)
      |> Ash.read!()

    counts =
      for {key, _, action} <- @views, key != "all", into: %{} do
        {key, Company |> Ash.Query.for_read(action) |> Ash.count!()}
      end

    assign(socket,
      companies: companies,
      counts: counts,
      last_run: List.first(Directory.recent_discovery_runs!())
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Companies
        <:subtitle>
          Companies with a working website get published. The rest become prospects for outreach.
          <span :if={@last_run} class="block mt-1 text-xs">
            Last {@last_run.source} run: {@last_run.status}, {Calendar.strftime(
              @last_run.inserted_at,
              "%b %d %H:%M"
            )}
            <span :if={@last_run.stats != %{}}>
              ({@last_run.stats["created"]} new, {@last_run.stats["updated"]} updated, {@last_run.stats[
                "linked"
              ]} licenses linked)
            </span>
            <span :if={@last_run.error} class="text-error">{@last_run.error}</span>
          </span>
        </:subtitle>
        <:actions>
          <div class="flex flex-wrap gap-2">
            <button phx-click="import_fmc" class="btn btn-sm">
              <.icon name="hero-building-library" /> Import FMC list
            </button>
            <button phx-click="google_lookups" class="btn btn-sm">
              <.icon name="hero-map-pin" /> Run Google lookups
            </button>
            <.button href={~p"/admin/prospects.csv"} class="btn btn-sm btn-primary">
              <.icon name="hero-arrow-down-tray" /> Export prospects
            </.button>
          </div>
        </:actions>
      </.header>

      <div role="tablist" class="tabs tabs-border">
        <.link
          :for={{key, label} <- @views}
          patch={~p"/admin?view=#{key}"}
          role="tab"
          class={["tab", @view == key && "tab-active"]}
        >
          {label}
          <span :if={@counts[key]} class="badge badge-sm ml-2">{@counts[key]}</span>
        </.link>
      </div>

      <p :if={@view == "triage"} class="text-sm opacity-70">
        FMC-licensed forwarders in our metros whose name doesn't say "Caribbean". Is this a Caribbean barrel/freight shipper?
      </p>

      <div class="overflow-x-auto">
        <.table id="companies" rows={@companies} row_id={&"company-#{&1.id}"}>
          <:col :let={c} label="Company">
            <div class="font-medium">
              {c.name}
              <span
                :if={c.fmc_license_no}
                class="badge badge-xs badge-info ml-1"
                title="FMC license"
              >
                FMC {c.fmc_license_no}
              </span>
            </div>
            <div class="text-xs opacity-60">
              {[c.address, c.city, c.state] |> Enum.reject(&is_nil/1) |> Enum.join(", ")}
              <span :if={c.phone}>· {c.phone}</span>
            </div>
          </:col>
          <:col :let={c} label="Website">
            <a
              :if={c.website_url}
              href={c.website_url}
              target="_blank"
              rel="noopener"
              class="link text-sm"
            >
              {URI.parse(c.website_url).host}
            </a>
            <span :if={!c.website_url} class="text-xs opacity-50">none</span>
            <a
              :if={c.google_place_id}
              href={GooglePlaces.maps_url(c.google_place_id)}
              target="_blank"
              rel="noopener"
              class="link text-xs block"
            >
              Google Maps{if c.google_has_website, do: " (lists a site)", else: ""}
            </a>
          </:col>
          <:col :let={c} label="Presence">
            <span class={["badge badge-sm", presence_class(c.presence_status)]}>
              {c.presence_status || "unchecked"}
            </span>
          </:col>
          <:col :let={c} label="Status">
            <form
              :if={to_string(c.status) in @crm_statuses}
              id={"status-#{c.id}"}
              phx-change="set_status"
            >
              <input type="hidden" name="company_id" value={c.id} />
              <select name="status" class="select select-xs">
                {Phoenix.HTML.Form.options_for_select(@crm_statuses, to_string(c.status))}
              </select>
            </form>
            <span :if={to_string(c.status) not in @crm_statuses} class="text-sm">{c.status}</span>
            <span :if={c.needs_triage} class="badge badge-xs badge-ghost block mt-1">triage</span>
          </:col>
          <:col :let={c} label="Notes">
            <div :if={c.possible_duplicate_of} class="text-xs text-warning max-w-xs">
              Possible duplicate of <strong>{c.possible_duplicate_of.name}</strong>
              ({[c.possible_duplicate_of.city, c.possible_duplicate_of.state]
              |> Enum.reject(&is_nil/1)
              |> Enum.join(", ")})
            </div>
            <div :if={c.review_reason} class="text-xs text-warning max-w-xs">{c.review_reason}</div>
            <div :if={!c.review_reason && c.notes} class="text-xs opacity-70 max-w-xs">{c.notes}</div>
            <form
              :if={c.presence_status == :needs_review && !c.website_url}
              id={"website-#{c.id}"}
              phx-submit="set_website"
              class="flex gap-1 mt-1"
            >
              <input type="hidden" name="company_id" value={c.id} />
              <input
                type="url"
                name="website_url"
                placeholder="https://…"
                required
                class="input input-xs w-48"
              />
              <button class="btn btn-xs">Save &amp; check</button>
            </form>
          </:col>
          <:col :let={c} label="Checked">
            <span class="text-xs opacity-70">
              {if c.last_checked_at, do: Calendar.strftime(c.last_checked_at, "%b %d"), else: "never"}
            </span>
          </:col>
          <:action :let={c}>
            <div class="flex gap-1 justify-end flex-wrap">
              <%= if c.needs_triage and c.status != :excluded do %>
                <button phx-click="confirm" phx-value-id={c.id} class="btn btn-xs btn-success">
                  Caribbean shipper
                </button>
                <button phx-click="exclude" phx-value-id={c.id} class="btn btn-xs btn-ghost">
                  Not Caribbean
                </button>
              <% end %>
              <%= if c.possible_duplicate_of do %>
                <button phx-click="merge" phx-value-id={c.id} class="btn btn-xs btn-warning">
                  Merge
                </button>
                <button phx-click="not_duplicate" phx-value-id={c.id} class="btn btn-xs btn-ghost">
                  Not a duplicate
                </button>
              <% end %>
              <%= if c.presence_status == :needs_review && c.website_url do %>
                <button phx-click="approve" phx-value-id={c.id} class="btn btn-xs btn-success">
                  Approve
                </button>
                <button phx-click="reject" phx-value-id={c.id} class="btn btn-xs btn-warning">
                  Not their site
                </button>
              <% end %>
              <button
                :if={!c.needs_triage}
                phx-click="recheck"
                phx-value-id={c.id}
                disabled={MapSet.member?(@checking, c.id)}
                class="btn btn-xs btn-ghost"
              >
                <.icon
                  name="hero-arrow-path"
                  class={["size-4", MapSet.member?(@checking, c.id) && "animate-spin"]}
                /> Recheck
              </button>
            </div>
          </:action>
        </.table>
      </div>

      <p :if={@companies == []} class="py-8 text-center opacity-60">Nothing here.</p>
    </Layouts.app>
    """
  end

  defp presence_class(:listed), do: "badge-success"
  defp presence_class(:needs_review), do: "badge-warning"
  defp presence_class(status) when status in [:dead_site, :social_only, :none], do: "badge-error"
  defp presence_class(_), do: "badge-ghost"
end
