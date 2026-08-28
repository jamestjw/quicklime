defmodule QuicklimeWeb.GameChannel do
  use QuicklimeWeb, :channel

  alias Quicklime.RegionalGame

  @impl true
  def join("game:regional", %{"name" => raw_name, "session_id" => session_id}, socket) do
    with {:ok, name} <- validate_name(raw_name),
         true <- valid_session_id?(session_id) do
      socket = assign(socket, player_id: session_id, player_name: name)
      {:ok, RegionalGame.join(session_id, name), socket}
    else
      _invalid -> {:error, %{reason: "invalid_player"}}
    end
  end

  def join("game:" <> _region, _params, _socket) do
    {:error, %{reason: "unknown_region"}}
  end

  @impl true
  def handle_in(
        "claim_tile",
        %{"tile_id" => tile_id, "tile_index" => tile_index},
        socket
      )
      when is_integer(tile_id) and is_integer(tile_index) and tile_index in 0..19 do
    result = RegionalGame.claim(socket.assigns.player_id, tile_id, tile_index)
    {:reply, {:ok, result}, socket}
  end

  def handle_in("claim_tile", _payload, socket) do
    {:reply, {:error, %{reason: "invalid_claim"}}, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    if player_id = socket.assigns[:player_id] do
      RegionalGame.disconnect(player_id)
    end

    :ok
  end

  defp validate_name(name) when is_binary(name) do
    name = String.trim(name)

    if String.length(name) in 1..20 and String.printable?(name) do
      {:ok, name}
    else
      :error
    end
  end

  defp validate_name(_name), do: :error

  defp valid_session_id?(session_id) when is_binary(session_id) do
    String.match?(session_id, ~r/\A[a-zA-Z0-9-]{8,64}\z/)
  end

  defp valid_session_id?(_session_id), do: false
end
