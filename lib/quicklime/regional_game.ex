defmodule Quicklime.RegionalGame do
  @moduledoc """
  Owns the authoritative state and timing for the default regional match.
  """

  use GenServer

  alias Quicklime.Game

  @topic "game:regional"
  @initial_delay_ms 1_000
  @tile_lifetime_ms 3_500
  @drop_grace_ms 20_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def join(player_id, name), do: GenServer.call(__MODULE__, {:join, player_id, name})
  def disconnect(player_id), do: GenServer.cast(__MODULE__, {:disconnect, player_id})

  def claim(player_id, tile_id, tile_index) do
    GenServer.call(__MODULE__, {:claim, player_id, tile_id, tile_index})
  end

  @impl true
  def init(opts) do
    initial_delay = Keyword.get(opts, :initial_delay_ms, @initial_delay_ms)
    Process.send_after(self(), :open_tile, initial_delay)
    {:ok, %{game: Game.new(), drop_timers: %{}}}
  end

  @impl true
  def handle_call({:join, player_id, name}, _from, state) do
    state = cancel_drop(state, player_id)
    game = Game.join(state.game, player_id, name)
    next_state = %{state | game: game}
    broadcast_leaderboard(game)
    {:reply, snapshot(game, player_id), next_state}
  end

  def handle_call({:claim, player_id, tile_id, tile_index}, _from, state) do
    {game, result} =
      Game.claim(state.game, player_id, tile_id, tile_index, System.monotonic_time(:millisecond))

    if result.status in [:won, :wrong] do
      broadcast_leaderboard(game)
    end

    if result.status == :won do
      broadcast("tile_won", %{
        tile_id: tile_id,
        winner: result.player,
        reaction_ms: result.reaction_ms
      })

      Process.send_after(self(), :open_tile, next_tile_delay())
    end

    {:reply, result, %{state | game: game}}
  end

  @impl true
  def handle_cast({:disconnect, player_id}, state) do
    token = make_ref()
    timer = Process.send_after(self(), {:drop_player, player_id, token}, @drop_grace_ms)
    game = Game.disconnect(state.game, player_id)
    drop_timers = Map.put(state.drop_timers, player_id, {timer, token})
    broadcast_leaderboard(game)
    {:noreply, %{state | game: game, drop_timers: drop_timers}}
  end

  @impl true
  def handle_info(:open_tile, %{game: %{phase: :waiting}} = state) do
    game = Game.open_tile(state.game, :rand.uniform(20) - 1, System.monotonic_time(:millisecond))

    broadcast("tile_opened", %{
      tile_id: game.tile_id,
      tile_index: game.active_tile,
      lifetime_ms: @tile_lifetime_ms
    })

    Process.send_after(self(), {:expire_tile, game.tile_id}, @tile_lifetime_ms)
    {:noreply, %{state | game: game}}
  end

  def handle_info(:open_tile, state), do: {:noreply, state}

  def handle_info({:expire_tile, tile_id}, %{game: game} = state) do
    if game.phase == :open and game.tile_id == tile_id do
      expired = Game.expire_tile(game)
      broadcast("tile_expired", %{tile_id: tile_id})
      Process.send_after(self(), :open_tile, next_tile_delay())
      {:noreply, %{state | game: expired}}
    else
      {:noreply, state}
    end
  end

  def handle_info({:drop_player, player_id, token}, state) do
    case Map.get(state.drop_timers, player_id) do
      {_timer, ^token} ->
        game = Game.drop(state.game, player_id)
        broadcast_leaderboard(game)

        {:noreply, %{state | game: game, drop_timers: Map.delete(state.drop_timers, player_id)}}

      _other ->
        {:noreply, state}
    end
  end

  defp snapshot(game, player_id) do
    %{
      tile_id: game.tile_id,
      active_tile: game.active_tile,
      phase: Atom.to_string(game.phase),
      player_count: Game.connected_count(game),
      leaderboard: Game.leaderboard(game),
      player: Game.player(game, player_id)
    }
  end

  defp cancel_drop(state, player_id) do
    case Map.pop(state.drop_timers, player_id) do
      {nil, _timers} ->
        state

      {{timer, _token}, timers} ->
        Process.cancel_timer(timer)
        %{state | drop_timers: timers}
    end
  end

  defp broadcast_leaderboard(game) do
    broadcast("leaderboard", %{
      players: Game.leaderboard(game),
      player_count: Game.connected_count(game)
    })
  end

  defp broadcast(event, payload) do
    QuicklimeWeb.Endpoint.broadcast(@topic, event, payload)
  end

  defp next_tile_delay, do: 850 + :rand.uniform(750)
end
