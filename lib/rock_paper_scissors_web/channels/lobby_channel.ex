defmodule RockPaperScissorsWeb.LobbyChannel do
  alias RockPaperScissors.MatchMaker
  alias RockPaperScissors.Terminator
  use Phoenix.Channel
  require Logger

  def join("lobby:player:" <> player_id, _message, socket) do
    [session_id, game_id] = String.split(player_id, ":")
    :ok = Terminator.monitor(self(), {__MODULE__, :leave, [{session_id, game_id}]})
    MatchMaker.registerPlayer({session_id, game_id})
    {:ok, socket}
  end

  def leave({session_id, game_id}) do
    Logger.info("player #{session_id}:#{game_id} leaved player channel")
    MatchMaker.deRegisterPlayer({session_id, game_id})
  end
end
