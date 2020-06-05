defmodule TrademarkFreeStrategicLandWarfare.Players.Sam do
  alias TrademarkFreeStrategicLandWarfare.{Board, Player, Piece}
  @behaviour Player

  @type direction() :: :north | :west | :east | :south
  @type count() :: Integer.t()
  @type state() :: any()

  @spec name() :: binary()
  def name() do
    "Sam Marten"
  end

  # should return a list with 4 lists of 10 piece-name atoms (:miner, :colonel, etc) per list
  @spec initial_pieces_placement() :: nonempty_list([Atom.t(), ...])
  def initial_pieces_placement() do
    pieces = 
      Board.piece_name_counts()
      |> Enum.flat_map(
        fn {type, count} ->
          for _ <- 1..count, do: type
        end)

    {flag_defense_strategy, flag_protection} =
      case :rand.uniform() do
        val when val < 0.15 ->
          {:right_side_defense, [:flag, :bomb, :bomb, :bomb]}

        val when val < 0.30 ->
          {:left_side_defense, [:flag, :bomb, :bomb, :bomb]}

        val when val < 0.5 ->
          {:corner_defense, [:flag, :bomb, :bomb]}

        _ ->
          {:bottom_defense, [:flag, :bomb, :bomb, :bomb]}
      end

    pieces
    |> Kernel.--(flag_protection)
    |> Enum.shuffle()
    |> insert_defense(flag_defense_strategy)
    |> Enum.chunk_every(10)
  end

  @spec turn(
          %TrademarkFreeStrategicLandWarfare.Board{},
          %TrademarkFreeStrategicLandWarfare.Player{},
          state()
        ) :: {binary(), direction(), count(), state()}
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

    # select from them, biasing towards pieces that can win, then those that can advance,
    # then west/east, then move backward
    eligible_moves =
      Enum.shuffle(
        [
          Map.get(move_partitioned_pieces, :win, []),
          Map.get(move_partitioned_pieces, :win, []),
          Map.get(move_partitioned_pieces, :win, []),
          Map.get(
            move_partitioned_pieces,
            Board.maybe_invert_player_direction(:north, number),
            []
          ),
          Map.get(move_partitioned_pieces, :west, []) ++
            Map.get(move_partitioned_pieces, :east, []),
          Map.get(
            move_partitioned_pieces,
            Board.maybe_invert_player_direction(:south, number),
            []
          )
        ])
      |> Enum.find(fn list -> length(list) > 0 end)

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
    # TODO: reduce_while and halt when preferred one found (win, progressing forward)
    Enum.reduce(pieces, %{}, fn piece, acc ->
      Enum.reduce([:north, :west, :east, :south], acc, fn direction, dir_acc ->
        case Board.move(board, piece.player, piece.uuid, direction, 1) do
          {:ok, :win, _} ->
            # this shouldn't ever get hit, because we'll never know as a player
            # where the opponent's flag is without trying to capture it.  putting
            # this here for that note, and just in case.
            Map.update(
              dir_acc,
              :win,
              [{piece.uuid, direction, 1}],
              &[{piece.uuid, direction, 1} | &1]
            )

          {:error, :unknown_result} ->
            # allowed move, but masked piece.  include in the possibles.
            Map.update(
              dir_acc,
              direction,
              [{piece.uuid, direction, 1}],
              &[{piece.uuid, direction, 1} | &1]
            )

          {:ok, %Board{}} ->
            # allowed move -- no differentiation on whether attack happened
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

  defp insert_defense(positions, :bottom_defense) do
    flag_col = Enum.random(1..8)

    positions
    |> List.insert_at(20 + flag_col, :bomb)
    |> List.insert_at(30 + flag_col - 1, :bomb)
    |> List.insert_at(30 + flag_col, :flag)
    |> List.insert_at(30 + flag_col + 1, :bomb)
  end

  defp insert_defense(positions, :corner_defense) do
    case Enum.random([0, 9]) do
      0 ->
        positions
        |> List.insert_at(20, :bomb)
        |> List.insert_at(30, :flag)
        |> List.insert_at(31, :bomb)

      9 ->
        positions
        |> List.insert_at(29, :bomb)
        |> List.insert_at(38, :bomb)
        |> List.insert_at(39, :flag)
    end

  end

  defp insert_defense(positions, :left_side_defense) do
    case Enum.random(1..2) do
      1 ->
        positions
        |> List.insert_at(0, :bomb)
        |> List.insert_at(10, :flag)
        |> List.insert_at(11, :bomb)
        |> List.insert_at(20, :bomb)

      2 ->
        positions
        |> List.insert_at(10, :bomb)
        |> List.insert_at(20, :flag)
        |> List.insert_at(21, :bomb)
        |> List.insert_at(30, :bomb)
    end
  end

  defp insert_defense(positions, :right_side_defense) do
    case Enum.random(1..2) do
      1 ->
        positions
        |> List.insert_at(9, :bomb)
        |> List.insert_at(18, :bomb)
        |> List.insert_at(19, :flag)
        |> List.insert_at(29, :bomb)

      2 ->
        positions
        |> List.insert_at(19, :bomb)
        |> List.insert_at(28, :bomb)
        |> List.insert_at(29, :flag)
        |> List.insert_at(39, :bomb)
    end
  end
end
