defmodule ShipperDirectoryWeb.Owner.ListingEditLive do
  @moduledoc """
  An owner edits their own listing. Name and internal notes stay
  admin-only. A new website URL is re-verified right away, and a site that
  doesn't work takes the listing out of the directory until it's fixed.
  """
  use ShipperDirectoryWeb, :live_view

  import ShipperDirectoryWeb.CompanyForm, only: [company_form: 1]

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Directory.Presence
  alias ShipperDirectoryWeb.CompanyForm

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    user = socket.assigns.current_user

    case Directory.get_company_by_slug(slug) do
      {:ok, %{owner_id: owner_id} = company} when owner_id == user.id ->
        {:ok,
         socket
         |> assign(page_title: "Edit #{company.name}", noindex: true, checking: false)
         |> assign_company(company)}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "That listing isn't yours.")
         |> push_navigate(to: ~p"/my/listings")}
    end
  end

  @impl true
  def handle_event("save", %{"company" => params}, socket) do
    old = socket.assigns.company
    attrs = CompanyForm.attrs(params, CompanyForm.owner_fields())

    case Directory.owner_update_company(old, attrs) do
      {:ok, company}
      when company.website_url != old.website_url and not is_nil(company.website_url) ->
        {:noreply,
         socket
         |> assign_company(company)
         |> assign(checking: true)
         |> put_flash(:info, "Saved. Checking your new website...")
         |> start_async(:check, fn -> Presence.check(company) end)}

      {:ok, company} ->
        {:noreply, socket |> assign_company(company) |> put_flash(:info, "Saved")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Couldn't save: #{Exception.message(error)}")}
    end
  end

  @impl true
  def handle_async(:check, {:ok, company}, socket) do
    message =
      if company.status == :published,
        do: {:info, "Your website checks out. Your listing is live."},
        else:
          {:error,
           "We couldn't verify that website, so your listing is hidden for now. #{company.review_reason}"}

    {:noreply,
     socket
     |> assign(checking: false)
     |> assign_company(company)
     |> put_flash(elem(message, 0), elem(message, 1))}
  end

  def handle_async(:check, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> assign(checking: false)
     |> put_flash(:error, "Website check failed. We'll retry later.")}
  end

  defp assign_company(socket, company) do
    assign(socket,
      company: company,
      form: CompanyForm.to_form(company, CompanyForm.owner_fields())
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <nav class="text-sm opacity-70">
        <.link navigate={~p"/my/listings"} class="hover:underline">My listings</.link>
        <span class="mx-1">/</span> {@company.name}
      </nav>

      <.header>
        {@company.name}
        <:subtitle>
          <span :if={@checking} class="inline-flex items-center gap-1">
            <.icon name="hero-arrow-path" class="size-4 animate-spin" /> Checking your website...
          </span>
          <span :if={!@checking && @company.status == :published}>
            Listed in the directory.
            <.link navigate={~p"/shippers/#{@company.slug}"} class="link">View your page</.link>
          </span>
          <span :if={!@checking && @company.status != :published}>
            Not listed: your website needs to be live and show your business name or phone.
          </span>
        </:subtitle>
      </.header>

      <p class="text-sm opacity-70">
        To change your business name, contact us.
      </p>

      <.company_form
        form={@form}
        company={@company}
        fields={CompanyForm.owner_fields()}
        submit_label="Save listing"
      />
    </Layouts.app>
    """
  end
end
