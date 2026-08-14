import Config

config :phoenix_test, otp_app: :frmn_play, endpoint: FrmnPlayWeb.Endpoint

# The server is enabled so Playwright-driven browser tests can connect to it.
#
# `:url` has to name the test port too: `Endpoint.url/0` (which test_helper.exs
# hands to Playwright as the base URL) reads `:url`, not `:http`, and would
# otherwise default to port 4000 and drive the browser against a dev server.
config :frmn_play, FrmnPlayWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  url: [host: "localhost", port: 4002, scheme: "http"],
  secret_key_base: "344D/cPay9R2VKsnJHIuELMpAff/awvn3E/LlSwccAwfkyvTy1VeoQ0lQwD58TTZ",
  server: true

# In test we don't send emails
config :frmn_play, FrmnPlay.Mailer, adapter: Swoosh.Adapters.Test

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

# Coverage. `lib/frmn_play_web.ex` is skipped because every "uncovered" line in
# it is a `quote do` inside a `__using__` macro — :cover can't see through macro
# expansion, so those lines can never be marked covered no matter what we test.
#
# `core_components.ex` is deliberately NOT skipped: most of it is generated
# components we don't use yet, and leaving it counted keeps that visible as debt
# rather than hiding UI logic once we start adopting it.
config :six,
  skip_files: [~r/lib\/frmn_play_web\.ex$/],
  # Ratchet: sits just under current coverage so it can only be raised, never
  # silently drifted down. Bump it when coverage climbs.
  minimum_coverage: 53.0
