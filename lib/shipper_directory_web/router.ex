defmodule ShipperDirectoryWeb.Router do
  use ShipperDirectoryWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ShipperDirectoryWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :admin do
    plug ShipperDirectoryWeb.Plugs.AdminAuth
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  scope "/", ShipperDirectoryWeb do
    pipe_through :browser

    # Listing owners (signed in by magic link).
    ash_authentication_live_session :authenticated_routes,
      on_mount: {ShipperDirectoryWeb.LiveUserAuth, :live_user_required} do
      live "/my/listings", Owner.MyListingsLive, :index
      live "/my/listings/:slug", Owner.ListingEditLive, :edit
      live "/my/leads", Owner.LeadsLive, :index
    end

    # Public pages. A signed-in owner is optional.
    ash_authentication_live_session :public,
      on_mount: {ShipperDirectoryWeb.LiveUserAuth, :live_user_optional} do
      live "/", DirectoryLive, :index
      live "/shippers/:slug/claim", ClaimLive, :new
      live "/quote", QuoteLive, :new
    end
  end

  scope "/", ShipperDirectoryWeb do
    pipe_through :browser

    get "/shippers/:slug", CompanyController, :show
    get "/ship-barrel", RouteController, :index
    get "/ship-barrel/:route", RouteController, :show
    auth_routes AuthController, ShipperDirectory.Accounts.User, path: "/auth"

    sign_out_route AuthController, "/sign-out",
      overrides: [ShipperDirectoryWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    # Listing owners sign in with a magic link (no passwords).
    sign_in_route auth_routes_prefix: "/auth",
                  on_mount: [{ShipperDirectoryWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    ShipperDirectoryWeb.AuthOverrides,
                    AshAuthentication.Phoenix.Overrides.Default
                  ]

    magic_sign_in_route(ShipperDirectory.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [ShipperDirectoryWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    )
  end

  scope "/", ShipperDirectoryWeb do
    get "/sitemap.xml", SitemapController, :index
    get "/robots.txt", SitemapController, :robots
  end

  scope "/admin", ShipperDirectoryWeb.Admin do
    pipe_through [:browser, :admin]

    live "/", CompaniesLive, :index
    live "/companies/:id", CompanyEditLive, :edit
    live "/prospects", ProspectsLive, :index
    live "/leads", LeadsLive, :index
    live "/placements", PlacementsLive, :index
    get "/ledger.csv", LedgerExportController, :index
    get "/prospects.csv", ProspectExportController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", ShipperDirectoryWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:shipper_directory, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ShipperDirectoryWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
