defmodule ShipperDirectoryWeb.CompanyForm do
  @moduledoc """
  The company details form, shared by the admin edit page and the owner's
  listing editor. Each caller passes the fields it may edit. List fields
  (destinations, origin metros) are comma-separated text in the form.
  """
  use ShipperDirectoryWeb, :html

  alias ShipperDirectory.Directory.Destinations
  alias ShipperDirectory.Directory.Types.Service
  alias ShipperDirectory.Discovery.Metros

  @list_fields ~w(destinations origin_metros)a
  @admin_fields ~w(name website_url phone email address city state origin_metros destinations services sailing_schedule neighborhood whatsapp_number next_sailing_date christmas_cutoff_date pickup_available notes)a
  @owner_fields ~w(website_url phone email address city state origin_metros destinations services sailing_schedule)a

  def admin_fields, do: @admin_fields
  def owner_fields, do: @owner_fields

  @doc "A Phoenix form for the company's current values."
  def to_form(company, fields) do
    fields
    |> Map.new(fn
      field when field in @list_fields ->
        {to_string(field), Enum.join(Map.get(company, field), ", ")}

      :services ->
        {"services", Enum.map(company.services, &to_string/1)}

      field ->
        {to_string(field), Map.get(company, field)}
    end)
    |> Phoenix.Component.to_form(as: :company)
  end

  @doc "Submitted params to action attrs, for the given fields only."
  def attrs(params, fields) do
    Map.new(fields, fn
      field when field in @list_fields -> {field, split(params[to_string(field)])}
      :services -> {:services, params |> Map.get("services", []) |> Enum.reject(&(&1 == ""))}
      field -> {field, blank_to_nil(params[to_string(field)])}
    end)
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :company, :map, required: true
  attr :fields, :list, required: true
  attr :id, :string, default: "company-form"
  attr :submit_label, :string, default: "Save"

  def company_form(assigns) do
    assigns = assign(assigns, services: Enum.map(Service.values(), &to_string/1))

    ~H"""
    <.form for={@form} id={@id} phx-submit="save" class="grid gap-x-6 sm:grid-cols-2">
      <.input :if={:name in @fields} field={@form[:name]} label="Name" required />
      <.input field={@form[:website_url]} type="url" label="Website" />
      <.input field={@form[:phone]} label="Phone" />
      <.input field={@form[:email]} type="email" label="Public email" />
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
          Listed under: {slug_names(@company.metro_slugs, &Metros.name/1)}
        </p>
      </div>
      <div>
        <.input
          field={@form[:destinations]}
          label="Ships to (comma separated)"
          placeholder="Jamaica, Guyana, T&T"
        />
        <p class="-mt-1 mb-3 text-xs opacity-70">
          Route pages: {slug_names(@company.destination_slugs, &Destinations.name/1)}
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
              checked={service in (@form[:services].value || [])}
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
      <.input :if={:neighborhood in @fields} field={@form[:neighborhood]} label="Neighborhood" />
      <.input
        :if={:whatsapp_number in @fields}
        field={@form[:whatsapp_number]}
        label="WhatsApp number"
        placeholder="+1 718 555 0101"
      />
      <.input
        :if={:next_sailing_date in @fields}
        field={@form[:next_sailing_date]}
        type="date"
        label="Next sailing"
      />
      <.input
        :if={:christmas_cutoff_date in @fields}
        field={@form[:christmas_cutoff_date]}
        type="date"
        label="Christmas cutoff (last drop-off)"
      />
      <.input
        :if={:pickup_available in @fields}
        field={@form[:pickup_available]}
        type="select"
        label="Pickup available"
        prompt="Unknown"
        options={[{"Yes", "true"}, {"No", "false"}]}
      />
      <.input :if={:notes in @fields} field={@form[:notes]} type="textarea" label="Internal notes" />
      <div class="sm:col-span-2">
        <.button variant="primary" phx-disable-with="Saving...">{@submit_label}</.button>
      </div>
    </.form>
    """
  end

  defp slug_names([], _fun), do: "none (won't appear on route pages)"
  defp slug_names(slugs, fun), do: Enum.map_join(slugs, ", ", fun)

  defp split(nil), do: []

  defp split(value),
    do: value |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
