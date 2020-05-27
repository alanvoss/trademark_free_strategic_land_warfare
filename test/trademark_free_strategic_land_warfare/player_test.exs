defmodule TrademarkFreeStrategicLandWarfare.PlayerTest do
  use ExUnit.Case

  alias TrademarkFreeStrategicLandWarfare.Player
  @implementer TrademarkFreeStrategicLandWarfare.Players.SemiRandom

  describe "new" do
    test "creates a new player will work for player 1 or 2" do
      for n <- 1..2 do
        assert %Player{number: ^n, name: "Semi-Random", module: @implementer} =
                 Player.new(@implementer, n)
      end
    end

    test "create a new player won't work for players outside that range" do
      assert_raise RuntimeError, ~r/^player valid range is 1-2!$/, fn ->
        Player.new(@implementer, 3)
      end
    end
  end
end
