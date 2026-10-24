defmodule ShipperDirectoryWeb.FinderLive do
  @moduledoc """
  The QR sticker onboarding flow, one LiveView with a step per action:

    * `/start` (`:destination`): where's the barrel headed?
    * `/start/when` (`:timing`): before Christmas? Only in the Christmas
      season, and only for a listed destination.
    * `/shippers` (`:results`): the filtered shippers.

  All state lives in the URL (`to`, `when`, `src` and the UTM params), and
  steps move by patch, so every step is a shareable URL and Back works.
  Every control is a real link, so the pages work before (or without) the
  socket. No cookies or browser storage are used.

  Answers and impressions are logged only from the connected LiveView, so
  each one counts once. An answer is logged when the visitor moves on from
  a step, never when a URL is opened directly.
  """
  use ShipperDirectoryWeb, :live_view

  import ShipperDirectoryWeb.FlowComponents

  alias ShipperDirectory.Analytics.{EventLog, FlowAnswerEvent, ImpressionEvent}
  alias ShipperDirectory.Discovery.Metros
  alias ShipperDirectory.Finder
  alias ShipperDirectoryWeb.{Bots, FlowParams}

  @impl true
  def mount(_params, _session, socket) do
    track? = connected?(socket) and not Bots.bot?(get_connect_info(socket, :user_agent))

    {:ok,
     assign(socket,
       destinations: Finder.destinations(),
       track?: track?,
       step: nil,
       sticker: nil
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    carry = FlowParams.carry(params)
    sticker = sticker(socket.assigns.sticker, carry["src"])
    season? = Finder.christmas_season?()
    destination = Enum.find(socket.assigns.destinations, &(&1.code == params["to"]))

    to =
      cond do
        destination -> destination.code
        params["to"] == "other" -> "other"
        true -> nil
      end

    socket =
      assign(socket,
        carry: carry,
        sticker: sticker,
        season?: season?,
        destination: destination,
        to: to,
        timing: if(season? and params["when"] == "christmas", do: :christmas, else: :any),
        logo_variant: FlowParams.logo_variant(sticker, carry)
      )

    {:noreply, show_step(socket, socket.assigns.live_action, params)}
  end

  # Patches keep `src`, so the sticker source is looked up once.
  defp sticker(%{code: code} = sticker, code), do: sticker
  defp sticker(_previous, src), do: Finder.sticker_source(src)

  defp show_step(socket, :destination, params) do
    socket
    |> assign(page_title: "Where’s your barrel headed?", canonical_url: url(~p"/start"))
    |> moved_on(:destination, params)
  end

  # The timing question needs a listed destination, and only exists in season.
  defp show_step(%{assigns: %{destination: nil}} = socket, :timing, _params),
    do: push_navigate(socket, to: ~p"/start?#{query(socket.assigns)}", replace: true)

  defp show_step(%{assigns: %{season?: false}} = socket, :timing, _params),
    do: push_navigate(socket, to: results_path(socket.assigns), replace: true)

  defp show_step(socket, :timing, params) do
    socket
    |> assign(
      page_title: "When does it need to get there?",
      canonical_url: url(~p"/start/when?#{[to: socket.assigns.to]}")
    )
    |> moved_on(:timing, params)
  end

  defp show_step(socket, :results, params) do
    %{destination: destination, sticker: sticker, timing: when_} = socket.assigns
    results = Finder.search(destination, sticker && sticker.area, when_)

    socket
    |> assign(
      results: results,
      thin?: results.count < Finder.thin_threshold(),
      go_query: go_query(socket.assigns),
      heading: if(destination, do: "Shippers to #{destination.name}", else: "All shippers"),
      page_title: if(destination, do: "Shippers to #{destination.name}", else: "All shippers"),
      canonical_url:
        url(~p"/shippers?#{FlowParams.query(%{}, to: socket.assigns.to, when: christmas(when_))}")
    )
    |> stream(:shippers, results.shippers, reset: true)
    |> moved_on(:results, params)
    |> log_impressions()
  end

  # Runs once the step is shown: logs the answer to the step the visitor
  # just left, and after a patch moves focus to the new heading.
  defp moved_on(%{assigns: %{step: from}} = socket, to, params) do
    if socket.assigns.track? and from do
      log_answer(socket.assigns, from, to, params)
    end

    socket = if from, do: push_event(socket, "flow:focus-heading", %{}), else: socket
    assign(socket, step: to)
  end

  defp log_answer(assigns, :destination, to, _params) when to in [:timing, :results],
    do: record_answer(assigns, :destination, assigns.to || "all")

  defp log_answer(assigns, :timing, :results, params) do
    answer =
      cond do
        assigns.timing == :christmas -> "christmas"
        params["when"] == "skip" -> "skip"
        true -> "any"
      end

    record_answer(assigns, :timing, answer)
  end

  defp log_answer(_assigns, _from, _to, _params), do: :ok

  defp record_answer(assigns, step, answer) do
    EventLog.record(FlowAnswerEvent, %{
      step: step,
      answer: answer,
      source_code: assigns.carry["src"],
      utm_content: assigns.carry["utm_content"]
    })
  end

  defp log_impressions(%{assigns: %{track?: false}} = socket), do: socket

  defp log_impressions(socket) do
    %{results: results, to: to, sticker: sticker, carry: carry} = socket.assigns

    shown =
      if(results.sponsored, do: [{results.sponsored, true}], else: []) ++
        Enum.map(results.shippers, &{&1, false})

    EventLog.record_all(
      ImpressionEvent,
      Enum.map(shown, fn {shipper, sponsored} ->
        %{
          company_id: shipper.id,
          sponsored: sponsored,
          destination_code: to,
          area_slug: sticker && sticker.area,
          source_code: carry["src"]
        }
      end)
    )

    socket
  end

  ## Paths. Every link carries `src` and the UTM params.

  defp query(assigns, extra \\ []), do: FlowParams.query(assigns.carry, extra)

  defp christmas(:christmas), do: "christmas"
  defp christmas(_when), do: nil

  defp destination_path(%{season?: true} = assigns, %{code: code}),
    do: ~p"/start/when?#{query(assigns, to: code)}"

  defp destination_path(assigns, %{code: code}),
    do: ~p"/shippers?#{query(assigns, to: code)}"

  defp results_path(assigns, extra \\ []),
    do: ~p"/shippers?#{query(assigns, Keyword.merge([to: assigns.to], extra))}"

  defp results_back_path(%{season?: true, destination: %{}} = assigns),
    do: ~p"/start/when?#{query(assigns, to: assigns.to)}"

  defp results_back_path(assigns), do: ~p"/start?#{query(assigns)}"

  defp go_query(%{to: to, carry: carry}),
    do: FlowParams.query(%{}, to: to, src: carry["src"], utm_content: carry["utm_content"])

  defp chips(assigns) do
    destination =
      if assigns.destination,
        do: [
          {"destination", assigns.destination.name,
           results_path(assigns, to: nil, when: christmas(assigns.timing))}
        ],
        else: []

    timing =
      if assigns.timing == :christmas,
        do: [{"timing", "Before Christmas", results_path(assigns)}],
        else: []

    destination ++ timing
  end

  defp summary(results, when_) do
    count = "#{results.count} #{if results.count == 1, do: "shipper", else: "shippers"}"

    area =
      cond do
        results.area_fallback? -> " in all areas"
        results.area -> " near #{Metros.name(results.area)}"
        true -> ""
      end

    count <> area <> if(when_ == :christmas, do: " · makes Christmas", else: "")
  end

  ## Steps

  @impl true
  def render(%{live_action: :destination} = assigns) do
    ~H"""
    <Layouts.flow flash={@flash} logo_variant={@logo_variant}>
      <div class="flex flex-1 flex-col gap-6 px-6 pb-6 pt-8">
        <div class="flex flex-col gap-2">
          <p class="text-base font-semibold text-brand-muted">Packing a barrel?</p>
          <.heading>Let’s find you a shipper. Where’s it headed?</.heading>
        </div>

        <nav aria-label="Choose a destination" id="destination-list" class="flex flex-col gap-2.5">
          <.choice_link
            :for={destination <- @destinations}
            id={"destination-#{destination.code}"}
            patch={destination_path(assigns, destination)}
          >
            <:icon><.flag code={destination.code} /></:icon>
            {destination.name}
          </.choice_link>
          <.choice_link id="destination-other" patch={~p"/shippers?#{query(assigns, to: "other")}"}>
            <:icon>
              <span class="flex w-[30px] justify-center">
                <.icon name="hero-globe-americas" class="size-6 text-brand-primary" />
              </span>
            </:icon>
            Somewhere else
          </.choice_link>
        </nav>

        <div class="mt-auto flex flex-col items-center gap-2.5 pt-4">
          <.link
            id="browse-all"
            patch={~p"/shippers?#{query(assigns)}"}
            class="flex min-h-11 items-center px-3 text-base font-semibold text-brand-primary underline-offset-4 hover:underline"
          >
            Just browse all shippers
          </.link>
          <p class="text-sm text-brand-muted">Free to use. No sign-up.</p>
        </div>
      </div>
    </Layouts.flow>
    """
  end

  def render(%{live_action: :timing} = assigns) do
    ~H"""
    <Layouts.flow
      flash={@flash}
      back={~p"/start?#{query(assigns)}"}
      step_label="Step 2 of 2"
      logo_variant={@logo_variant}
    >
      <div class="flex flex-1 flex-col gap-6 px-6 pb-6 pt-7">
        <p
          id="destination-chip"
          class="inline-flex items-center gap-2 self-start rounded-full bg-brand-tint px-3.5 py-2 text-[15px] font-semibold"
        >
          <.flag code={@destination.code} class="h-3.5 w-[21px]" /> Shipping to {@destination.name}
        </p>

        <.heading>When does it need to get there?</.heading>

        <div class="flex flex-col gap-3">
          <.link
            id="timing-christmas"
            patch={results_path(assigns, when: "christmas")}
            class="flex min-h-14 flex-col gap-1 rounded-2xl border-2 border-brand-primary bg-brand-surface p-[18px] transition hover:shadow-md active:scale-[0.99]"
          >
            <span class="text-[19px] font-bold">Before Christmas</span>
            <span class="text-[15px] text-brand-muted">
              Show shippers with a sailing that makes it in time
            </span>
          </.link>
          <.link
            id="timing-any"
            patch={results_path(assigns, when: "any")}
            class="flex min-h-14 flex-col gap-1 rounded-2xl border border-brand-border bg-brand-surface p-[18px] transition hover:border-brand-primary hover:shadow-md active:scale-[0.99]"
          >
            <span class="text-[19px] font-bold">No rush</span>
            <span class="text-[15px] text-brand-muted">
              Show me every shipper to {@destination.name}
            </span>
          </.link>
        </div>

        <aside id="cutoff-notice" class="flex gap-3 rounded-[14px] bg-brand-sponsor-bg p-4">
          <.icon name="hero-clock" class="size-[22px] shrink-0 text-brand-sponsor-ink" />
          <div class="flex flex-col gap-1 text-brand-sponsor-ink">
            <p class="text-base font-bold">Christmas cutoffs are close</p>
            <p class="text-[15px] leading-snug">
              Many shippers stop taking barrels for Christmas delivery around {Calendar.strftime(
                Finder.christmas_cutoff_display_date(),
                "%B %-d"
              )}. Check with your shipper before you pack.
            </p>
          </div>
        </aside>

        <.link
          id="timing-skip"
          patch={results_path(assigns, when: "skip")}
          class="mt-auto flex min-h-11 items-center self-center px-3 text-base font-semibold text-brand-primary underline-offset-4 hover:underline"
        >
          Skip this question
        </.link>
      </div>
    </Layouts.flow>
    """
  end

  def render(%{live_action: :results} = assigns) do
    ~H"""
    <Layouts.flow flash={@flash} back={results_back_path(assigns)} logo_variant={@logo_variant}>
      <div class="flex flex-col gap-4 px-5 pb-8 pt-5">
        <div class="flex flex-col gap-1">
          <.heading class="text-[26px]">{@heading}</.heading>
          <p id="results-summary" class="text-[15px] text-brand-muted">
            {summary(@results, @timing)}
          </p>
        </div>

        <div :if={chips(assigns) != []} id="filter-chips" class="flex flex-wrap gap-2">
          <.link
            :for={{key, label, remove_path} <- chips(assigns)}
            id={"remove-#{key}"}
            patch={remove_path}
            aria-label={"Remove filter: #{label}"}
            class="flex min-h-11 items-center gap-1.5 rounded-full border border-brand-primary bg-brand-tint px-3.5 text-[15px] font-semibold transition hover:bg-brand-surface"
          >
            {label} <.icon name="hero-x-mark" class="size-4" />
          </.link>
        </div>

        <p :if={@to == "other"} id="suggest-destination" class="text-[15px] text-brand-muted">
          Shipping somewhere we don’t list yet?
          <a href={Finder.suggest_shipper_url()} class="font-semibold text-brand-primary underline">
            Tell us where
          </a>
        </p>

        <.shipper_card
          :if={@results.sponsored}
          id="sponsored-shipper"
          shipper={@results.sponsored}
          sponsored
          christmas={@timing == :christmas}
          go_query={@go_query}
        />

        <div id="shippers" phx-update="stream" class="flex flex-col gap-4">
          <.shipper_card
            :for={{id, shipper} <- @streams.shippers}
            id={id}
            shipper={shipper}
            go_query={@go_query}
          />
        </div>

        <section
          :if={@thin?}
          id="thin-results"
          class="flex flex-col gap-3 rounded-2xl bg-brand-tint p-5"
        >
          <h2 class="text-[19px] font-bold">
            We’re still adding shippers{if @destination, do: " to #{@destination.name}"}
          </h2>
          <p class="text-[15px] leading-relaxed text-brand-ink/85">
            SendItHome is new, and we’re verifying shippers one call at a time. Know a good one? Tell us and we’ll add them.
          </p>
          <a
            id="suggest-shipper"
            href={Finder.suggest_shipper_url()}
            class="flex min-h-12 items-center justify-center rounded-xl bg-brand-primary text-base font-semibold text-white transition hover:bg-brand-ink"
          >
            Suggest a shipper
          </a>
          <.link
            :if={@destination}
            id="all-destinations"
            patch={~p"/shippers?#{query(assigns)}"}
            class="flex min-h-11 items-center self-center px-3 text-base font-semibold text-brand-primary underline-offset-4 hover:underline"
          >
            See shippers to all destinations
          </.link>
        </section>

        <a
          :if={!@thin?}
          id="suggest-footer"
          href={Finder.suggest_shipper_url()}
          class="flex min-h-11 items-center self-center px-3 text-base font-semibold text-brand-primary underline-offset-4 hover:underline"
        >
          Don’t see your shipper? Suggest one
        </a>
      </div>
    </Layouts.flow>
    """
  end

  # Focus target after a patch (see app.js), so screen readers hear the new step.
  attr :class, :string, default: "text-[30px]"
  slot :inner_block, required: true

  defp heading(assigns) do
    ~H"""
    <h1
      id="flow-heading"
      tabindex="-1"
      class={["font-bold leading-[1.15] tracking-tight outline-none", @class]}
    >
      {render_slot(@inner_block)}
    </h1>
    """
  end
end
