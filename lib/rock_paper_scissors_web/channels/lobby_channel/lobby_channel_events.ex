defmodule RockPaperScissors.LobbyChannelEvents do
  # used to tell the client that there are no available players online
  @no_players "no_players"
  def no_players, do: @no_players

  # used to tell that a player has been matchmaked with an opponent
  @got_opponent "got_opponent"
  def got_opponent, do: @got_opponent
end
