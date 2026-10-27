defmodule ShipperDirectoryWeb.FlowComponents do
  @moduledoc "Building blocks of the QR sticker flow (`FinderLive`)."
  use ShipperDirectoryWeb, :html

  alias ShipperDirectory.Finder

  @doc "A destination's flag as inline SVG, keyed by its ISO code. Decorative."
  attr :code, :string, required: true
  attr :class, :string, default: "h-5 w-[30px]"

  def flag(assigns) do
    ~H"""
    <svg viewBox="0 0 30 20" class={["shrink-0 rounded-[3px]", @class]} aria-hidden="true">
      <%= case @code do %>
        <% "jm" -> %>
          <rect width="30" height="20" fill="#009B3A" />
          <path d="M0 0 L15 10 L0 20 Z M30 0 L15 10 L30 20 Z" fill="#000000" />
          <path d="M0 0 L30 20 M30 0 L0 20" stroke="#FED100" stroke-width="3" />
        <% "gy" -> %>
          <rect width="30" height="20" fill="#009E49" />
          <path d="M0 0 L30 10 L0 20 Z" fill="#FFFFFF" />
          <path d="M0 1.4 L27 10 L0 18.6 Z" fill="#FCD116" />
          <path d="M0 0 L15 10 L0 20 Z" fill="#000000" />
          <path d="M0 1.6 L12.6 10 L0 18.4 Z" fill="#CE1126" />
        <% "tt" -> %>
          <rect width="30" height="20" fill="#CE1126" />
          <path d="M2 -2 L32 20" stroke="#FFFFFF" stroke-width="9" />
          <path d="M2 -2 L32 20" stroke="#000000" stroke-width="5.5" />
        <% "bb" -> %>
          <rect width="30" height="20" fill="#00267F" />
          <rect x="10" width="10" height="20" fill="#FFC726" />
          <path
            d="M15 5 V16 M11.6 7 Q11.6 11.4 15 11.8 Q18.4 11.4 18.4 7"
            fill="none"
            stroke="#000000"
            stroke-width="1.3"
          />
        <% "ht" -> %>
          <rect width="30" height="10" fill="#00209F" />
          <rect y="10" width="30" height="10" fill="#D21034" />
          <rect x="11" y="7" width="8" height="6" fill="#FFFFFF" />
        <% _ -> %>
          <rect width="30" height="20" fill="#E3EFEE" />
          <path d="M10 4 V16 M10 5 H21 L18 8.5 L21 12 H10" fill="none" stroke="#0E6B6B" />
      <% end %>
    </svg>
    """
  end

  @doc "A full-width answer on the first step: icon, label, chevron."
  attr :id, :string, required: true
  attr :patch, :string, required: true
  slot :icon, required: true
  slot :inner_block, required: true

  def choice_link(assigns) do
    ~H"""
    <.link
      id={@id}
      patch={@patch}
      class="group flex min-h-14 items-center gap-3.5 rounded-[14px] border border-brand-border bg-brand-surface px-4 text-lg font-semibold text-brand-ink transition hover:border-brand-primary hover:shadow-sm focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-primary active:scale-[0.99]"
    >
      {render_slot(@icon)}
      <span>{render_slot(@inner_block)}</span>
      <.icon
        name="hero-chevron-right"
        class="ml-auto size-5 text-brand-muted transition-transform group-hover:translate-x-0.5"
      />
    </.link>
    """
  end

  @doc """
  A shipper result. The sponsored card gets the "Sponsored" label, an
  accent border and a filled Call button.
  """
  attr :id, :string, required: true
  attr :shipper, :map, required: true
  attr :sponsored, :boolean, default: false
  attr :christmas, :boolean, default: false
  attr :go_query, :list, required: true, doc: "query params for the /go contact links"

  def shipper_card(assigns) do
    assigns =
      assign(assigns,
        meta: card_meta(assigns.shipper),
        channels: channels(assigns.shipper),
        go_query:
          if(assigns.sponsored,
            do: [{"sponsored", "1"} | assigns.go_query],
            else: assigns.go_query
          )
      )

    ~H"""
    <article
      id={@id}
      class={[
        "flex flex-col gap-3 rounded-2xl bg-brand-surface p-4",
        if(@sponsored, do: "border-2 border-brand-accent", else: "border border-brand-border")
      ]}
    >
      <p
        :if={@sponsored}
        class="self-start rounded-full bg-brand-sponsor-bg px-2.5 py-0.5 text-[13px] font-bold uppercase tracking-wide text-brand-sponsor-ink"
      >
        Sponsored
      </p>
      <div class="flex flex-col gap-1">
        <h2 class={["font-bold", if(@sponsored, do: "text-xl", else: "text-lg")]}>
          {@shipper.name}
        </h2>
        <p :if={@meta != ""} class="text-[15px] text-brand-muted">{@meta}</p>
      </div>
      <div
        :if={@sponsored and (@shipper.pickup_available || @christmas)}
        class="flex flex-wrap gap-1.5"
      >
        <span :if={@shipper.pickup_available} class="rounded-lg bg-brand-ground px-2.5 py-1 text-sm">
          Pickup available
        </span>
        <span :if={@christmas} class="rounded-lg bg-brand-ground px-2.5 py-1 text-sm">
          Makes Christmas cutoff
        </span>
      </div>
      <%!-- mt-auto lines the buttons up across a row of the results grid --%>
      <div :if={@channels != []} class="mt-auto flex gap-2.5">
        <.link
          :for={{channel, label, icon} <- @channels}
          href={~p"/go/#{@shipper.slug}/#{channel}?#{@go_query}"}
          id={"#{@id}-#{channel}"}
          class={[
            "flex min-h-12 flex-1 items-center justify-center gap-2 rounded-xl text-base font-semibold transition",
            contact_class(@sponsored, channel)
          ]}
        >
          <.icon name={icon} class="size-[18px]" /> {label}
        </.link>
      </div>
    </article>
    """
  end

  defp contact_class(true, :call),
    do: "bg-brand-primary text-brand-on-primary hover:bg-brand-ink"

  defp contact_class(true, _channel),
    do: "border border-brand-primary bg-brand-surface text-brand-primary hover:bg-brand-tint"

  defp contact_class(false, _channel),
    do:
      "border border-brand-border text-brand-primary hover:border-brand-primary hover:bg-brand-tint"

  # Call and WhatsApp when the shipper has them; Website only when neither
  # does, so a card is never left without a way to reach the shipper.
  defp channels(shipper) do
    phone =
      [{:call, "Call", "hero-phone"}, {:whatsapp, "WhatsApp", "hero-chat-bubble-oval-left"}]
      |> Enum.filter(fn {channel, _, _} -> Finder.contact_target(shipper, channel) end)

    if phone == [] and Finder.contact_target(shipper, :website),
      do: [{:website, "Website", "hero-globe-alt"}],
      else: phone
  end

  defp card_meta(shipper) do
    sailing =
      with %Date{} = date <- shipper.next_sailing_date,
           true <- Date.compare(date, Date.utc_today()) != :lt do
        "Next sailing " <> Calendar.strftime(date, "%b %-d")
      else
        _ -> nil
      end

    [shipper.neighborhood || shipper.city, sailing]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end
end
