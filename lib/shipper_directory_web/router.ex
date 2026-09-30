defmodule ShipperDirectoryWeb.Router do
  use ShipperDirectoryWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ShipperDirectoryWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :admin do
    plug ShipperDirectoryWeb.Plugs.AdminAuth
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ShipperDirectoryWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/admin", ShipperDirectoryWeb.Admin do
    pipe_through [:browser, :admin]

    live "/", CompaniesLive, :index
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
