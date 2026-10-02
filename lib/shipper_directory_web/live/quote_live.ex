defmodule ShipperDirectoryWeb.QuoteLive do
  @moduledoc """
  "Get quotes": a consumer sends one shipping request to up to 3 shippers
  they pick. Opened from a route page (`?from=brooklyn&to=guyana`) or a
  company page (`?company=fcs-shipping-llc`). The consent text updates live
  to name exactly the selected shippers. See `ShipperDirectory.Leads`.
  """
  use ShipperDirectoryWeb, :live_view

  alias ShipperDirectory.{Directory, Leads}
  alias ShipperDirectory.Directory.Destinations
  alias ShipperDirectory.Discovery.Metros

  @impl true
  def mount(params, _session, socket) do
    company = params["company"] && find_company(params["company"])
    {from, to} = route(params, company)
    candidates = candidates(company, from, to)

    selected = candidates |> Enum.take(Leads.max_companies()) |> Enum.map(& &1.id)

    {:ok,
     assign(socket,
       company: company,
       candidates: candidates,
       selected: selected,
       sent: nil,
       metros: Enum.map(Metros.all(), &{&1.name, &1.slug}),
       destinations: Enum.map(Destinations.all(), &{&1.name, &1.slug}),
       form:
         to_form(
           %{
             "origin_metro" => from,
             "destination" => to,
             "barrels" => "1",
             "boxes" => "0",
             "pickup_needed" => "false"
           },
           as: :lead
         ),
       page_title: "Get shipping quotes",
       noindex: true
     )}
  end

  @impl true
  def handle_event("validate", %{"lead" => params} = all, socket) do
    {:noreply, assign(socket, form: to_form(params, as: :lead), selected: selected(all, socket))}
  end

  def handle_event("submit", %{"lead" => params} = all, socket) do
    selected = selected(all, socket)
    params = Map.put(params, "website", all["website"])

    case Leads.submit(params, selected, source_path: source_path(socket)) do
      {:ok, :ignored} ->
        {:noreply, assign(socket, sent: [])}

      {:ok, _lead} ->
        {:noreply,
         assign(socket, sent: Enum.filter(socket.assigns.candidates, &(&1.id in selected)))}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(form: to_form(params, as: :lead), selected: selected)
         |> put_flash(:error, Leads.error_message(reason))}
    end
  end

  # Checkbox list for route requests; a single company is always selected.
  defp selected(_params, %{assigns: %{company: %{id: id}, candidates: [_]}}), do: [id]

  defp selected(params, _socket),
    do: params |> Map.get("companies", []) |> Enum.reject(&(&1 == ""))

  # The route comes from the URL, else from what the company ships.
  defp route(params, nil),
    do: {valid(params["from"], Metros.slugs()), valid(params["to"], Destinations.slugs())}

  defp route(params, company) do
    {from, to} = route(params, nil)
    {from || List.first(company.metro_slugs), to || List.first(company.destination_slugs)}
  end

  defp candidates(nil, from, to) when is_binary(from) and is_binary(to),
    do: Leads.eligible(from, to)

  defp candidates(nil, _from, _to), do: []
  defp candidates(company, _from, _to), do: if(Leads.eligible?(company), do: [company], else: [])

  defp source_path(%{assigns: %{company: %{slug: slug}}}), do: "/shippers/#{slug}"
  defp source_path(_socket), do: "/quote"

  defp find_company(slug) do
    case Directory.get_published_company(slug) do
      {:ok, company} -> company
      _ -> nil
    end
  end

  defp valid(value, allowed), do: if(value in allowed, do: value)

  defp selected_companies(candidates, selected), do: Enum.filter(candidates, &(&1.id in selected))

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-2xl space-y-6">
        <%= cond do %>
          <% @sent -> %>
            <div class="rounded-2xl border border-success/40 bg-success/10 p-6 space-y-3">
              <h1 class="text-2xl font-bold">Request sent</h1>
              <p :if={@sent != []}>
                {Enum.map_join(@sent, ", ", & &1.name)} will contact you directly with rates and pickup details.
              </p>
              <.link navigate={~p"/"} class="link">Back to the directory</.link>
            </div>
          <% @candidates == [] -> %>
            <h1 class="text-2xl font-bold">Get shipping quotes</h1>
            <p class="opacity-80">
              No shippers on this route take online requests yet. Contact them directly from their listings.
            </p>
            <.link navigate={~p"/"} class="btn btn-primary">Find a shipper</.link>
          <% true -> %>
            <header class="space-y-2">
              <h1 class="text-2xl font-bold">
                {if @company, do: "Get a quote from #{@company.name}", else: "Get free quotes"}
              </h1>
              <p class="opacity-80">
                One form, sent only to the shippers you choose. They'll contact you directly.
              </p>
            </header>

            <.form
              for={@form}
              id="quote-form"
              phx-change="validate"
              phx-submit="submit"
              class="space-y-4"
            >
              <fieldset :if={!@company} class="space-y-2">
                <legend class="text-sm font-medium">
                  Send to (up to {Leads.max_companies()})
                </legend>
                <input type="hidden" name="companies[]" value="" />
                <label
                  :for={company <- @candidates}
                  class={[
                    "flex cursor-pointer items-center gap-3 rounded-xl border p-3 transition",
                    if(company.id in @selected,
                      do: "border-primary bg-primary/5",
                      else: "border-base-300"
                    )
                  ]}
                >
                  <input
                    type="checkbox"
                    name="companies[]"
                    value={company.id}
                    checked={company.id in @selected}
                    disabled={
                      company.id not in @selected and length(@selected) >= Leads.max_companies()
                    }
                    class="checkbox checkbox-sm checkbox-primary"
                  />
                  <span class="font-medium">{company.name}</span>
                  <span class="ml-auto text-xs opacity-60">{company.city}</span>
                </label>
              </fieldset>

              <div class="grid gap-x-4 sm:grid-cols-2">
                <.input
                  field={@form[:origin_metro]}
                  type="select"
                  label="Shipping from"
                  options={@metros}
                  required
                />
                <.input
                  field={@form[:destination]}
                  type="select"
                  label="Shipping to"
                  options={@destinations}
                  required
                />
                <.input field={@form[:barrels]} type="number" label="Barrels" min="0" max="100" />
                <.input field={@form[:boxes]} type="number" label="Boxes" min="0" max="100" />
              </div>
              <.input field={@form[:other_items]} label="Anything else? (vehicle, appliances...)" />
              <div class="grid gap-x-4 sm:grid-cols-2">
                <.input
                  field={@form[:pickup_needed]}
                  type="select"
                  label="Pickup"
                  options={[{"I'll drop off", "false"}, {"Please pick up", "true"}]}
                />
                <.input field={@form[:ship_by]} type="date" label="Ship by (optional)" />
              </div>
              <.input field={@form[:name]} label="Your name" required />
              <div class="grid gap-x-4 sm:grid-cols-2">
                <.input field={@form[:phone]} type="tel" label="Phone" />
                <.input field={@form[:email]} type="email" label="Email" />
              </div>
              <.input field={@form[:notes]} type="textarea" label="Notes (optional)" />

              <%!-- Honeypot: hidden from people, filled by bots. --%>
              <div class="hidden" aria-hidden="true">
                <label>Website <input type="text" name="website" tabindex="-1" autocomplete="off" /></label>
              </div>

              <p
                :if={selected_companies(@candidates, @selected) != []}
                id="consent"
                class="rounded-xl bg-base-200 p-3 text-xs opacity-80"
              >
                {Leads.consent_text(selected_companies(@candidates, @selected))}
              </p>

              <.button class="btn btn-primary w-full" phx-disable-with="Sending...">
                Send my request
              </.button>
            </.form>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
