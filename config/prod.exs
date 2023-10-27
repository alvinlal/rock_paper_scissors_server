import Config

config :rock_paper_scissors, RockPaperScissorsWeb.Endpoint,
  join_timeout: 5000,
  move_timeout: 60000

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
