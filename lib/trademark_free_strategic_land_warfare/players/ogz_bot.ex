defmodule TrademarkFreeStrategicLandWarfare.Players.OgzBot do
  alias TrademarkFreeStrategicLandWarfare.{Board, Player, Piece}
  @behaviour Player

  @type direction() :: :north | :west | :east | :south
  @type count() :: Integer.t()
  @type state() :: any()

  @spec name() :: binary()
  def name() do
    Enum.random(["Ogz Bot", "Little Bobby Fischer Tables", "Garry Kasparov's Evil Twin"])
  end

  @initial_setups [
    [
      [:captain, :scout, :scout, :lieutenant, :scout, :captain, :miner, :marshall, :scout, :captain],
      [:lieutenant, :sergeant, :bomb, :spy, :general, :scout, :major, :major, :colonel, :scout],
      [:sergeant, :bomb, :sergeant, :major, :colonel, :lieutenant, :bomb, :lieutenant, :captain, :sergeant],
      [:scout, :miner, :bomb, :scout, :miner, :bomb, :flag, :bomb, :miner, :miner]
    ],
    [
      [:scout, :colonel, :lieutenant, :scout, :captain, :scout, :general, :miner, :scout, :captain],
      [:marshall, :scout, :major, :colonel, :scout, :captain, :bomb, :lieutenant, :bomb, :lieutenant],
      [:captain, :sergeant, :major, :spy, :major, :lieutenant, :bomb, :sergeant, :bomb, :sergeant],
      [:miner, :scout, :miner, :miner, :sergeant, :bomb, :flag, :bomb, :miner, :scout]
    ],
    [
      [:marshall, :captain, :lieutenant, :miner, :scout, :captain, :scout, :scout, :scout, :captain],
      [:sergeant, :scout, :colonel, :colonel, :general, :scout, :sergeant, :bomb, :bomb, :lieutenant],
      [:major, :scout, :major, :spy, :captain, :lieutenant, :bomb, :sergeant, :lieutenant, :scout],
      [:major, :miner, :miner, :miner, :sergeant, :bomb, :flag, :bomb, :bomb, :miner]
    ]
  ]

  # should return a list with 4 lists of 10 piece-name atoms (:miner, :colonel, etc) per list
  @spec initial_pieces_placement() :: nonempty_list([Atom.t(), ...])
  def initial_pieces_placement() do
    Enum.random(@initial_setups)
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
