defmodule RockPaperScissorsWeb.GameChannel do
  alias RockPaperScissorsWeb.Endpoint
  alias RockPaperScissors.Referee
  alias RockPaperScissors.Terminator
  use Phoenix.Channel
  require Logger

  # Channel Callbacks
  @impl true
  def join("game:" <> game_channel_id, %{"player_id" => player_id}, socket) do
    :ok =
      Terminator.monitor(
        socket.channel_pid,
        {__MODULE__, :player_left, [{game_channel_id}]}
      )

    game_process = Registry.lookup(Registry.RpsRegistry, game_channel_id)

    case length(game_process) do
      0 ->
        Logger.info("Game referee not found")
        Endpoint.broadcast(socket.topic, "game_not_found", %{})

      _ ->
        Logger.info("Referee found")
        Referee.playerJoin(game_channel_id, player_id, self())
    end

    {:ok, socket}
  end

  @impl true
  def handle_in(
        "move",
        %{"player_id" => player_id, "move" => move},
        socket
      ) do
    [_, game_channel_id] = String.split(socket.topic, ":")
    Referee.playerMove(game_channel_id, player_id, move)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:game_round_result, result}, socket) do
    push(socket, "game_round_result", %{result: result})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:game_match_result, result}, socket) do
    push(socket, "game_match_result", %{result: result})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:opponent_made_move}, socket) do
    push(socket, "opponent_made_move", %{})
    {:noreply, socket}
  end

  # Helper functions
  def player_left({game_channel_id}) do
    Referee.playerLeft(game_channel_id)
  end
end
