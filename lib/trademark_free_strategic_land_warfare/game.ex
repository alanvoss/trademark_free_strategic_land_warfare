defmodule TrademarkFreeStrategicLandWarfare.Frame do
  @derive Jason.Encoder
  @enforce_keys [:rows, :move]
  defstruct rows: nil, move: nil, result: nil

  @type t() :: %__MODULE__{
          rows: [List.t()],
          move: {:ok | :error, String.t()},
          result: nil | {:ok | :error, String.t()}
          # result: nil | String.t()
          # move: String.t(),
          # result: String.t()
        }

  def new(rows, move, result) do
    %__MODULE__{rows: rows, move: move, result: result}
  end
end

defmodule TrademarkFreeStrategicLandWarfare.Game do
  @derive Jason.Encoder
  @enforce_keys [:players, :player_states, :board, :frames, :timestamp]
  defstruct players: nil, player_states: nil, board: nil, frames: nil, timestamp: nil

  @timeout 5000

  alias TrademarkFreeStrategicLandWarfare.{Player, Board, Frame, TaskSupervisor}

  @type t() :: %__MODULE__{
          players: [Player.t()],
          player_states: [any()],
          board: Board.t(),
          frames: [Frame.t()],
          timestamp: String.t()
        }

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
      [nil, nil] ->
        tie(Board.new(), [], players, {:error, "no moves"})

      [nil, placements] ->
        case Board.init_pieces(Board.new(), placements, 2) do
          {:error, error} ->
            tie(
              Board.new(),
              [],
              players,
              {:error, "player 1 timeout, player 2 incorrect placements #{inspect(error)}"}
            )

          {:ok, board} ->
            winner(board, [], players, 2, {:error, "player 1 timeout"})
        end

      [placements, nil] ->
        case Board.init_pieces(Board.new(), placements, 1) do
          {:error, error} ->
            tie(
              Board.new(),
              [],
              players,
              {:error, "player 2 timeout, player 1 incorrect placements #{inspect(error)}"}
            )

          {:ok, board} ->
            winner(board, [], players, 1, {:error, "player 2 timeout"})
        end

      [placements1, placements2] ->
        board =
          Board.new()
          |> Board.init_pieces(placements1, 1)
          |> Board.init_pieces(placements2, 2)

        %__MODULE__{
          players: players,
          player_states: [nil, nil],
          board: board,
          frames: [Frame.new(board.rows, {:ok, "both players placed pieces successfully"}, nil)],
          timestamp: DateTime.now!("Etc/UTC")
        }
        |> perform_turns(1, 0, [])
    end
  end

  defp perform_turns(%__MODULE__{} = game, player_number, 3, errors) do
    winner(
      game.board,
      game.frames,
      game.players,
      other_player_number(player_number),
      {:error, "player #{player_number} 3 errors in a row, #{inspect(errors)}"}
    )
  end

  defp perform_turns(%__MODULE__{} = game, player_number, error_count, errors) do
    {%Player{number: ^player_number, module: module} = player, state} =
      game.players
      |> Enum.zip(game.player_states)
      |> Enum.at(player_number - 1)

    board =
      struct(game.board,
        rows:
          game.board
          # mask board when passing to player
          |> Board.mask_board(player_number)
          |> Map.get(:rows)
          # for move, flip for player 2 for display
          |> Board.maybe_flip(player_number)
      )

    turn_result =
      module
      |> perform_task(:turn, [board, player, state])
      |> task_result()

    case turn_result do
      {piece_uuid, direction, count, state}
      when is_binary(piece_uuid) and
             direction in [:forward, :backward, :left, :right] and
             is_integer(count) ->
        case Board.move(board, player_number, piece_uuid, direction, count) do
          {:error, error} ->
            {current_coord, piece} = Board.lookup_by_uuid(board, piece_uuid)

            {x, y} =
              Board.new_coordinate(
                current_coord,
                Board.maybe_invert_player_direction(direction, player_number)
              )

            perform_turns(
              game,
              player_number,
              error_count + 1,
              errors ++
                [
                  "#{player_number} tried to move #{piece_uuid}, a #{piece.name}, #{direction} to coordinate {#{
                    x
                  }, #{y}}, but failed: #{inspect(error)}"
                ]
            )

          {:ok, :win, new_board} ->
            winner(
              new_board,
              game.frames,
              game.players,
              player_number,
              {:ok,
               "player #{player_number} captured player #{other_player_number(player_number)}'s flag"}
            )

          {:ok, new_board} ->
            %__MODULE__{
              game
              | player_states:
                  List.update_at(game.player_states, player_number - 1, fn _ -> state end),
                board: new_board,
                frames:
                  game.previous_frames ++
                    [
                      Frame.new(
                        new_board.rows,
                        {:ok, "player #{player_number} successfully moved"},
                        nil
                      )
                    ]
            }
            |> perform_turns(other_player_number(player_number), 0, [])
        end

      _ ->
        winner(
          game.board,
          game.frames,
          game.players,
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
    Task.Supervisor.async_nolink(
      TaskSupervisor,
      fn -> apply(module, function, arguments) end
    )
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

  defp tie(board, frames, players, move) do
    result(board, frames, players, move, {:ok, :tie})
  end

  defp winner(board, frames, players, player_number, move) do
    result(board, frames, players, move, {:ok, :win, player_number})
  end

  defp result(board, previous_frames, players, move, status) do
    %__MODULE__{
      players: players,
      # TODO: actual player state in result
      player_states: [nil, nil],
      board: board,
      frames: previous_frames ++ [Frame.new(board.rows, move, status)],
      timestamp: DateTime.now!("Etc/UTC")
    }
  end

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
