defmodule TrademarkFreeStrategicLandWarfare.PieceTest do
  use ExUnit.Case

  alias TrademarkFreeStrategicLandWarfare.Piece

  setup_all do
    {:ok,
     %{
       pieces:
         Piece.names()
         |> Enum.flat_map(&[{&1, Piece.new(&1, 1)}])
         |> Map.new()
     }}
  end

  def filter_non_players(pieces) do
    pieces
    |> Map.values()
    |> Enum.filter(&(&1.name not in [:bomb, :flag]))
  end

  describe "new" do
    test "create a new piece won't work for player 3" do
      assert_raise RuntimeError, ~r/^player valid range is 1-2!$/, fn ->
        Piece.new(:marshall, 3)
      end
    end

    test "create a new piece won't work for a nonsense type" do
      assert_raise RuntimeError, ~r/^piece name must be one of/, fn ->
        Piece.new(:nonsense, 2)
      end
    end
  end

  describe "reveal" do
    test "reveal switches a piece from invisible to visible", %{pieces: %{scout: scout}} do
      assert scout.visible == false
      assert %Piece{visible: true} = Piece.reveal(scout)
    end
  end

  describe "maybe_mask" do
    test "maybe_mask hides nothing for current player", %{
      pieces: %{lieutenant: %Piece{rank: rank} = lieutenant}
    } do
      assert %Piece{name: :lieutenant, rank: ^rank} = Piece.maybe_mask(lieutenant, 1)
    end

    test "maybe_mask hides fields for other player when not visible", %{pieces: %{major: major}} do
      assert %Piece{name: nil, rank: nil} = Piece.maybe_mask(major, 2)
    end

    test "maybe_mask hides nothing for other player when visible", %{
      pieces: %{colonel: %Piece{rank: rank} = colonel}
    } do
      revealed_piece = Piece.reveal(colonel)
      assert %Piece{name: :colonel, rank: ^rank} = Piece.maybe_mask(revealed_piece, 2)
    end
  end

  describe "attack" do
    test "neither bomb nor flag can be attacker", %{pieces: pieces} do
      pieces
      |> filter_non_players()
      |> Enum.each(fn defender ->
        assert {:error, _} = Piece.attack(pieces.flag, defender)
        assert {:error, _} = Piece.attack(pieces.bomb, defender)
      end)
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
        |> Enum.sort_by(& &1.rank)

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
        |> Enum.sort_by(& &1.rank, :desc)

      for attacker <- personnel do
        for defender <- personnel, attacker.rank > defender.rank do
          assert Piece.attack(attacker, defender) == {:ok, [remove: [defender.uuid]]}
        end
      end
    end
  end
end
