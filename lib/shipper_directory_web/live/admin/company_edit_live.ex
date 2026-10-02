defmodule ShipperDirectoryWeb.Admin.CompanyEditLive do
  @moduledoc """
  Edit a company's details, see its owner and claim history, and remove
  an owner.
  """
  use ShipperDirectoryWeb, :live_view

  import ShipperDirectoryWeb.CompanyForm, only: [company_form: 1]

  alias ShipperDirectory.Directory
  alias ShipperDirectoryWeb.CompanyForm

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    company = Directory.get_company!(id)

    {:ok,
     socket
     |> assign(page_title: "Edit #{company.name}", noindex: true)
     |> assign_company(company)}
  end

  @impl true
  def handle_event("save", %{"company" => params}, socket) do
    attrs = CompanyForm.attrs(params, CompanyForm.admin_fields())

    case Directory.update_company(socket.assigns.company, attrs) do
      {:ok, company} ->
        {:noreply, socket |> put_flash(:info, "Saved") |> assign_company(company)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Couldn't save: #{Exception.message(error)}")}
    end
  end

  def handle_event("remove_owner", _params, socket) do
    company = Directory.remove_owner!(socket.assigns.company)
    {:noreply, socket |> put_flash(:info, "Owner removed") |> assign_company(company)}
  end

  defp assign_company(socket, company) do
    # Admin is trusted (basic auth), and User has policies with no admin actor.
    company = Ash.load!(company, [:owner], authorize?: false)

    assign(socket,
      company: company,
      claims: Directory.claims_for_company!(company.id),
      form: CompanyForm.to_form(company, CompanyForm.admin_fields())
    )
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

      <div :if={@company.owner} class="alert alert-info">
        <.icon name="hero-check-badge" />
        <span>
          Claimed by <strong>{@company.owner.email}</strong>
          on {Calendar.strftime(@company.claimed_at, "%b %d, %Y")}
        </span>
        <button
          phx-click="remove_owner"
          data-confirm="Remove this owner? They'll lose edit access."
          class="btn btn-sm"
        >
          Remove owner
        </button>
      </div>

      <.company_form form={@form} company={@company} fields={CompanyForm.admin_fields()} />

      <section :if={@claims != []} class="space-y-2 pt-6">
        <h2 class="font-semibold">Claim attempts</h2>
        <ul class="text-sm space-y-1">
          <li :for={claim <- @claims}>
            {Calendar.strftime(claim.inserted_at, "%b %d %H:%M")} · {claim.claimant_name} ({claim.claimant_email}) via {claim.method} to {claim.destination} ·
            <strong>{claim.status}</strong>
            <span :if={claim.attempts > 0}>({claim.attempts} wrong codes)</span>
          </li>
        </ul>
      </section>
    </Layouts.app>
    """
  end
end
