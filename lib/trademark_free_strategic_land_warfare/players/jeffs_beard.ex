defmodule TrademarkFreeStrategicLandWarfare.Players.JeffsBeard do
  alias TrademarkFreeStrategicLandWarfare.{Board, Player, Piece}
  @behaviour Player

  @type direction() :: :north | :west | :east | :south
  @type count() :: Integer.t()
  @type state() :: any()

  @spec name() :: binary()
  def name(), do: "Jeff's Beard 🧔"

  # should return a list with 4 lists of 10 piece-name atoms (:miner, :colonel, etc) per list
  @spec initial_pieces_placement() :: nonempty_list([Atom.t(), ...])
  def initial_pieces_placement() do
    [
      [
        :captain,
        :scout,
        :scout,
        :lieutenant,
        :scout,
        :captain,
        :miner,
        :marshall,
        :scout,
        :captain
      ],
      [:lieutenant, :sergeant, :bomb, :spy, :general, :scout, :major, :major, :colonel, :scout],
      [
        :sergeant,
        :bomb,
        :sergeant,
        :major,
        :colonel,
        :lieutenant,
        :bomb,
        :lieutenant,
        :captain,
        :sergeant
      ],
      [:scout, :miner, :bomb, :scout, :miner, :bomb, :flag, :bomb, :miner, :miner]
    ]
  end

  @spec turn(
          %TrademarkFreeStrategicLandWarfare.Board{},
          %TrademarkFreeStrategicLandWarfare.Player{},
          state()
        ) :: {binary(), direction(), count(), state()}
  def turn(%Board{} = board, %Player{module: module, number: number}, state) do
    possible_pieces = all_pieces_for_player(board, number)

    all_possible_moves = possible_moves(board, possible_pieces, state)

    weighted_moves = weight_moves(board, number, all_possible_moves)

    case weighted_moves do
      [] ->
        raise "no move possible"

      moves ->
        Enum.random(moves)
    end
  end

  defp possible_moves(board, possible_pieces, state) do
    res =
      for piece <- possible_pieces,
          direction <- [:north, :west, :east, :south],
          move_count <- [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] do
        case move_count in move_counts(piece) do
          true ->
            case Board.move(board, piece.player, piece.uuid, direction, move_count) do
              {:ok, :win, _} -> {piece.uuid, direction, move_count, state}
              {:error, :unknown_result} -> {piece.uuid, direction, move_count, state}
              {:ok, %Board{}} -> {piece.uuid, direction, move_count, state}
              _ -> nil
            end

          false ->
            nil
        end
      end

    Enum.reject(res, &is_nil(&1))
  end

  defp move_counts(:scout), do: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  defp move_counts(_), do: [1]

  defp weight_moves(board, player, moves) do
    Enum.flat_map(moves, fn {uuid, direction, spaces, state} = move ->
      case Board.move(board, player, uuid, direction, spaces) do
        {:ok, :win, _} ->
          Enum.map(0..1_000_000, fn _ -> move end)

        {:error, :unknown_result} ->
          [move]

        {:ok, %Board{} = new_board} ->
          other_player =
            case player do
              1 -> 2
              2 -> 1
            end

          old_count_other_player = length(all_pieces_for_player(board, other_player))
          new_count_other_player = length(all_pieces_for_player(new_board, other_player))
          old_count_me = length(all_pieces_for_player(board, player))
          new_count_me = length(all_pieces_for_player(new_board, player))

          case {new_count_other_player < old_count_other_player, new_count_me < old_count_me} do
            {true, _} -> Enum.map(0..200, fn _ -> move end)
            {_, true} -> [move]
            {_, _} -> Enum.map(0..20, fn _ -> move end)
          end
      end
    end)
  end

  def all_pieces_for_player(%Board{rows: rows}, number) do
    rows
    |> List.flatten()
    |> Enum.flat_map(fn
      %Piece{player: ^number, name: name} = piece when name not in [:bomb, :flag] -> [piece]
      _ -> []
    end)
  end
end
