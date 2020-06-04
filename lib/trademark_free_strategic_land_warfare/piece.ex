defmodule TrademarkFreeStrategicLandWarfare.Piece do
  @derive Jason.Encoder
  @enforce_keys [:uuid, :player, :visible]
  defstruct uuid: nil, player: nil, name: nil, visible: nil, rank: nil, lose_when_attacked_by: nil

  @type t() :: %__MODULE__{
          uuid: String.t(),
          player: Integer.t(),
          name: Atom.t(),
          visible: boolean(),
          rank: Integer.t(),
          lose_when_attacked_by: Atom.t()
        }

  @name_properties %{
    flag: %{},
    bomb: %{lose_when_attacked_by: :miner},
    spy: %{rank: 1},
    scout: %{rank: 2},
    miner: %{rank: 3},
    sergeant: %{rank: 4},
    lieutenant: %{rank: 5},
    captain: %{rank: 6},
    major: %{rank: 7},
    colonel: %{rank: 8},
    general: %{rank: 9},
    marshall: %{rank: 10, lose_when_attacked_by: :spy}
  }

  @type player_number() :: 1 | 2

  @names Map.keys(@name_properties)

  @spec new(binary(), player_number()) ::
          RuntimeError | %__MODULE__{uuid: binary(), player: player_number(), visible: boolean()}
  def new(_, player) when player < 1 or player > 2 do
    raise "player valid range is 1-2!"
  end

  def new(name, _) when name not in @names do
    raise "piece name must be one of #{inspect(@names)}!"
  end

  def new(name, player) when name in @names do
    properties =
      Map.merge(
        %{
          uuid: UUID.uuid1(),
          player: player,
          name: name,
          visible: false
        },
        @name_properties[name]
      )

    struct(__MODULE__, properties)
  end

  @spec reveal(%__MODULE__{}) :: %__MODULE__{}
  def reveal(piece) do
    %__MODULE__{piece | visible: true}
  end

  # current player, show piece
  @spec maybe_mask(%__MODULE__{}, player_number()) :: %__MODULE__{}
  def maybe_mask(piece = %__MODULE__{player: player}, player) do
    piece
  end

  # opposing player, visible (was previously exposed), show piece
  def maybe_mask(piece = %__MODULE__{visible: true}, _) do
    piece
  end

  def maybe_mask(piece, _) when piece in [nil, :lake], do: piece

  # opposing player, not visible, mask piece
  def maybe_mask(piece, _) do
    %__MODULE__{
      uuid: piece.uuid,
      player: piece.player,
      name: nil,
      visible: piece.visible,
      rank: nil,
      lose_when_attacked_by: nil
    }
  end

  @spec attack(%__MODULE__{}, %__MODULE__{}) ::
          {:ok, :win | [remove: [binary()]]} | {:error, binary() | atom()}
  def attack(%__MODULE__{name: :flag}, _), do: {:error, "flag can never be the attacker"}
  def attack(%__MODULE__{name: :bomb}, _), do: {:error, "bomb can never be the attacker"}
  def attack(_, %__MODULE__{name: :flag}), do: {:ok, :win}

  def attack(
        %__MODULE__{name: name},
        %__MODULE__{lose_when_attacked_by: name, uuid: uuid}
      )
      when name != nil do
    {:ok, [remove: [uuid]]}
  end

  def attack(%__MODULE__{uuid: uuid}, %__MODULE__{name: :bomb}) do
    {:ok, [remove: [uuid]]}
  end

  def attack(
        %__MODULE__{rank: rank, uuid: uuid_attacker},
        %__MODULE__{rank: rank, uuid: uuid_defender}
      )
      when rank != nil do
    {:ok, [remove: [uuid_attacker, uuid_defender]]}
  end

  def attack(
        %__MODULE__{rank: attacker_rank} = attacker,
        %__MODULE__{rank: defender_rank} = defender
      )
      when nil not in [attacker_rank, defender_rank] do
    if attacker.rank > defender.rank do
      {:ok, [remove: [defender.uuid]]}
    else
      {:ok, [remove: [attacker.uuid]]}
    end
  end

  # at least one is a masked piece, so can't be sure what will happen.
  # this would never happen for the game engine, but when a player
  # uses it on their turn, the opponent might have a masked piece,
  # in which case the rank, name, and what they lose to might be hidden
  # if the piece has never been attacked before or if it is a scout
  # and has never moved 2 or more pieces.
  def attack(_, _), do: {:error, :unknown_result}

  @spec names() :: list(atom())
  def names() do
    @names
  end
end
