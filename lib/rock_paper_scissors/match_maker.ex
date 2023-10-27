defmodule RockPaperScissors.MatchMaker do
  use GenServer
  alias RockPaperScissors.Referee
  alias RockPaperScissorsWeb.Endpoint
  require Logger

  # Client API
  def registerPlayer({session_id, game_id}) do
    GenServer.cast({:global, MatchMaker}, {:register_player, {session_id, game_id}})
  end

  def deRegisterPlayer({session_id, game_id}) do
    GenServer.cast({:global, MatchMaker}, {:deregister_player, {session_id, game_id}})
  end

  # for tests only
  def resetState() do
    GenServer.call({:global, MatchMaker}, {:reset_state})
  end

  # Server API
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: {:global, MatchMaker})
  end

  @impl true
  def init(_args) do
    Logger.info("started matchmaker")
    {:ok, {nil, nil}}
  end

  @impl true
  def handle_cast({:register_player, {new_player_session_id, new_player_game_id}}, state) do
    new_player_id = new_player_session_id <> ":" <> new_player_game_id
    Logger.info("Got matchmaking request for player ")

    case state do
      {nil, nil} ->
        Logger.info("broadcasting no_players to #{new_player_id}")
        Endpoint.broadcast("lobby:player:" <> new_player_id, "no_players", %{})
        {:noreply, {new_player_session_id, new_player_game_id}}

      {^new_player_session_id, _} ->
        {:noreply, {new_player_session_id, new_player_game_id}}

      {waiting_player_session_id, waiting_player_game_id}
      when waiting_player_session_id != new_player_session_id and
             waiting_player_game_id != new_player_game_id ->
        game_channel_id = UUID.uuid4()
        waiting_player_id = waiting_player_session_id <> ":" <> waiting_player_game_id

        Logger.info(
          "broadcasting got_opponent to #{waiting_player_id} and #{new_player_id} with channel id #{game_channel_id}"
        )

        GenServer.start(Referee, {game_channel_id})

        Endpoint.broadcast("lobby:player:" <> new_player_id, "got_opponent", %{
          game_channel_id: game_channel_id
        })

        Endpoint.broadcast("lobby:player:" <> waiting_player_id, "got_opponent", %{
          game_channel_id: game_channel_id
        })

        {:noreply, {nil, nil}}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast(
        {:deregister_player, {leaving_player_session_id, leaving_player_game_id}},
        state
      ) do
    case state do
      {^leaving_player_session_id, ^leaving_player_game_id} ->
        Logger.info("reseting matchmaker state back to nil")
        {:noreply, {nil, nil}}

      _ ->
        Logger.info("no need to reset matchmaker ")
        {:noreply, state}
    end
  end

  # for tests only
  @impl true
  def handle_call({:reset_state}, _from, _state) do
    {:reply, :ok, {nil, nil}}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.info("Matchmaker got unknown message :- #{msg}")
    {:noreply, state}
  end
end
