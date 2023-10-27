# Requirements
# 1. A player should be able to join the channel and get "no_opponents" if there are no other players joined
# 2. A player should be able to join the channel and get matchmaked if there are other players joined
# 3. A player should not be matchmaked with himself on the race condition that the new player_join event reach's the matchmaker before the old player_leave event reach's the matchmaker on browser refresh
# 4. A player should be matchmaked on the race condition that the old player_leave event reach's the matchmaker after the new player_join event reach's the matchmaker on browser refresh

defmodule RockPaperScissorsWeb.LobbyChannelTest do
  use RockPaperScissorsWeb.ChannelCase, async: true
  require Logger
  alias RockPaperScissors.MatchMaker

  test "A player should be able to join the channel and get 'no_opponents' if there are no other players joined" do
    joinLobbyChannel(UUID.uuid4(), UUID.uuid4())

    assert_push "no_players", _, 200
    MatchMaker.resetState()
  end

  test "A player should be able to join the channel and get matchmaked if there are other players joined" do
    joinLobbyChannel(UUID.uuid4(), UUID.uuid4())
    joinLobbyChannel(UUID.uuid4(), UUID.uuid4())

    assert_push "got_opponent", %{game_channel_id: _}

    joinLobbyChannel(UUID.uuid4(), UUID.uuid4())
    joinLobbyChannel(UUID.uuid4(), UUID.uuid4())

    assert_push "got_opponent", %{game_channel_id: _}
    MatchMaker.resetState()
  end

  test "A player should not be matchmaked with himself on browser refresh" do
    session_id = UUID.uuid4()
    game_id = UUID.uuid4()

    joinLobbyChannel(session_id, game_id)

    # Browser refresh's

    joinLobbyChannel(session_id, UUID.uuid4())

    assert_push "no_players", _

    joinLobbyChannel(UUID.uuid4(), UUID.uuid4())

    assert_push "got_opponent", %{game_channel_id: _}

    MatchMaker.resetState()
  end

  test "A player should be matchmaked on the race condition that the old player_leave event reach's the matchmaker after the new player_join event reach's the matchmaker on browser refresh" do
    session_id = UUID.uuid4()
    game_id = UUID.uuid4()

    {_, _, socket} = joinLobbyChannel(session_id, game_id)

    Process.unlink(socket.channel_pid)

    # Browser refresh's

    joinLobbyChannel(session_id, UUID.uuid4())

    leaveLobbyChannel(socket)

    joinLobbyChannel(UUID.uuid4(), UUID.uuid4())

    assert_push "got_opponent", %{game_channel_id: _}

    joinLobbyChannel(UUID.uuid4(), UUID.uuid4())

    assert_push "no_players", _

    MatchMaker.resetState()
  end

  # Helpers
  defp joinLobbyChannel(session_id, game_id) do
    RockPaperScissorsWeb.Socket
    |> socket(nil, %{})
    |> subscribe_and_join(
      RockPaperScissorsWeb.LobbyChannel,
      "lobby:player:#{session_id}:#{game_id}"
    )
  end

  defp leaveLobbyChannel(socket) do
    leave(socket)
  end
end
