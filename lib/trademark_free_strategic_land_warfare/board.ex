defmodule TrademarkFreeStrategicLandWarfare.Board do
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
          rows: [List.t()],
          lookup: Map.t()
        }

  def piece_name_counts() do
    @piece_name_counts
  end

  def new() do
    %__MODULE__{
      rows: @empty_board,
      lookup: %{}
    }
  end

  def init_pieces(
        %__MODULE__{} = board,
        pieces,
        player
      ) do
    with true <- validate_piece_counts(pieces),
         true <- validate_row_dimensions(pieces),
         rows_of_pieces <- create_pieces(pieces, player) do
      populate_board(board, rows_of_pieces, player)
    else
      _ -> {:error, "piece configuration is incorrect"}
    end
  end

  defp populate_board(%__MODULE__{} = board, rows_of_pieces, player) do
    new_board =
      Enum.reduce(rows_of_pieces, {3, board}, fn row, {y, row_acc} ->
        {
          y - 1,
          Enum.reduce(row, {0, row_acc}, fn piece, {x, column_acc} ->
            {
              x + 1,
              place_piece(column_acc, piece, {x, y}, player)
            }
          end)
        }
      end)

    {:ok, new_board}
  end

  def translate_coord(coord, 1 = _player), do: coord
  def translate_coord({x, y}, 2 = _player), do: {9 - x, 9 - y}

  def lookup_by_uuid(board, uuid, player \\ 1) do
    case board.lookup[uuid] do
      nil ->
        nil

      coord ->
        {translate_coord(coord, player), lookup_by_coord(board, coord)}
    end
  end

  def lookup_by_coord(board, coord, player \\ 1) do
    {x, y} = translate_coord(coord, player)
    get_in(board.rows, [Access.at(y), Access.at(x)])
  end

  def remove_piece(%__MODULE__{} = board, %Piece{uuid: uuid}) do
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

  def place_piece(%__MODULE__{} = board, piece, {x, y}, player \\ 1) do
    {translated_x, translated_y} = translate_coord({x, y}, player)

    board
    |> remove_piece(piece)
    |> put_in([Access.key(:rows), Access.at(translated_y), Access.at(translated_x)], piece)
    |> put_in([Access.key(:lookup), piece.uuid], {translated_x, translated_y})
  end

  def maybe_flip(rows, 1), do: rows

  def maybe_flip(rows, 2) do
    rows
    |> Enum.reverse()
    |> Enum.reduce([], &Enum.reverse/1)
  end

  defp validate_piece_counts(pieces) do
    @piece_name_counts ==
      Enum.reduce(
        pieces,
        %{},
        fn name, acc -> Map.update(acc, name, 1, &(&1 + 1)) end
      )
  end

  defp validate_row_dimensions(pieces) do
    length(pieces) == 4 and [10, 10, 10, 10] == Enum.map(pieces, &length(&1))
  end

  defp create_pieces(pieces, player) do
    for row <- pieces do
      for piece <- row do
        Piece.new(piece, player)
      end
    end
  end

  def move(board, player, uuid, direction, count) do
    case lookup_by_uuid(board, uuid, player) do
      nil ->
        {:error, "no piece with that name"}

      {{x, y}, %Piece{player: ^player} = piece} ->
        advance(board, piece, {x, y}, maybe_invert_player_direction(direction, player), count)

      _ ->
        {:error, "you cannot move the other player's piece"}
    end
  end

  defp advance(_, %Piece{name: :bomb}, _, _, _) do
    {:error, "bombs cannot move"}
  end

  defp advance(_, %Piece{name: :flag}, _, _, _) do
    {:error, "flags cannot move"}
  end

  # advance until you hit something in case of scout
  defp advance(board, %Piece{name: :scout} = piece, {x, y}, direction, count) when count > 1 do
    with {:ok, new_coord} <- new_coordinate({x, y}, direction) do
      case lookup_by_coord(board, new_coord) do
        nil ->
          advance(board, piece, new_coord, direction, count - 1)

        _ ->
          # we hit something prematurely, either a lake, or another player,
          # so scout multiple square advancement ends here
          advance(board, piece, {x, y}, direction, 1)
      end
    end
  end

  # have to update the lookups after moving

  defp advance(board, piece, {x, y}, direction, 1) do
    with {:ok, new_coord} <- new_coordinate({x, y}, direction) do
      case lookup_by_coord(board, new_coord) do
        nil ->
          place_piece(board, piece, new_coord)

        :lake ->
          {:error, "cannot move into lake"}

        %Piece{} = defender ->
          attack(board, piece, defender)
      end
    end
  end

  defp advance(_, _, _, _, _) do
    {:error, "all pieces except the scout can only advance 1"}
  end

  defp attack(board, piece, defender) do
    case Piece.attack(piece, defender) do
      {:ok, actions} when is_list(actions) ->
        actions
        |> Keyword.get(:remove, [])
        |> Enum.reduce({:ok, board}, fn piece_to_remove, {:ok, acc} ->
          {:ok, remove_piece(acc, piece_to_remove)}
        end)

      other ->
        # either {:ok, :win} or an {:error, reason}
        other
    end
  end

  def maybe_invert_player_direction(direction, 1), do: direction
  def maybe_invert_player_direction(:forward, 2), do: :backward
  def maybe_invert_player_direction(:backward, 2), do: :forward
  def maybe_invert_player_direction(:left, 2), do: :right
  def maybe_invert_player_direction(:right, 2), do: :left

  def new_coordinate({x, y}, direction) do
    case direction do
      :forward -> {x, y - 1}
      :backward -> {x, y + 1}
      :left -> {x - 1, y}
      :right -> {x + 1, y}
    end
    |> check_coordinate_within_bounds()
  end

  def check_coordinate_within_bounds({x, y} = coord) when x >= 0 and x < 10 and y >= 0 and y < 10,
    do: {:ok, coord}

  def check_coordinate_within_bounds(_), do: {:error, "coordinate out of bounds"}
end
