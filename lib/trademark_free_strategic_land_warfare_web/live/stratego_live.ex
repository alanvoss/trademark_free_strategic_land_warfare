defmodule TrademarkFreeStrategicLandWarfareWeb.StrategoLive do
  use TrademarkFreeStrategicLandWarfareWeb, :live_view
  alias TrademarkFreeStrategicLandWarfare.{Game, Board}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, modules} = :application.get_key(:trademark_free_strategic_land_warfare, :modules)

    player_modules =
      Enum.filter(
        modules,
        &String.starts_with?(
          Atom.to_string(&1),
          "Elixir.TrademarkFreeStrategicLandWarfare.Players"
        )
      )

    module_names =
      player_modules
      |> Enum.map(& &1.name())

    pieces = [
      {"marshall", 10},
      {"general", 9},
      {"colonel", 8},
      {"major", 7},
      {"captain", 6},
      {"lieutenant", 5},
      {"sergeant", 4},
      {"miner", 3},
      {"scout", 2},
      {"spy", 1},
      {"flag", nil},
      {"bomb", nil}
    ]

    {:ok,
     assign(
       socket,
       rows: Board.new().rows,
       modules: Enum.zip(player_modules, module_names),
       pieces: pieces
     )}
  end

  @impl true
  def handle_event("modules-selected", %{"modules" => modules_data}, socket) do
    modules = Enum.map(modules_data, &(&1["id"] |> String.to_atom()))
    result_game = TrademarkFreeStrategicLandWarfare.Game.go(modules)
    send(self(), {"continue-game", modules, result_game, 0})
    {:noreply, socket}
  end

  def handle_info({"continue-game", modules, result_game, index}, socket) do
    case get_frame(result_game, index) do
      nil ->
        {:noreply, socket}

      frame ->
        :timer.sleep(200)
        send(self(), {"continue-game", modules, result_game, index + 1})

        {:noreply,
         assign(
           socket,
           modules: modules,
           result: result_game,
           frame_index: index,
           rows: frame.rows,
           move: frame.move,
           result: frame.result
         )}
    end
  end

  defp get_frame(game, index) do
    Enum.at(game.frames, index)
  end
end
