defmodule TrademarkFreeStrategicLandWarfare.Players.SemiRandom do
  alias TrademarkFreeStrategicLandWarfare.{Board, Player, Piece}
  @behaviour Player

  def name() do
    "Semi-Random"
  end

  def initial_pieces_placement() do
    Board.piece_name_counts()
    |> Enum.flat_map(fn {type, count} ->
      for _ <- 1..count, do: type
    end)
    |> Enum.shuffle()
    |> Enum.chunk_every(10)
  end

  def turn(%Board{rows: rows} = board, %Player{number: number}, state) do
    # find all eligible pieces
    move_partitioned_pieces =
      rows
      |> List.flatten()
      |> Enum.flat_map(fn
        %Piece{player: ^number, name: name} = piece when name not in [:bomb, :flag] -> [piece]
        _ -> []
      end)
      |> partition_by_move(board)

    # select from them, biasing towards pieces that can win, then those that can move forward,
    # then left/right, then back
    eligible_moves =
      Enum.find(
        [
          Map.get(move_partitioned_pieces, :win, []),
          Map.get(move_partitioned_pieces, :forward, []),
          Map.get(move_partitioned_pieces, :left, []) ++
            Map.get(move_partitioned_pieces, :right, []),
          Map.get(move_partitioned_pieces, :backward, [])
        ],
        fn list -> length(list) > 0 end
      )

    # randomly select one from the list returned
    case eligible_moves do
      nil ->
        raise "no move possible"

      moves ->
        moves
        |> Enum.random()
        |> Tuple.append(state)
    end
  end

  defp partition_by_move(pieces, board) do
    # TODO: reduce_while and halt when preferred one found (win, forward)
    Enum.reduce(pieces, %{}, fn piece, acc ->
      Enum.reduce([:forward, :left, :right, :backward], acc, fn direction, dir_acc ->
        case Board.move(board, piece.player, piece.uuid, direction, 1) do
          {:error, _} ->
            dir_acc

          {:ok, :win, _} ->
            Map.update(
              dir_acc,
              :win,
              [{piece.uuid, direction, 1}],
              &[{piece.uuid, direction, 1} | &1]
            )

          {:ok, %Board{}} ->
            # allowed move -- no differentiation on whether attack happened in semi-random
            Map.update(
              dir_acc,
              direction,
              [{piece.uuid, direction, 1}],
              &[{piece.uuid, direction, 1} | &1]
            )

          _ ->
            dir_acc
        end
      end)
    end)
  end
end
