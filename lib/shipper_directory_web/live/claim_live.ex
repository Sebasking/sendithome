defmodule ShipperDirectoryWeb.ClaimLive do
  @moduledoc """
  "Is this your business?" Claim a published listing by verifying a code
  sent to an email at the company's domain or to the listed phone. See
  `ShipperDirectory.Claims`.
  """
  use ShipperDirectoryWeb, :live_view

  alias ShipperDirectory.{Claims, Directory}
  alias ShipperDirectoryWeb.NotFoundError

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    company =
      case Directory.get_published_company(slug) do
        {:ok, company} -> company
        {:error, _} -> raise NotFoundError
      end

    methods = Claims.methods(company)

    {:ok,
     assign(socket,
       company: company,
       methods: methods,
       step: :start,
       claim: nil,
       method: List.first(methods),
       form: to_form(%{"method" => to_string(List.first(methods)), "name" => "", "email" => ""}),
       code_form: to_form(%{"code" => ""}),
       page_title: "Claim #{company.name}",
       noindex: true
     )}
  end

  @impl true
  def handle_event("change", params, socket) do
    method = Enum.find(socket.assigns.methods, &(to_string(&1) == params["method"]))

    {:noreply,
     assign(socket, method: method, form: to_form(Map.take(params, ~w(method name email))))}
  end

  def handle_event("start", params, socket) do
    case Claims.start(socket.assigns.company, params) do
      {:ok, claim} ->
        {:noreply, assign(socket, step: :code, claim: claim) |> clear_flash()}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(form: to_form(Map.take(params, ~w(method name email))))
         |> put_flash(:error, Claims.error_message(reason))}
    end
  end

  def handle_event("verify", %{"code" => code}, socket) do
    case Claims.verify(socket.assigns.claim, code) do
      {:ok, _company} ->
        {:noreply, socket |> assign(step: :done) |> clear_flash()}

      {:error, reason} when reason in [:expired, :locked] ->
        {:noreply,
         socket
         |> assign(step: :start, claim: nil)
         |> put_flash(:error, Claims.error_message(reason))}

      {:error, reason} ->
        claim = Directory.get_claim!(socket.assigns.claim.id)

        {:noreply,
         socket |> assign(claim: claim) |> put_flash(:error, Claims.error_message(reason))}
    end
  end

  def handle_event("restart", _params, socket) do
    {:noreply, assign(socket, step: :start, claim: nil)}
  end

  defp domain(company) do
    case company.website_url && URI.parse(company.website_url).host do
      nil -> nil
      host -> String.replace_prefix(host, "www.", "")
    end
  end

  defp method_label(:email, company), do: "Email me a code at @#{domain(company)}"
  defp method_label(:call, company), do: "Call #{Claims.masked_phone(company)} with a code"
  defp method_label(:sms, company), do: "Text #{Claims.masked_phone(company)} a code"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-lg space-y-6">
        <nav class="text-sm opacity-70">
          <.link navigate={~p"/shippers/#{@company.slug}"} class="hover:underline">
            {@company.name}
          </.link>
          <span class="mx-1">/</span>
          Claim
        </nav>

        <%= cond do %>
          <% not Claims.claimable?(@company) -> %>
            <h1 class="text-2xl font-bold">This listing already has an owner</h1>
            <p class="opacity-80">
              If you run {@company.name} and don't have access, contact us and we'll sort it out.
            </p>
          <% @step == :start -> %>
            <header class="space-y-2">
              <h1 class="text-2xl font-bold">Claim {@company.name}</h1>
              <p class="opacity-80">
                Prove you run this business, then update your listing yourself: services, destinations, sailing schedule, and contact details.
              </p>
            </header>

            <.form
              for={@form}
              id="claim-form"
              phx-change="change"
              phx-submit="start"
              class="space-y-4"
            >
              <fieldset class="space-y-2">
                <legend class="text-sm font-medium">How should we verify you?</legend>
                <label
                  :for={method <- @methods}
                  class={[
                    "flex cursor-pointer items-center gap-3 rounded-xl border p-3 transition",
                    if(@method == method,
                      do: "border-primary bg-primary/5",
                      else: "border-base-300 hover:border-base-content/30"
                    )
                  ]}
                >
                  <input
                    type="radio"
                    name="method"
                    value={method}
                    checked={@method == method}
                    class="radio radio-sm radio-primary"
                  />
                  <span>{method_label(method, @company)}</span>
                </label>
              </fieldset>

              <.input name="name" value={@form[:name].value} label="Your name" required />
              <.input
                name="email"
                type="email"
                value={@form[:email].value}
                required
                label={
                  if @method == :email,
                    do: "Your email at @#{domain(@company)}",
                    else: "Your email (you'll sign in with it)"
                }
                placeholder={
                  if @method == :email, do: "you@#{domain(@company)}", else: "you@example.com"
                }
              />

              <.button class="btn btn-primary w-full" phx-disable-with="Sending...">
                Send my code
              </.button>
            </.form>
          <% @step == :code -> %>
            <header class="space-y-2">
              <h1 class="text-2xl font-bold">Enter your code</h1>
              <p class="opacity-80">
                <%= case @claim.method do %>
                  <% :email -> %>
                    We emailed a 6-digit code to {@claim.destination}.
                  <% :call -> %>
                    We're calling {Claims.masked_phone(@company)} now. The code will be read out twice.
                  <% :sms -> %>
                    We texted a 6-digit code to {Claims.masked_phone(@company)}.
                <% end %>
                It expires in 15 minutes.
              </p>
            </header>

            <.form for={@code_form} id="code-form" phx-submit="verify" class="space-y-4">
              <.input
                name="code"
                value=""
                label="6-digit code"
                inputmode="numeric"
                autocomplete="one-time-code"
                maxlength="6"
                required
              />
              <.button class="btn btn-primary w-full" phx-disable-with="Checking...">
                Verify
              </.button>
            </.form>
            <button phx-click="restart" class="link text-sm">Start over</button>
          <% @step == :done -> %>
            <div class="rounded-2xl border border-success/40 bg-success/10 p-6 space-y-2">
              <h1 class="text-2xl font-bold">You're verified</h1>
              <p>
                {@company.name} is now yours. We sent a sign-in link to <strong>{@claim.claimant_email}</strong>. Open it to edit your listing.
              </p>
            </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
