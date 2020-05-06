defmodule TrademarkFreeStrategicLandWarfare.Piece do
  @enforce_keys [:uuid, :name, :visible, :rank, :lose_when_attacked_by]
  defstruct uuid: nil, name: nil, visible: nil, rank: nil, lose_when_attacked_by: nil

  @type t() :: %__MODULE__{
          uuid: String.t(),
          name: String.t(),
          visible: boolean(),
          rank: Integer.t(),
          lose_when_attacked_by: [Tuple.t()]
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

  @names Map.keys(@name_properties)

  def new(name) when name in @names do
    properties =
      Map.merge(
        %{
          name: name,
          visible: false,
          uuid: UUID.uuid1()
        },
        @name_properties[name]
      )

    struct(__MODULE__, properties)
  end

  def reveal(piece) do
    %__MODULE__{piece | visible: true}
  end

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

  def names() do
    @names
  end
end
