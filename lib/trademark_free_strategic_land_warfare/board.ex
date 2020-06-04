defmodule TrademarkFreeStrategicLandWarfare.Board do
  @derive Jason.Encoder
  @enforce_keys [:rows, :lookup]
  defstruct rows: nil, lookup: nil

  alias TrademarkFreeStrategicLandWarfare.Piece

  @empty_board [
    [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
    [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
    [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
    [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
    [nil, nil, :lake, :lake, nil, nil, :lake, :lake, nil, nil],
    [nil, nil, :lake, :lake, nil, nil, :lake, :lake, nil, nil],
    [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
    [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
    [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
    [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
  ]

  @piece_name_counts %{
    flag: 1,
    bomb: 6,
    spy: 1,
    scout: 8,
    miner: 5,
    sergeant: 4,
    lieutenant: 4,
    captain: 4,
    major: 3,
    colonel: 2,
    general: 1,
    marshall: 1
  }

  @type t() :: %__MODULE__{
          rows: list(list()),
          lookup: map()
        }

  @type coordinate() :: {integer(), integer()}
  @type player_number() :: 1 | 2
  @type direction :: :north | :east | :south | :west

  @spec piece_name_counts() :: map()
  def piece_name_counts() do
    @piece_name_counts
  end

  @spec new() :: %__MODULE__{rows: [List.t()], lookup: map()}
  def new() do
    %__MODULE__{
      rows: @empty_board,
      lookup: %{}
    }
  end

  @spec init_pieces(%__MODULE__{}, list(list(atom())), player_number()) ::
          {:ok, %__MODULE__{rows: list(list()), lookup: map()}} | {:error, binary()}
  def init_pieces(
        %__MODULE__{} = board,
        pieces,
        player
      ) do
    with :ok <- validate_piece_counts(pieces),
         :ok <- validate_row_dimensions(pieces),
         rows_of_pieces <- create_pieces(pieces, player) do
      populate_board(board, rows_of_pieces, player)
    else
      {:error, x} -> {:error, "piece configuration is incorrect: #{inspect(x)}"}
    end
  end

  @spec lookup_by_uuid(%__MODULE__{}, binary()) ::
          nil | {coordinate(), %TrademarkFreeStrategicLandWarfare.Piece{}}
  def lookup_by_uuid(board, uuid) do
    case board.lookup[uuid] do
      nil ->
        nil

      {_, _} = coord ->
        {coord, lookup_by_coord(board, coord)}
    end
  end

  @spec lookup_by_coord(%__MODULE__{}, coordinate()) ::
          nil | %TrademarkFreeStrategicLandWarfare.Piece{}
  def lookup_by_coord(board, {x, y}) do
    if x >= 0 and x < 10 and y >= 0 and y < 10 do
      get_in(board.rows, [Access.at(y), Access.at(x)])
    else
      nil
    end
  end

  @spec remove_pieces(%__MODULE__{}, list(%TrademarkFreeStrategicLandWarfare.Piece{})) ::
          %__MODULE__{}
  def remove_pieces(%__MODULE__{} = board, pieces) do
    Enum.reduce(pieces, board, fn piece_to_remove, acc ->
      remove_piece(acc, piece_to_remove)
    end)
  end

  @spec remove_piece(%__MODULE__{}, %TrademarkFreeStrategicLandWarfare.Piece{}) :: %__MODULE__{}
  def remove_piece(%__MODULE__{} = board, %Piece{uuid: uuid}) do
    remove_piece(board, uuid)
  end

  @spec remove_piece(%__MODULE__{}, binary()) :: %__MODULE__{}
  def remove_piece(%__MODULE__{} = board, uuid) do
    case lookup_by_uuid(board, uuid) do
      nil ->
        board

      {{current_x, current_y}, _} ->
        %__MODULE__{
          rows:
            board.rows
            |> put_in([Access.at(current_y), Access.at(current_x)], nil),
          lookup: Map.delete(board.lookup, uuid)
        }
    end
  end

  @spec place_piece(%__MODULE__{}, %TrademarkFreeStrategicLandWarfare.Piece{}, coordinate()) ::
          {:error, binary()} | {:ok, %__MODULE__{}}
  def place_piece(_, %Piece{}, {x, y}) when x in [2, 3, 6, 7] and y in [4, 5] do
    {:error, "can't place a piece where a lake is"}
  end

  def place_piece(_, %Piece{}, {x, y}) when x < 0 or x >= 10 or y < 0 or y >= 10 do
    {:error, "can't place a piece out of bounds"}
  end

  def place_piece(%__MODULE__{} = board, %Piece{} = piece, {x, y}) do
    {:ok,
     board
     |> remove_piece(piece)
     |> put_in([Access.key(:rows), Access.at(y), Access.at(x)], piece)
     |> put_in([Access.key(:lookup), piece.uuid], {x, y})}
  end

  @spec(
    move(%__MODULE__{}, player_number(), binary(), direction(), integer()) :: {:error, binary()},
    {:ok, %__MODULE__{}}
  )
  def move(board, player, uuid, direction, count) do
    case lookup_by_uuid(board, uuid) do
      nil ->
        {:error, "no piece with that name"}

      {{x, y}, %Piece{player: ^player} = piece} ->
        advance(board, piece, {x, y}, direction, count)

      _ ->
        {:error, "you cannot move the other player's piece"}
    end
  end

  # these maybe functions are for if you choose to (maybe, if player 2) flip
  # the board to think about playing from the bottom to the top always,
  # rather than bottom down (for player 2).
  @spec maybe_flip(%__MODULE__{}, player_number()) :: RuntimeError
  def maybe_flip(%__MODULE__{}, _) do
    raise "not implemented for boards, only board rows"
  end

  @spec maybe_flip(list(list()), player_number()) :: list(list())
  def maybe_flip(rows, 1), do: rows

  def maybe_flip(rows, 2) do
    rows
    |> Enum.reverse()
    |> Enum.map(&Enum.reverse/1)
  end

  @spec maybe_invert_player_direction(direction(), player_number()) :: direction()
  def maybe_invert_player_direction(direction, 1), do: direction
  def maybe_invert_player_direction(:north, 2), do: :south
  def maybe_invert_player_direction(:south, 2), do: :north
  def maybe_invert_player_direction(:west, 2), do: :east
  def maybe_invert_player_direction(:east, 2), do: :west

  @spec maybe_translate_coord(coordinate(), player_number()) :: coordinate()
  def maybe_translate_coord(coord, 1), do: coord
  def maybe_translate_coord({x, y}, 2), do: {9 - x, 9 - y}

  @spec new_coordinate(coordinate(), direction()) :: nil | coordinate()
  def new_coordinate({x, y}, direction) do
    {new_x, new_y} =
      case direction do
        :north -> {x, y - 1}
        :south -> {x, y + 1}
        :west -> {x - 1, y}
        :east -> {x + 1, y}
      end

    if new_x >= 0 and new_x < 10 and new_y >= 0 and new_y < 10 do
      {new_x, new_y}
    else
      nil
    end
  end

  @spec mask_board(%__MODULE__{}, player_number()) :: %__MODULE__{}
  def mask_board(board, player) do
    new_rows =
      Enum.map(board.rows, fn row ->
        Enum.map(row, fn column ->
          Piece.maybe_mask(column, player)
        end)
      end)

    %__MODULE__{board | rows: new_rows}
  end

  defp populate_board(%__MODULE__{} = board, rows_of_pieces, player) do
    {row_range, column_range} =
      if player == 1 do
        {6..9, 0..9}
      else
        {3..0, 9..0}
      end

    new_board =
      rows_of_pieces
      |> Enum.zip(row_range)
      |> Enum.reduce(board, fn {row, y}, row_acc ->
        row
        |> Enum.zip(column_range)
        |> Enum.reduce(row_acc, fn {piece, x}, column_acc ->
          {:ok, new_board} = place_piece(column_acc, piece, {x, y})
          new_board
        end)
      end)

    {:ok, new_board}
  end

  defp validate_piece_counts(pieces) do
    player_piece_counts =
      pieces
      |> List.flatten()
      |> Enum.reduce(
        %{},
        fn name, acc -> Map.update(acc, name, 1, &(&1 + 1)) end
      )

    if @piece_name_counts == player_piece_counts do
      :ok
    else
      {:error,
       "invalid piece counts.  see Board.piece_name_counts() for individual named piece counts, and the total must add to 40"}
    end
  end

  defp validate_row_dimensions(pieces) do
    if length(pieces) == 4 and [10, 10, 10, 10] == Enum.map(pieces, &length(&1)) do
      :ok
    else
      {:error, "invalid row dimensions.  must give a list of 4 with 10 names each"}
    end
  end

  defp create_pieces(pieces, player) do
    for row <- pieces do
      for piece <- row do
        Piece.new(piece, player)
      end
    end
  end

  defp advance(_, %Piece{name: :bomb}, _, _, _) do
    {:error, "bombs cannot move"}
  end

  defp advance(_, %Piece{name: :flag}, _, _, _) do
    {:error, "flags cannot move"}
  end

  # advance until you hit something in case of scout, and reveal piece if move more than 1
  defp advance(board, %Piece{name: :scout} = piece, {x, y}, direction, count) when count > 1 do
    with new_coord = {new_x, new_y} when is_integer(new_x) and is_integer(new_y) <-
           new_coordinate({x, y}, direction) do
      case lookup_by_coord(board, new_coord) do
        nil ->
          # since this space is empty, and we are advancing by at least two (on next
          # iteration of this function), so other player now has knowledge that
          # this is a scout piece, so revealing it.
          piece = Piece.reveal(piece)
          advance(board, piece, new_coord, direction, count - 1)

        _ ->
          # we hit something prematurely, either a lake, or a piece,
          # so scout multiple square advancement ends here, and we'll let
          # the "normal" advance by 1 logic version of this function
          # catch any errors, move, or attack
          advance(board, piece, {x, y}, direction, 1)
      end
    else
      nil -> {:error, "attempt to move out of bounds isn't allowed"}
    end
  end

  # have to update the lookups after moving
  defp advance(board, %Piece{player: player} = piece, {x, y}, direction, 1) do
    with new_coord = {new_x, new_y} when is_integer(new_x) and is_integer(new_y) <-
           new_coordinate({x, y}, direction) do
      case lookup_by_coord(board, new_coord) do
        %Piece{player: ^player} ->
          {:error, "you can't run into your own team's piece"}

        %Piece{} = defender ->
          attack(board, piece, defender, new_coord)

        _ ->
          place_piece(board, piece, new_coord)
      end
    else
      nil -> {:error, "attempt to move out of bounds isn't allowed"}
    end
  end

  defp advance(_, _, _, _, n) when n != 1 do
    {:error, "all pieces except the scout can only advance 1"}
  end

  defp attack(board, attacker, defender, coord) do
    case Piece.attack(attacker, defender) do
      {:ok, actions} when is_list(actions) ->
        pieces_to_remove = actions[:remove]
        maybe_piece_to_place = [attacker.uuid, defender.uuid] -- pieces_to_remove
        board_with_removed_pieces = remove_pieces(board, pieces_to_remove)

        case maybe_piece_to_place do
          [uuid] ->
            {_, piece} = lookup_by_uuid(board, uuid)

            # attack happened, so piece type had to be announced, so revealing
            # it to other player for future turns.
            piece = Piece.reveal(piece)

            place_piece(board_with_removed_pieces, piece, coord)

          [] ->
            # equivalent ranks, so both pieces are removed
            {:ok, board_with_removed_pieces}
        end

      {:ok, :win} ->
        {:ok, board_with_flag_removed} =
          board
          |> remove_piece(defender)
          |> place_piece(attacker, coord)

        {:ok, :win, board_with_flag_removed}

      other ->
        # an {:error, reason}
        other
    end
  end
end
