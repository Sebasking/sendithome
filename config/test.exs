import Config
config :shipper_directory, token_signing_secret: "ybbtK7aXlnLzUCiPvRGAQkvPHnlJwALj"
config :bcrypt_elixir, log_rounds: 1
config :shipper_directory, Oban, testing: :manual

# Presence checks hit Req.Test stubs instead of the network.
config :shipper_directory, :presence_req_options,
  plug: {Req.Test, ShipperDirectory.Directory.Presence},
  retry: false

config :shipper_directory, :google_places_api_key, "test-key"

config :shipper_directory, :google_places_req_options,
  plug: {Req.Test, ShipperDirectory.Discovery.GooglePlaces},
  retry: false

config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :shipper_directory, ShipperDirectory.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "shipper_directory_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :shipper_directory, ShipperDirectoryWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "OIU5BPLA8YV//u9KbTIH+qGrWJJQ5U5uZEPZJsJ2P7FvDCTJfR9R/YDUKMBE+1b9",
  server: false

# In test we don't send emails
config :shipper_directory, ShipperDirectory.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Write analytics events inline so tests can assert on them.
config :shipper_directory, :async_event_log, false

config :shipper_directory, :admin_auth, username: "admin", password: "secret"
