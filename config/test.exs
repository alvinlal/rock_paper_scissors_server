import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :rock_paper_scissors, RockPaperScissorsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "rSWeUswFvoMX/tDg/Q12JejJFItgvnygRRVrt/SXg+Gkc5j3BATvUloVJBHKwDeu",
  server: false,
  join_timeout: 100,
  move_timeout: 200

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
