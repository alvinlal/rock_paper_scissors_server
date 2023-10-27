# Requirements
# 1. Both players should receive "game_ready" event when 2 players have joined
# 2. A player should get 'opponent_join_timeout' event if the 2nd player haven't joined after join_timeout amount of milliseconds specified in config
# 3. A player should get "opponent_left" event when the opponent player has left
# 4. Player should get "game_not_found" event on rejoin after network disconnect
# 5. Player join should be idempotent
# 6. A player should get "game_timeout" event if the other player doesn't make a move after move_timeout amount of milliseconds specified in config
# 7. Both players should get "game_timeout" event if none of them makes a move after move_timeout amount of milliseconds specified in config
# 8. A player gets "opponent_made_move" event when the opponent has made a move
# 9. Players should be able to make moves and get results correctly

defmodule RockPaperScissorsWeb.GameChannelTest do
  use RockPaperScissorsWeb.ChannelCase, async: true
  alias RockPaperScissors.Referee
  import ExUnit.CaptureIO

  setup do
    game_channel_id = UUID.uuid4()
    {:ok, pid} = GenServer.start_link(Referee, {game_channel_id})
    %{game_channel_id: game_channel_id, referee_pid: pid}
  end

  test "Both players should receive 'game_ready' event when 2 players have joined", %{
    game_channel_id: game_channel_id
  } do
    joinGameChannel(game_channel_id, UUID.uuid4())
    joinGameChannel(game_channel_id, UUID.uuid4())
    assert_broadcast "game_ready", _
  end

  test "A player should get 'opponent_join_timeout' event if the 2nd player haven't joined after join_timeout amount of milliseconds specified in config",
       %{
         game_channel_id: game_channel_id,
         referee_pid: referee_pid
       } do
    Process.monitor(referee_pid)
    joinGameChannel(game_channel_id, UUID.uuid4())

    assert_broadcast "opponent_join_timeout",
                     _,
                     Application.get_env(:rock_paper_scissors, RockPaperScissorsWeb.Endpoint)[
                       :join_timeout
                     ] + 100

    assert_receive {:DOWN, _, _, _, :normal}
  end

  test "A player should get 'opponent_left' event when the opponent player has left", %{
    game_channel_id: game_channel_id,
    referee_pid: referee_pid
  } do
    Process.monitor(referee_pid)
    joinGameChannel(game_channel_id, UUID.uuid4())
    {_, _, socket} = joinGameChannel(game_channel_id, UUID.uuid4())
    Process.unlink(socket.channel_pid)

    leaveGameChannel(socket)
    assert_push "opponent_left", _
    assert_receive {:DOWN, _, _, _, :normal}
  end

  test "Player should get 'game_not_found' event on rejoin after network disconnect" do
    joinGameChannel(UUID.uuid4(), UUID.uuid4())
    assert_broadcast "game_not_found", _
  end

  test "Player join should be idempotent", %{game_channel_id: game_channel_id} do
    player_id = UUID.uuid4()

    joinGameChannel(game_channel_id, player_id)
    joinGameChannel(game_channel_id, UUID.uuid4())
    assert_push "game_ready", _
    capture_io(fn -> :c.flush() end)
    joinGameChannel(game_channel_id, player_id)
    refute_push "game_ready", _
  end

  test "A player should get 'move_timeout' event if the other player doesn't make a move after move_timeout amount of milliseconds specified in config",
       %{game_channel_id: game_channel_id, referee_pid: referee_pid} do
    Process.monitor(referee_pid)
    player_id_a = UUID.uuid4()
    player_id_b = UUID.uuid4()

    {_, _, socketA} = joinGameChannel(game_channel_id, player_id_a)
    {_, _, socketB} = joinGameChannel(game_channel_id, player_id_b)

    push(socketA, "move", %{"player_id" => player_id_a, "move" => "r"})
    push(socketB, "move", %{"player_id" => player_id_b, "move" => "r"})

    assert_broadcast "move_timeout",
                     %{},
                     Application.get_env(:rock_paper_scissors, RockPaperScissorsWeb.Endpoint)[
                       :move_timeout
                     ] + 100

    assert_receive {:DOWN, _, _, _, :normal}
  end

  test "Both players should get 'move_timeout' event if none of them makes a move after move_timeout amount of milliseconds specified in config",
       %{game_channel_id: game_channel_id, referee_pid: referee_pid} do
    Process.monitor(referee_pid)
    player_id_a = UUID.uuid4()
    player_id_b = UUID.uuid4()

    joinGameChannel(game_channel_id, player_id_a)
    joinGameChannel(game_channel_id, player_id_b)

    assert_broadcast "move_timeout",
                     %{},
                     Application.get_env(:rock_paper_scissors, RockPaperScissorsWeb.Endpoint)[
                       :move_timeout
                     ] + 100

    assert_receive {:DOWN, _, _, _, :normal}
  end

  test " A player gets 'opponent_made_move' event when the opponent has made a move", %{
    game_channel_id: game_channel_id
  } do
    player_id_a = UUID.uuid4()
    player_id_b = UUID.uuid4()

    {_, _, socketA} = joinGameChannel(game_channel_id, player_id_a)
    joinGameChannel(game_channel_id, player_id_b)

    push(socketA, "move", %{"player_id" => player_id_a, "move" => "r"})

    assert_push "opponent_made_move", _
  end

  # Helpers
  defp joinGameChannel(game_channel_id, player_id) do
    RockPaperScissorsWeb.Socket
    |> socket(nil, %{})
    |> subscribe_and_join(
      RockPaperScissorsWeb.GameChannel,
      "game:#{game_channel_id}",
      %{"player_id" => player_id}
    )
  end

  defp leaveGameChannel(socket) do
    leave(socket)
  end
end
