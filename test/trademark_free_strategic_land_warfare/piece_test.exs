defmodule TrademarkFreeStrategicLandWarfare.PieceTest do
  use ExUnit.Case

  alias TrademarkFreeStrategicLandWarfare.Piece

  setup_all do
    {:ok, %{pieces: Piece.names()
                    |> Enum.flat_map(&([{&1, Piece.new(&1)}]))
                    |> Map.new()
    }}
  end

  def filter_non_players(pieces) do
    pieces
    |> Map.values()
    |> Enum.filter(&(&1.name not in [:bomb, :flag]))
  end

  test "spy attacks marshall", %{pieces: %{spy: spy, marshall: marshall}} do
    assert Piece.attack(spy, marshall) == {:ok, [remove: [marshall.uuid]]} 
  end

  test "anyone except spy attacks spy", %{pieces: pieces = %{spy: spy}} do
    pieces
    |> filter_non_players()
    |> Enum.filter(&(&1.name != :spy))
    |> Enum.each(fn attacker ->
         assert Piece.attack(attacker, spy) == {:ok, [remove: [spy.uuid]]}
       end)
  end

  test "miner attacks bomb", %{pieces: %{miner: miner, bomb: bomb}} do
    assert Piece.attack(miner, bomb) == {:ok, [remove: [bomb.uuid]]} 
  end

  test "anyone but miner attacks bomb", %{pieces: pieces = %{bomb: bomb}} do
    pieces
    |> filter_non_players()
    |> Enum.filter(&(&1.name != :miner))
    |> Enum.each(fn attacker ->
         assert Piece.attack(attacker, bomb) == {:ok, [remove: [attacker.uuid]]}
       end)
  end

  test "anyone attacks flag", %{pieces: pieces = %{flag: flag}} do
    pieces
    |> filter_non_players()
    |> Enum.each(fn attacker ->
         assert Piece.attack(attacker, flag) == {:ok, :win}
       end)
  end

  test "anyone attacks someone of the same rank", %{pieces: pieces} do
    pieces
    |> filter_non_players()
    |> Enum.each(fn attacker ->
         defender = %Piece{attacker | uuid: UUID.uuid1()}
         assert Piece.attack(attacker, defender) == {:ok, [remove: [attacker.uuid, defender.uuid]]}
       end)
  end

  test "anyone attacks someone of higher rank", %{pieces: pieces} do
    personnel =
      pieces
      |> filter_non_players()
      |> Enum.sort_by(&(&1.rank))

    for attacker <- personnel do
      for defender <- personnel,
          attacker.rank < defender.rank,
          {attacker.name, defender.name} != {:spy, :marshall} do
            assert Piece.attack(attacker, defender) == {:ok, [remove: [attacker.uuid]]}
      end
    end
  end

  test "anyone attacks someone of lower rank", %{pieces: pieces} do
    personnel =
      pieces
      |> filter_non_players()
      |> Enum.sort_by(&(&1.rank), :desc)

    for attacker <- personnel do
      for defender <- personnel, attacker.rank > defender.rank do
         assert Piece.attack(attacker, defender) == {:ok, [remove: [defender.uuid]]}
      end
    end
  end
end
