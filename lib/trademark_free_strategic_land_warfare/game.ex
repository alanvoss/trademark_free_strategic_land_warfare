defmodule TrademarkFreeStrategicLandWarfare.Frame do
  @derive Jason.Encoder
  @enforce_keys [:rows, :move]
  defstruct rows: nil, move: nil, result: nil

  @type t() :: %__MODULE__{
          rows: [List.t()],
          move: {:ok | :error, binary()},
          result: nil | {:ok | :error, binary()}
        }

  @type player_number() :: 1 | 2

  @spec new(
          list(list()),
          nil | {:ok, binary()} | {:error, binary()},
          nil | {:ok, :win, player_number()} | {:ok, binary()} | {:error, binary()}
        ) :: %__MODULE__{}
  def new(rows, move, result) do
    %__MODULE__{rows: rows, move: move, result: result}
  end
end

defmodule TrademarkFreeStrategicLandWarfare.Game do
  @derive Jason.Encoder
  @enforce_keys [:players, :player_states, :board, :frames, :timestamp]
  defstruct players: nil, player_states: nil, board: nil, frames: nil, timestamp: nil

  @timeout 5000
  @max_turns 20_000

  alias TrademarkFreeStrategicLandWarfare.{Player, Board, Frame}

  @type t() :: %__MODULE__{
          players: [Player.t()],
          player_states: [any()],
          board: Board.t(),
          frames: [Frame.t()],
          timestamp: binary()
        }

  @type player_number() :: 1 | 2

  @spec go([%TrademarkFreeStrategicLandWarfare.Player{}]) ::
          {:ok, %__MODULE__{}} | {:error, binary()}
  def go(modules) when length(modules) == 2 do
    players =
      modules
      |> Enum.with_index(1)
      |> Enum.map(fn {module, number} ->
        Player.new(module, number)
      end)

    results =
      modules
      |> Enum.map(fn module -> perform_task(module, :initial_pieces_placement, []) end)
      |> Enum.map(fn task -> task_result(task) end)

    case results do
      [p1, p2]
      when p1 in [nil, {:error, :task_exception}] and p2 in [nil, {:error, :task_exception}] ->
        tie(
          nil,
          players,
          {:error,
           "no moves - both players either timed out or threw exception - player 1: #{inspect(p1)}, player 2: #{
             inspect(p2)
           }"}
        )

      [p1, placements] when p1 in [nil, {:error, :task_exception}] ->
        case Board.init_pieces(Board.new(), placements, 2) do
          {:error, error} ->
            tie(
              nil,
              players,
              {:error,
               "player 1 timeout/exception #{inspect(p1)}, player 2 incorrect placements #{
                 inspect(error)
               }"}
            )

          {:ok, board} ->
            winner(nil, board, players, 2, {:error, "player 1 timeout/exception #{inspect(p1)}"})
        end

      [placements, p2] when p2 in [nil, {:error, :task_exception}] ->
        case Board.init_pieces(Board.new(), placements, 1) do
          {:error, error} ->
            tie(
              nil,
              players,
              {:error,
               "player 2 timeout/exception #{inspect(p2)}, player 1 incorrect placements #{
                 inspect(error)
               }"}
            )

          {:ok, board} ->
            winner(nil, board, players, 1, {:error, "player 2 timeout/exception #{inspect(p2)}"})
        end

      [placements1, placements2] ->
        {:ok, board_player_1} = Board.init_pieces(Board.new(), placements1, 1)
        {:ok, board} = Board.init_pieces(board_player_1, placements2, 2)

        %__MODULE__{
          players: players,
          player_states: [nil, nil],
          board: board,
          frames: [Frame.new(board.rows, {:ok, "both players placed pieces successfully"}, nil)],
          # don't call DateTime.now! more than once per game
          timestamp: DateTime.now!("Etc/UTC")
        }
        |> perform_turns(1, [], 0)
    end
  end

  defp perform_turns(%__MODULE__{} = game, 1, _, @max_turns) do
    tie(
      game,
      game.board,
      game.player_states,
      {:error, "max turns reached (#{@max_turns}.  tie game."}
    )
  end

  defp perform_turns(%__MODULE__{} = game, player_number, errors, _) when length(errors) == 3 do
    winner(
      game,
      game.board,
      game.player_states,
      other_player_number(player_number),
      {:error, "player #{player_number} 3 errors in a row, #{inspect(errors)}"}
    )
  end

  defp perform_turns(%__MODULE__{} = game, player_number, errors, turn_count) do
    {%Player{number: ^player_number, module: module} = player, state} =
      game.players
      |> Enum.zip(game.player_states)
      |> Enum.at(player_number - 1)

    # mask board when passing to player
    board_for_player = Board.mask_board(game.board, player_number)

    turn_result =
      module
      |> perform_task(:turn, [board_for_player, player, state])
      |> task_result()

    case turn_result do
      player_turn_result when player_turn_result in [nil, {:error, :task_exception}] ->
        perform_turns(
          game,
          player_number,
          errors ++
            [
              "Player number #{player_number} timeout/exception when trying to perform :turn - #{
                inspect(player_turn_result)
              }"
            ],
          turn_count + 1
        )

      {piece_uuid, direction, count, state}
      when is_binary(piece_uuid) and
             direction in [:north, :south, :west, :east] and
             is_integer(count) ->
        case Board.move(game.board, player_number, piece_uuid, direction, count) do
          {:error, error} ->
            {{x, y}, piece} = Board.lookup_by_uuid(game.board, piece_uuid)

            perform_turns(
              game,
              player_number,
              errors ++
                [
                  "Player number #{player_number} tried to move #{piece_uuid}, a #{piece.name}, #{
                    direction
                  } to coordinate {#{x}, #{y}}, but failed: #{inspect(error)}"
                ],
              turn_count + 1
            )

          {:ok, :win, new_board} ->
            winner(
              game,
              new_board,
              List.update_at(game.player_states, player_number - 1, fn _ -> state end),
              player_number,
              {:ok,
               "player #{player_number} captured player #{other_player_number(player_number)}'s flag after #{turn_count} moves"}
            )

          {:ok, new_board} ->
            game
            |> struct(
              player_states:
                List.update_at(game.player_states, player_number - 1, fn _ -> state end),
              board: new_board,
              frames:
                game.frames ++
                  [
                    Frame.new(
                      new_board.rows,
                      {:ok, "player #{player_number} successfully moved"},
                      nil
                    )
                  ]
            )
            |> perform_turns(other_player_number(player_number), [], turn_count + 1)
        end

      _ ->
        winner(
          game,
          game.board,
          game.player_states,
          other_player_number(player_number),
          {:error, "player #{player_number} time out or didn't match spec - automatic loss"}
        )
    end

    # look back in frame history for repeating moves
  end

  # def write_to_disk(%__MODULE__{} = game, file) do
  # end

  # def load_from_disk(file) do
  # end

  # def create_filename() do
  # end

  # def list_files() do
  # end

  defp perform_task(module, function, arguments) do
    Task.async(fn ->
      try do
        apply(module, function, arguments)
      rescue
        _ -> {:error, :task_exception}
      end
    end)
  end

  defp task_result(task) do
    case Task.yield(task, @timeout) || Task.shutdown(task) do
      {:ok, result} ->
        result

      nil ->
        IO.puts("Failed to get a result in #{@timeout}ms")
        nil
    end
  end

  # only called when neither player placed pieces successfully at beginning
  defp tie(nil, players, move) do
    board = Board.new()

    %__MODULE__{
      players: players,
      player_states: [nil, nil],
      board: board,
      frames: [Frame.new(board.rows, move, {:ok, :tie})],
      timestamp: DateTime.now!("Etc/UTC")
    }
  end

  defp tie(game, new_board, new_states, move) do
    result(game, new_board, new_states, move, {:ok, :tie})
  end

  # only called when one player can't place pieces successfully at beginning
  defp winner(nil, board, players, player_number, move) do
    %__MODULE__{
      players: players,
      player_states: [nil, nil],
      board: board,
      frames: [Frame.new(board.rows, move, {:ok, :win, player_number})],
      timestamp: DateTime.now!("Etc/UTC")
    }
  end

  defp winner(game, new_board, new_states, player_number, move) do
    result(game, new_board, new_states, move, {:ok, :win, player_number})
  end

  defp result(game, new_board, states, move, status) do
    struct(
      game,
      board: new_board,
      frames: game.frames ++ [Frame.new(new_board.rows, move, status)],
      player_states: states
    )
  end

  @spec other_player_number(player_number()) :: player_number()
  def other_player_number(1), do: 2
  def other_player_number(2), do: 1

  # # can't move back and forth more than 3 times
  # # automatic loss when player can't move
  # # loss when 3 errors in a row returned for game
  # # loss when timeout on call
  # # draw when 10000 moves happen without a win

  # # rules http://www.stratego.com/en/play/stratego-rules/
  # #       https://www.playmonster.com/wp-content/uploads/2018/06/7471_Classic_English_Rules.pdf
end
