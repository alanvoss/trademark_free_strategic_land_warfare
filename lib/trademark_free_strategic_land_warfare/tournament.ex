defmodule TrademarkFreeStrategicLandWarfare.Tournament do
  @enforce_keys [:uuid, :games, :results]
  defstruct uuid: nil, games: nil, results: nil

  alias TrademarkFreeStrategicLandWarfare.Game

  @type t() :: %__MODULE__{
          uuid: binary(),
          games: list(Game),
          results: list({binary(), integer})
        }

  @spec go() :: {:error, binary()} | {:ok, %__MODULE__{}}
  def go() do
    combos = combinations(all_player_modules(), 2)

    if length(combos) == 0 do
      {:error, "no contenders"}
    else
      all_games =
        combos
        |> Task.async_stream(Game, :go, [], timeout: 25_000)
        |> Enum.map(fn {:ok, game} -> game end)
        |> Enum.to_list()

      results =
        all_games
        |> Enum.reduce(%{}, fn game, acc ->
          [player1, player2] = players = game.players
          result_frame = List.last(game.frames)

          case result_frame.result do
            {:ok, :tie} ->
              # add 0.5 to both
              acc
              |> Map.update(player1.name(), 0.5, &(&1 + 0.5))
              |> Map.update(player2.name(), 0.5, &(&1 + 0.5))

            {:ok, :win, player_number} ->
              winning_player = get_in(players, [Access.at(player_number - 1)])
              Map.update(acc, winning_player.name(), 1, &(&1 + 1))

            _ ->
              acc
          end
        end)
        |> Enum.sort(&(elem(&1, 1) >= elem(&2, 1)))

      {:ok,
       %__MODULE__{
         uuid: UUID.uuid1(),
         games: all_games,
         results: results
       }}
    end
  end

  @spec all_player_modules() :: list(atom())
  def all_player_modules() do
    {:ok, modules} = :application.get_key(:trademark_free_strategic_land_warfare, :modules)

    Enum.filter(
      modules,
      &String.starts_with?(
        Atom.to_string(&1),
        "Elixir.TrademarkFreeStrategicLandWarfare.Players"
      )
    )
  end

  defp combinations(_, 0), do: [[]]
  defp combinations([], _), do: []

  defp combinations(_deck = [x | xs], n) when is_integer(n) do
    for(y <- combinations(xs, n - 1), do: [x | y]) ++ combinations(xs, n)
  end
end
