defmodule TrademarkFreeStrategicLandWarfare.Board do
  @enforce_keys [:board, :lookup]
  defstruct board: nil, lookup: nil

  @type t() :: %__MODULE__{
          board: [List.t()],
          lookup: Map.t()
        }

  # def new(player_pieces) do

  #   properties =
  #     Map.merge(
  #       %{
  #         name: name,
  #         visible: false,
  #         uuid: UUID.uuid1()
  #       },
  #       @name_properties[name]
  #     )

  #   struct(__MODULE__, properties)
  # end

  # def reveal(piece) do
  #    %__MODULE__{piece | visible: true}
  # end

  # def attack(_, %__MODULE__{name: :flag}), do: {:ok, :win}
  # def attack(%__MODULE__{name: name},
  #            %__MODULE__{lose_when_attacked_by: name, uuid: uuid}) when name != nil do
  #   {:ok, [remove: [uuid]]}
  # end
  # def attack(%__MODULE__{rank: rank, uuid: uuid_attacker},
  #            %__MODULE__{rank: rank, uuid: uuid_defender}) do
  #   {:ok, [remove: [uuid_attacker, uuid_defender]]}
  # end
  # def attack(attacker, defender) do
  #   if attacker.rank > defender.rank do
  #     {:ok, [remove: [defender.uuid]]}
  #   else
  #     {:ok, [remove: [attacker.uuid]]}
  #   end
  # end

  # def names() do
  #   @names
  # end
end
