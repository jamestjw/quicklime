defmodule QuicklimeWeb.GameChannelTest do
  use ExUnit.Case, async: false
  import Phoenix.ChannelTest

  alias QuicklimeWeb.GameChannel
  alias QuicklimeWeb.UserSocket

  @endpoint QuicklimeWeb.Endpoint

  test "a valid anonymous player can join the regional game" do
    session_id = "test-session-#{System.unique_integer([:positive])}"

    assert {:ok, snapshot, _socket} =
             socket(UserSocket, nil, %{})
             |> subscribe_and_join(GameChannel, "game:regional", %{
               "name" => "Mara",
               "session_id" => session_id
             })

    assert snapshot.player.name == "Mara"
    assert snapshot.player.score == 0
    assert is_list(snapshot.leaderboard)
  end

  test "invalid player data is rejected" do
    assert {:error, %{reason: "invalid_player"}} =
             socket(UserSocket, nil, %{})
             |> subscribe_and_join(GameChannel, "game:regional", %{
               "name" => "",
               "session_id" => "short"
             })
  end
end
