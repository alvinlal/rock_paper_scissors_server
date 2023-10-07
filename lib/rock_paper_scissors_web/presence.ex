defmodule RockPaperScissorsWeb.Presence do
  use Phoenix.Presence,
    otp_app: :rock_paper_scissors,
    pubsub_server: RockPaperScissors.PubSub
end
