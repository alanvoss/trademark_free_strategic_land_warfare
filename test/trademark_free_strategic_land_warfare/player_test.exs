defmodule TrademarkFreeStrategicLandWarfare.PlayerTest do
  use ExUnit.Case

  alias TrademarkFreeStrategicLandWarfare.Player

  describe "new" do
    test "fails when no name is passed" do
      assert_raise RuntimeError, ~r/^player must have a name!$/, fn ->
        Player.new(nil, 1)
      end
    end

    test "creates a new player will work for player 1 or 2" do
      name = ThisPlayer

      for n <- 1..2 do
        assert %Player{player: ^n, name: ^name} = Player.new(name, n)
      end
    end

    test "create a new player won't work for players outside that range" do
      assert_raise RuntimeError, ~r/^player valid range is 1-2!$/, fn ->
        Player.new(WhichPlayer, 3)
      end
    end
  end
end
