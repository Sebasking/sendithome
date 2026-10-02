defmodule ShipperDirectoryWeb.Admin.ProspectsLive do
  @moduledoc """
  Outreach CRM (spec section 7): prospects filtered by metro, sorted by fit
  or follow-up date, one-click outcome logging, and follow-up reminders.
  Suppressed (`do_not_contact`) companies never appear. SMS/WhatsApp can be
  logged only after the company opts in.
  """
  use ShipperDirectoryWeb, :live_view

  alias ShipperDirectory.Crm.Fit
  alias ShipperDirectory.Directory
  alias ShipperDirectory.Directory.Types.{OutreachChannel, OutreachOutcome}
  alias ShipperDirectory.Discovery.Metros

  # One-click outcomes for a phone call: {label, outcome, follow up in days}
  @quick [
    {"No answer", :no_answer, 2},
    {"Left message", :left_message, 3},
    {"Interested", :interested, 2},
    {"Not interested", :not_interested, nil}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       quick: @quick,
       metros: Enum.map(Metros.all(), &{&1.name, &1.slug}),
       channels:
         Enum.map(OutreachChannel.values(), &{&1 |> to_string() |> String.replace("_", " "), &1}),
       outcomes: Enum.map(OutreachOutcome.values(), &{OutreachOutcome.description(&1), &1}),
       page_title: "Outreach",
       noindex: true
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = %{
      "metro" => if(params["metro"] in Metros.slugs(), do: params["metro"]),
      "due" => params["due"] == "1",
      "sort" => if(params["sort"] in ~w(fit next name), do: params["sort"], else: "fit")
    }

    {:noreply,
     socket
     |> assign(filters: filters, selected_id: params["id"])
     |> load()}
  end

  @impl true
  def handle_event("filter", params, socket) do
    {:noreply,
     push_patch(socket,
       to:
         crm_path(
           socket.assigns.filters,
           socket.assigns.selected_id,
           Map.take(params, ~w(metro due sort))
         )
     )}
  end

  def handle_event("quick", %{"id" => id, "outcome" => outcome}, socket) do
    {_, outcome, days} = Enum.find(@quick, fn {_, o, _} -> to_string(o) == outcome end)
    next = days && DateTime.add(DateTime.utc_now(), days, :day)

    {:noreply,
     log(socket, %{company_id: id, channel: :call, outcome: outcome, next_action_at: next})}
  end

  def handle_event("log", %{"event" => params}, socket) do
    next =
      case params["next_action_at"] do
        date when date in [nil, ""] -> nil
        date -> DateTime.new!(Date.from_iso8601!(date), ~T[13:00:00], "Etc/UTC")
      end

    {:noreply,
     log(socket, %{
       company_id: socket.assigns.selected_id,
       channel: params["channel"],
       outcome: params["outcome"],
       notes: params["notes"],
       next_action_at: next
     })}
  end

  defp log(socket, attrs) do
    case Directory.log_outreach(attrs) do
      {:ok, _event} -> socket |> put_flash(:info, "Logged") |> load()
      {:error, error} -> put_flash(socket, :error, error_message(error))
    end
  end

  defp error_message(%Ash.Error.Invalid{errors: errors}),
    do: Enum.map_join(errors, "; ", &Exception.message/1)

  defp error_message(error), do: Exception.message(error)

  defp load(socket) do
    %{"metro" => metro, "due" => due?, "sort" => sort} = socket.assigns.filters
    now = DateTime.utc_now()

    rows =
      Directory.prospects!(
        load: [:last_outreach_at, :next_action_at, :last_outcome, :outreach_count]
      )
      |> Enum.filter(&(is_nil(metro) or metro in &1.metro_slugs))
      |> Enum.map(fn c ->
        {score, reasons} = Fit.score(c)
        %{company: c, fit: score, reasons: reasons}
      end)
      |> Enum.map(&Map.put(&1, :due?, due?(&1.company, now)))

    due_count = Enum.count(rows, & &1.due?)
    rows = if due?, do: Enum.filter(rows, & &1.due?), else: rows

    rows =
      case sort do
        "fit" ->
          Enum.sort_by(rows, &{-&1.fit, &1.company.name})

        "name" ->
          Enum.sort_by(rows, & &1.company.name)

        "next" ->
          Enum.sort_by(rows, &(&1.company.next_action_at || ~U[9999-01-01 00:00:00Z]), DateTime)
      end

    selected =
      with id when is_binary(id) <- socket.assigns.selected_id,
           {:ok, company} <- Directory.get_company(id, load: [:next_action_at]) do
        %{company: company, events: Directory.outreach_for_company!(id), fit: Fit.score(company)}
      else
        _ -> nil
      end

    assign(socket,
      rows: rows,
      due_count: due_count,
      selected: selected,
      event_form:
        to_form(
          %{"channel" => "call", "outcome" => "other", "notes" => "", "next_action_at" => ""},
          as: :event
        )
    )
  end

  defp due?(%{next_action_at: nil}, _now), do: false
  defp due?(%{next_action_at: at}, now), do: DateTime.compare(at, now) != :gt

  defp crm_path(filters, selected_id, overrides) do
    params =
      filters
      |> Map.merge(%{"due" => if(filters["due"], do: "1"), "id" => selected_id})
      |> Map.merge(overrides)
      |> Enum.reject(fn {_, v} -> v in [nil, "", false, "0"] end)

    ~p"/admin/prospects?#{params}"
  end

  defp date(nil), do: "–"
  defp date(dt), do: Calendar.strftime(dt, "%b %d")

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} admin>
      <.header>
        Outreach
        <:subtitle>
          Cold outreach by call, email, or visit only. SMS and WhatsApp need an opt-in first (TCPA).
        </:subtitle>
        <:actions>
          <.button href={~p"/admin/prospects.csv"} class="btn btn-sm">
            <.icon name="hero-arrow-down-tray" /> Export CSV
          </.button>
        </:actions>
      </.header>

      <form id="filters" phx-change="filter" class="flex flex-wrap items-end gap-3">
        <label class="text-sm">
          <span class="block opacity-70">Metro</span>
          <select name="metro" class="select select-sm">
            <option value="">All metros</option>
            {Phoenix.HTML.Form.options_for_select(@metros, @filters["metro"])}
          </select>
        </label>
        <label class="text-sm">
          <span class="block opacity-70">Sort by</span>
          <select name="sort" class="select select-sm">
            {Phoenix.HTML.Form.options_for_select(
              [{"Best fit", "fit"}, {"Next follow-up", "next"}, {"Name", "name"}],
              @filters["sort"]
            )}
          </select>
        </label>
        <label class="label cursor-pointer gap-2 text-sm">
          <input type="hidden" name="due" value="0" />
          <input
            type="checkbox"
            name="due"
            value="1"
            checked={@filters["due"]}
            class="checkbox checkbox-sm"
          /> Due for follow-up <span class="badge badge-sm badge-warning">{@due_count}</span>
        </label>
      </form>

      <div class="grid gap-6 lg:grid-cols-[1fr_22rem]">
        <div class="overflow-x-auto">
          <.table id="prospects" rows={@rows} row_id={&"prospect-#{&1.company.id}"}>
            <:col :let={row} label="Prospect">
              <.link
                patch={crm_path(@filters, @selected_id, %{"id" => row.company.id})}
                class={[
                  "font-medium hover:underline",
                  @selected_id == row.company.id && "text-primary"
                ]}
              >
                {row.company.name}
              </.link>
              <div class="text-xs opacity-60">
                {[row.company.city, row.company.state] |> Enum.reject(&is_nil/1) |> Enum.join(", ")}
              </div>
              <a
                :if={row.company.phone}
                href={"tel:" <> String.replace(row.company.phone, ~r/[^\d+]/, "")}
                class="text-xs link"
              >
                {row.company.phone}
              </a>
            </:col>
            <:col :let={row} label="Fit">
              <span class="badge badge-sm" title={Enum.join(row.reasons, "\n")}>{row.fit}</span>
            </:col>
            <:col :let={row} label="Last touch">
              <div class="text-xs">{date(row.company.last_outreach_at)}</div>
              <div :if={row.company.last_outcome} class="text-xs opacity-70">
                {OutreachOutcome.description(row.company.last_outcome)}
              </div>
            </:col>
            <:col :let={row} label="Follow up">
              <span class={["text-xs", row.due? && "text-warning font-semibold"]}>
                {date(row.company.next_action_at)}
              </span>
            </:col>
            <:action :let={row}>
              <div class="flex flex-nowrap justify-end gap-1">
                <button
                  :for={{label, outcome, _days} <- @quick}
                  phx-click="quick"
                  phx-value-id={row.company.id}
                  phx-value-outcome={outcome}
                  class="btn btn-xs btn-ghost whitespace-nowrap"
                >
                  {label}
                </button>
              </div>
            </:action>
          </.table>
          <p :if={@rows == []} class="py-8 text-center opacity-60">No prospects match.</p>
        </div>

        <aside
          :if={@selected}
          id="prospect-panel"
          class="h-fit space-y-4 rounded-2xl border border-base-300 p-4"
        >
          <div class="flex items-start justify-between gap-2">
            <div>
              <h2 class="font-semibold">{@selected.company.name}</h2>
              <p class="text-xs opacity-70">Status: {@selected.company.status}</p>
            </div>
            <.link
              patch={crm_path(@filters, @selected_id, %{"id" => nil})}
              class="btn btn-ghost btn-xs"
            >
              <.icon name="hero-x-mark" />
            </.link>
          </div>

          <ul class="text-xs space-y-0.5 opacity-80">
            <li :for={reason <- elem(@selected.fit, 1)}>{reason}</li>
          </ul>

          <p class="text-xs">
            <%= if @selected.company.messaging_consent_at do %>
              <span class="text-success">
                SMS/WhatsApp opt-in {date(@selected.company.messaging_consent_at)}: {@selected.company.messaging_consent_note}
              </span>
            <% else %>
              <span class="opacity-70">No SMS/WhatsApp opt-in yet.</span>
            <% end %>
          </p>

          <.form for={@event_form} id="log-form" phx-submit="log" class="space-y-2">
            <div class="grid grid-cols-2 gap-2">
              <.input field={@event_form[:channel]} type="select" label="Channel" options={@channels} />
              <.input field={@event_form[:outcome]} type="select" label="Outcome" options={@outcomes} />
            </div>
            <.input field={@event_form[:notes]} type="textarea" label="Notes" />
            <.input field={@event_form[:next_action_at]} type="date" label="Follow up on" />
            <.button class="btn btn-primary w-full">Log</.button>
          </.form>

          <div class="space-y-2">
            <h3 class="text-sm font-semibold">History</h3>
            <ol class="space-y-2 text-sm">
              <li :for={event <- @selected.events} class="border-l-2 border-base-300 pl-3">
                <div class="text-xs opacity-60">
                  {Calendar.strftime(event.inserted_at, "%b %d %H:%M")} · {event.channel}
                </div>
                <div>{OutreachOutcome.description(event.outcome)}</div>
                <div :if={event.notes} class="text-xs opacity-80">{event.notes}</div>
                <div :if={event.next_action_at} class="text-xs opacity-60">
                  Follow up {date(event.next_action_at)}
                </div>
              </li>
            </ol>
            <p :if={@selected.events == []} class="text-xs opacity-60">No touches yet.</p>
          </div>
        </aside>
      </div>
    </Layouts.app>
    """
  end
end
