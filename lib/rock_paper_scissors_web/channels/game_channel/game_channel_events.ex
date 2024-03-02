defmodule RockPaperScissors.GameChannelEvents do
  # emited when both players have joined the game channel
  # @game_ready "game_ready"
  # def game_ready, do: @game_ready

  # referee process has not been created, (used when client rejoins network disconnect)
  @game_not_found "game_not_found"
  def game_not_found, do: @game_not_found

  # result after a game round
  @game_round_result "game_round_result"
  def game_round_result, do: @game_round_result

  # result after a player wins
  @game_match_result "game_match_result"
  def game_match_result, do: @game_match_result

  # used to let a player know that opponent choose a move
  @opponent_made_move "opponent_made_move"
  def opponent_made_move, do: @opponent_made_move

  # emited when any one of the player leaves the channel
  @opponent_left "opponent_left"
  def opponent_left, do: @opponent_left

  # emited when any one of the player don't make a move after specific amount of time
  @move_timeout "move_timeout"
  def move_timeout, do: @move_timeout

  # emited when a player doesn't join the channel after getting matchmaked after specific amount of time
  @opponent_join_timeout "opponent_join_timeout"
  def opponent_join_timeout, do: @opponent_join_timeout
end
