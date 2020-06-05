defmodule TrademarkFreeStrategicLandWarfare.Players.Johnny5 do
  alias TrademarkFreeStrategicLandWarfare.{Board, Player, Piece}
  @behaviour Player

  @type direction() :: :north | :west | :east | :south
  @type count() :: Integer.t()
  @type state() :: any()

  @spec name() :: binary()
  def name() do
    "Johnny5"
  end

  # should return a list with 4 lists of 10 piece-name atoms (:miner, :colonel, etc) per list
  @spec initial_pieces_placement() :: nonempty_list([Atom.t(), ...])
  def initial_pieces_placement() do
      [[:sergeant, :sergeant, :scout, :scout, :scout, :scout, :scout, :scout, :marshall, :general],
      [:bomb, :bomb, :major, :major, :major, :scout, :sergeant, :scout, :sergeant, :lieutenant],
      [:bomb, :bomb, :spy, :lieutenant, :lieutenant, :lieutenant, :captain, :captain, :captain, :captain],
      [:flag, :bomb, :bomb, :miner, :miner, :miner, :colonel, :colonel, :miner, :miner]]
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
      Enum.find(
        [
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
end
