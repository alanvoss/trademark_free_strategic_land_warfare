defmodule TrademarkFreeStrategicLandWarfare.Player do
  @derive Jason.Encoder
  @enforce_keys [:name, :number, :module]
  defstruct name: nil, number: nil, module: nil

  @type t() :: %__MODULE__{
          name: binary(),
          number: Integer.t(),
          module: Atom.t()
        }

  @type state() :: any()
  @type piece_uuid() :: binary()
  @type direction() :: Atom.t()
  @type count() :: Integer.t()

  # return a string that your module will be referred by in the tournament.
  #   NOTE: it should be deterministic and return the same thing across
  #         invocations.
  @callback name() :: binary()

  # should return a list with 4 lists, each containing 10 piece names
  # with proper counts for each.  See: Board's @piece_name_counts
  # each list will represent a row on the board, and index 0 will be the
  # frontmost row, while index 3 will be the backmost.
  @callback initial_pieces_placement() :: nonempty_list([Atom.t(), ...])

  # given:
  # - board
  #   - rows (the orientation for player number 2 will be rotated, so that you
  #           will always be advancing towards index 0 of the rows, and
  #           your pieces will be originally places on rows 6-9)
  #   - lookup (do not use this directly, as it will be flipped for player 2.
  #             instead, use `Board.lookup_by_uuid/3` and `Board.lookup_by_coord/3`
  #             and pass this map)
  # - number (which will include the player number - 1 or 2 - which you'll need for
  #           for some function calls to properly orient)
  # - state (any state that you would like your player to retain
  #
  # return:
  # - piece's uuid
  # - direction (`:forward`, `:backward`, `:left`, `:right`)
  # - state for the next call.
  @callback turn(
              TrademarkFreeStrategicLandWarfare.Board.t(),
              TrademarkFreeStrategicLandWarfare.Player.t(),
              state()
            ) :: {piece_uuid(), direction(), count(), state()}

  @type player_number() :: 1 | 2

  @spec new(module(), player_number()) :: %__MODULE__{} | RuntimeError
  def new(module, number) when number in [1, 2] do
    %__MODULE__{
      name: get_name(module),
      number: number,
      module: module
    }
  end

  def new(_, _), do: raise("player valid range is 1-2!")

  defp get_name(module) do
    apply(module, :name, [])
  rescue
    _e in UndefinedFunctionError -> "#{module}"
  end
end
