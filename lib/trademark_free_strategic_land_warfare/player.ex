defmodule TrademarkFreeStrategicLandWarfare.Player do
  @enforce_keys [:name, :player]
  defstruct name: nil, player: nil

  @type t() :: %__MODULE__{
          name: String.t(),
          player: Integer.t()
        }

  def new(nil, player) do
    raise "player must have a name!"
  end

  def new(_, player) when player < 1 or player > 2 do
    raise "player valid range is 1-2!"
  end

  def new(name, player) do
    %__MODULE__{
      name: name,
      player: player
    }
  end
end
