defmodule ShipperDirectoryWeb.Admin.CompanyEditLive do
  @moduledoc """
  Edit a company's public details: contact, services, destinations,
  origin metros, and sailing schedule. It shows which metros and
  destinations the free text maps to, so the admin can tell whether the
  company will appear on route pages.
  """
  use ShipperDirectoryWeb, :live_view

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Directory.Destinations
  alias ShipperDirectory.Directory.Types.Service
  alias ShipperDirectory.Discovery.Metros

  @text_fields ~w(name phone email website_url address city state sailing_schedule notes)
  @list_fields ~w(destinations origin_metros)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    company = Directory.get_company!(id)

    {:ok,
     socket
     |> assign(page_title: "Edit #{company.name}", noindex: true)
     |> assign(services: Enum.map(Service.values(), &to_string/1))
     |> assign_company(company)}
  end

  @impl true
  def handle_event("save", %{"company" => params}, socket) do
    attrs =
      Map.new(@text_fields, &{String.to_existing_atom(&1), blank_to_nil(params[&1])})
      |> Map.merge(Map.new(@list_fields, &{String.to_existing_atom(&1), split(params[&1])}))
      |> Map.put(:services, params |> Map.get("services", []) |> Enum.reject(&(&1 == "")))

    case Directory.update_company(socket.assigns.company, attrs) do
      {:ok, company} ->
        {:noreply, socket |> put_flash(:info, "Saved") |> assign_company(company)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Couldn't save: #{Exception.message(error)}")}
    end
  end

  defp assign_company(socket, company) do
    params =
      Map.new(@text_fields, &{&1, Map.get(company, String.to_existing_atom(&1))})
      |> Map.merge(
        Map.new(
          @list_fields,
          &{&1, Enum.join(Map.get(company, String.to_existing_atom(&1)), ", ")}
        )
      )
      |> Map.put("services", Enum.map(company.services, &to_string/1))

    assign(socket, company: company, form: to_form(params, as: :company))
  end

  defp split(nil), do: []

  defp split(value) do
    value |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} admin>
      <nav class="text-sm opacity-70">
        <.link navigate={~p"/admin"} class="hover:underline">Companies</.link>
        <span class="mx-1">/</span> {@company.name}
      </nav>

      <.header>
        {@company.name}
        <:subtitle>
          Status: {@company.status} · Presence: {@company.presence_status || "unchecked"}
          <.link
            :if={@company.status == :published}
            navigate={~p"/shippers/#{@company.slug}"}
            class="link ml-2"
          >
            View public page
          </.link>
        </:subtitle>
      </.header>

      <.form for={@form} id="company-form" phx-submit="save" class="grid gap-x-6 sm:grid-cols-2">
        <.input field={@form[:name]} label="Name" required />
        <.input field={@form[:website_url]} type="url" label="Website" />
        <.input field={@form[:phone]} label="Phone" />
        <.input field={@form[:email]} type="email" label="Email" />
        <.input field={@form[:address]} label="Street address" />
        <div class="grid grid-cols-3 gap-3">
          <div class="col-span-2"><.input field={@form[:city]} label="City" /></div>
          <.input field={@form[:state]} label="State" maxlength="2" />
        </div>
        <div>
          <.input
            field={@form[:origin_metros]}
            label="Ships from (comma separated)"
            placeholder="Brooklyn, Queens"
          />
          <p class="-mt-1 mb-3 text-xs opacity-70">
            Metros: {slug_names(@company.metro_slugs, &Metros.name/1)}
          </p>
        </div>
        <div>
          <.input
            field={@form[:destinations]}
            label="Ships to (comma separated)"
            placeholder="Jamaica, Guyana, T&T"
          />
          <p class="-mt-1 mb-3 text-xs opacity-70">
            Route destinations: {slug_names(@company.destination_slugs, &Destinations.name/1)}
          </p>
        </div>
        <fieldset class="fieldset mb-2 sm:col-span-2">
          <legend class="fieldset-legend">Services</legend>
          <input type="hidden" name="company[services][]" value="" />
          <div class="flex flex-wrap gap-4">
            <label :for={service <- @services} class="label cursor-pointer gap-2 capitalize">
              <input
                type="checkbox"
                name="company[services][]"
                value={service}
                checked={service in @form[:services].value}
                class="checkbox checkbox-sm"
              />
              {service}
            </label>
          </div>
        </fieldset>
        <.input
          field={@form[:sailing_schedule]}
          label="Sailing schedule"
          placeholder="Sails Mon/Wed/Fri"
        />
        <.input field={@form[:notes]} type="textarea" label="Internal notes" />
        <div class="sm:col-span-2">
          <.button variant="primary" phx-disable-with="Saving...">Save</.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  defp slug_names([], _fun), do: "none (won't appear on route pages)"
  defp slug_names(slugs, fun), do: Enum.map_join(slugs, ", ", fun)
end
