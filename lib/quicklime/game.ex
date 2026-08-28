defmodule Quicklime.Game do
  @moduledoc """
  Pure state transitions for a regional Quicklime match.
  """

  @correct_score 100
  @wrong_score -40

  defstruct tile_id: 0,
            active_tile: nil,
            opened_at: nil,
            phase: :waiting,
            players: %{}

  def new, do: %__MODULE__{}

  def join(%__MODULE__{} = game, id, name) do
    player =
      game.players
      |> Map.get(id, new_player(id, name))
      |> Map.merge(%{name: name, connected: true})

    put_in(game.players[id], player)
  end

  def disconnect(%__MODULE__{} = game, id) do
    update_player(game, id, &Map.put(&1, :connected, false))
  end

  def drop(%__MODULE__{} = game, id) do
    %{game | players: Map.delete(game.players, id)}
  end

  def open_tile(%__MODULE__{} = game, tile_index, now_ms)
      when tile_index in 0..19 and is_integer(now_ms) do
    %{
      game
      | tile_id: game.tile_id + 1,
        active_tile: tile_index,
        opened_at: now_ms,
        phase: :open
    }
  end

  def expire_tile(%__MODULE__{} = game) do
    %{game | active_tile: nil, opened_at: nil, phase: :waiting}
  end

  def claim(%__MODULE__{} = game, player_id, tile_id, tile_index, now_ms) do
    player = Map.get(game.players, player_id)

    cond do
      game.phase != :open or game.tile_id != tile_id ->
        {game, %{status: "stale"}}

      is_nil(player) or not player.connected ->
        {game, %{status: "unavailable"}}

      game.active_tile != tile_index ->
        penalized = %{player | score: player.score + @wrong_score}
        next_game = put_in(game.players[player_id], penalized)

        {next_game, %{status: "wrong", delta: @wrong_score, player: player_payload(penalized)}}

      true ->
        reaction_ms = max(now_ms - game.opened_at, 0)

        winner = %{
          player
          | score: player.score + @correct_score,
            wins: player.wins + 1,
            best_ms: best_time(player.best_ms, reaction_ms)
        }

        next_game =
          game
          |> put_in([Access.key(:players), player_id], winner)
          |> Map.merge(%{active_tile: nil, opened_at: nil, phase: :waiting})

        result = %{
          status: "won",
          delta: @correct_score,
          reaction_ms: reaction_ms,
          player: player_payload(winner)
        }

        {next_game, result}
    end
  end

  def player(%__MODULE__{} = game, id) do
    case Map.get(game.players, id) do
      nil -> nil
      player -> player_payload(player)
    end
  end

  def leaderboard(%__MODULE__{} = game, limit \\ 20) do
    game.players
    |> Map.values()
    |> Enum.sort_by(fn player -> {-player.score, String.downcase(player.name), player.id} end)
    |> Enum.with_index(1)
    |> Enum.take(limit)
    |> Enum.map(fn {player, rank} -> Map.put(player_payload(player), :rank, rank) end)
  end

  def connected_count(%__MODULE__{} = game) do
    Enum.count(game.players, fn {_id, player} -> player.connected end)
  end

  defp new_player(id, name) do
    %{id: id, name: name, score: 0, wins: 0, best_ms: nil, connected: true}
  end

  defp update_player(%__MODULE__{} = game, id, update) do
    case Map.fetch(game.players, id) do
      {:ok, player} -> put_in(game.players[id], update.(player))
      :error -> game
    end
  end

  defp player_payload(player) do
    Map.take(player, [:id, :name, :score, :wins, :best_ms, :connected])
  end

  defp best_time(nil, reaction_ms), do: reaction_ms
  defp best_time(best_ms, reaction_ms), do: min(best_ms, reaction_ms)
end
