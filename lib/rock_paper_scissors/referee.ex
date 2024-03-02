defmodule RockPaperScissors.Referee do
  alias RockPaperScissors.GameChannelEvents
  alias RockPaperScissorsWeb.Endpoint
  use GenServer
  require Logger

  @game_matrix %{
    "r" => %{
      "r" => "draw",
      "p" => "loose",
      "s" => "win"
    },
    "p" => %{
      "r" => "win",
      "p" => "draw",
      "s" => "loose"
    },
    "s" => %{
      "r" => "loose",
      "p" => "win",
      "s" => "draw"
    }
  }

  # Client API
  def playerJoin(referee_pid, player_id, channel_pid) do
    GenServer.cast(
      {:via, Registry, {Registry.RpsRegistry, referee_pid}},
      {:player_join, player_id, channel_pid}
    )
  end

  def playerLeft(referee_pid) do
    GenServer.cast({:via, Registry, {Registry.RpsRegistry, referee_pid}}, {:player_left})
  end

  def playerMove(referee_pid, player_id, move) do
    GenServer.cast(
      {:via, Registry, {Registry.RpsRegistry, referee_pid}},
      {:player_move, player_id, move}
    )
  end

  # Server API
  def start(args) do
    Logger.info(args)

    GenServer.start_link(
      __MODULE__,
      args
    )
  end

  @impl true
  def init({game_channel_id}) do
    Logger.info("Referee for game channel #{game_channel_id} started")
    Registry.register(Registry.RpsRegistry, game_channel_id, %{})

    Process.send_after(
      self(),
      {:check_join_timeout},
      Application.get_env(:rock_paper_scissors, RockPaperScissorsWeb.Endpoint)[:join_timeout]
    )

    move_timeout_ref =
      Process.send_after(
        self(),
        {:move_timeout},
        Application.get_env(:rock_paper_scissors, RockPaperScissorsWeb.Endpoint)[:move_timeout]
      )

    {:ok,
     %{
       players_joined: 0,
       game_channel_id: game_channel_id,
       rounds_played: 0,
       current_move: nil,
       players: %{},
       move_timeout_ref: move_timeout_ref
     }}
  end

  @impl true
  def handle_cast({:player_join, player_id, channel_pid}, state) do
    Logger.info("#{player_id} joined game channel #{state.game_channel_id}")

    # if(state.players_joined == 1) do
    #   Logger.info("All players joined game channel #{state.game_channel_id}, emiting game_ready")
    #   Endpoint.broadcast("game:#{state.game_channel_id}", GameChannelEvents.game_ready(), %{})
    # end

    case state.players_joined do
      players_joined when players_joined == 0 or players_joined == 1 ->
        {:noreply,
         %{
           state
           | players:
               Map.put(state.players, player_id, %{
                 rounds_won: 0,
                 channel_pid: channel_pid
               }),
             players_joined: state.players_joined + 1
         }}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:player_move, player_id, move}, state) do
    Process.cancel_timer(state.move_timeout_ref)

    move_timeout_ref =
      Process.send_after(
        self(),
        {:move_timeout},
        Application.get_env(:rock_paper_scissors, RockPaperScissorsWeb.Endpoint)[:move_timeout]
      )

    case is_nil(state.current_move) do
      true ->
        Enum.each(state.players, fn {map_player_id, player_data} ->
          if map_player_id != player_id do
            send(player_data.channel_pid, {:opponent_made_move})
          end
        end)

        {:noreply,
         %{
           state
           | current_move: %{move: move, player_id: player_id},
             move_timeout_ref: move_timeout_ref
         }}

      false ->
        {player_id_a, player_a_result, player_id_b, player_b_result, winner_player_id} =
          get_results({state.current_move.player_id, state.current_move.move, player_id, move})

        new_state =
          %{"state" => state, "winner_player_id" => winner_player_id}
          |> set_rounds_won()
          |> Map.update(:rounds_played, 0, fn value -> value + 1 end)

        case has_won_series(
               new_state.players,
               player_id_a,
               player_id_b
             ) do
          {true, winner_player_id, looser_player_id} ->
            send(state.players[winner_player_id].channel_pid, {:game_match_result, "win"})
            send(state.players[looser_player_id].channel_pid, {:game_match_result, "loose"})
            Process.exit(self(), :normal)

          {false, nil, nil} ->
            send(
              state.players[player_id_a].channel_pid,
              {:game_round_result, player_a_result}
            )

            send(
              state.players[player_id_b].channel_pid,
              {:game_round_result, player_b_result}
            )
        end

        {:noreply, %{new_state | current_move: nil, move_timeout_ref: move_timeout_ref}}
    end
  end

  @impl true
  def handle_cast({:player_left}, state) do
    Logger.info("A player left the game, killing referee")
    Endpoint.broadcast("game:#{state.game_channel_id}", GameChannelEvents.opponent_left(), %{})
    Process.exit(self(), :normal)
  end

  @impl true
  def handle_info({:move_timeout}, state) do
    Endpoint.broadcast("game:#{state.game_channel_id}", GameChannelEvents.move_timeout(), %{})
    Process.exit(self(), :normal)
  end

  @impl true
  def handle_info({:check_join_timeout}, state) do
    if(state.players_joined != 2) do
      Logger.info(
        "2nd player haven't joined yet, emiting opponent_join_timeout and killing referee"
      )

      Endpoint.broadcast(
        "game:#{state.game_channel_id}",
        GameChannelEvents.opponent_join_timeout(),
        %{}
      )

      Process.exit(self(), :normal)
    end

    {:noreply, state}
  end

  # private funcs
  defp get_results({player_id_a, move_a, player_id_b, move_b}) do
    result = @game_matrix[move_a][move_b]

    case result do
      "draw" -> {player_id_a, "draw", player_id_b, "draw", nil}
      "win" -> {player_id_a, "win", player_id_b, "loose", player_id_a}
      "loose" -> {player_id_a, "loose", player_id_b, "win", player_id_b}
    end
  end

  defp has_won_series(players, player_id_a, player_id_b) do
    case {players[player_id_a].rounds_won, players[player_id_b].rounds_won} do
      {a, _b} when a == 3 -> {true, player_id_a, player_id_b}
      {_a, b} when b == 3 -> {true, player_id_b, player_id_a}
      _ -> {false, nil, nil}
    end
  end

  defp set_rounds_won(%{"state" => state, "winner_player_id" => winner_player_id}) do
    case is_nil(winner_player_id) do
      true ->
        state

      false ->
        put_in(
          state,
          [:players, winner_player_id, :rounds_won],
          state.players[winner_player_id].rounds_won + 1
        )
    end
  end

  # @todo emit something went wrong when referee goes down
end
