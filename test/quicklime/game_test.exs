defmodule Quicklime.GameTest do
  use ExUnit.Case, async: true

  alias Quicklime.Game

  test "the first correct claim wins and closes the tile" do
    game =
      Game.new()
      |> Game.join("player-one", "Mara")
      |> Game.join("player-two", "Devon")
      |> Game.open_tile(7, 1_000)

    {game, winner} = Game.claim(game, "player-one", 1, 7, 1_218)
    {_game, late} = Game.claim(game, "player-two", 1, 7, 1_219)

    assert winner.status == "won"
    assert winner.reaction_ms == 218
    assert winner.player.score == 100
    assert winner.player.wins == 1
    assert late.status == "stale"
  end

  test "wrong attempts are penalized and the player can keep trying" do
    game =
      Game.new()
      |> Game.join("player-one", "Mara")
      |> Game.open_tile(7, 1_000)

    {game, first_wrong} = Game.claim(game, "player-one", 1, 3, 1_100)
    {game, second_wrong} = Game.claim(game, "player-one", 1, 5, 1_150)
    {_game, winner} = Game.claim(game, "player-one", 1, 7, 1_200)

    assert first_wrong.status == "wrong"
    assert first_wrong.player.score == -40
    assert second_wrong.status == "wrong"
    assert second_wrong.player.score == -80
    assert winner.status == "won"
    assert winner.player.score == 20
  end

  test "rejoining preserves a disconnected player's score" do
    game =
      Game.new()
      |> Game.join("player-one", "Mara")
      |> Game.open_tile(7, 1_000)

    {game, _winner} = Game.claim(game, "player-one", 1, 7, 1_218)
    disconnected = Game.disconnect(game, "player-one")
    rejoined = Game.join(disconnected, "player-one", "Mara")

    refute Game.player(disconnected, "player-one").connected
    assert Game.player(rejoined, "player-one").connected
    assert Game.player(rejoined, "player-one").score == 100
  end

  test "leaderboard sorts by score and reports connected players" do
    game =
      Game.new()
      |> Game.join("player-one", "Mara")
      |> Game.join("player-two", "Devon")
      |> Game.open_tile(7, 1_000)

    {game, _wrong} = Game.claim(game, "player-one", 1, 3, 1_100)
    {game, _winner} = Game.claim(game, "player-two", 1, 7, 1_200)
    [first, second] = Game.leaderboard(game)

    assert {first.name, first.rank, first.score} == {"Devon", 1, 100}
    assert {second.name, second.rank, second.score} == {"Mara", 2, -40}
    assert Game.connected_count(game) == 2
  end
end
