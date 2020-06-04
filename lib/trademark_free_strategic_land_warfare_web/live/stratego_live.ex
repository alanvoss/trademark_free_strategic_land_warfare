defmodule TrademarkFreeStrategicLandWarfareWeb.StrategoLive do
  use TrademarkFreeStrategicLandWarfareWeb, :live_view
  alias TrademarkFreeStrategicLandWarfare.Board

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
       pieces: pieces,
       player_1_name: "",
       player_2_name: "",
       game_pid: nil,
       frame_index: nil,
       last_frame_index: nil
     )}
  end

  # display turn and result status
  # list of games
  # all combos
  # specs for everything public

  @impl true
  def handle_event("modules-selected", %{"modules" => modules_data}, socket) do
    %{:game_pid => game_pid} = socket.assigns
    modules = Enum.map(modules_data, &(&1["id"] |> String.to_atom()))

    # game is run in advance
    result_game = TrademarkFreeStrategicLandWarfare.Game.go(modules)
    # cancel existing game
    if game_pid do
      Process.exit(game_pid, :kill)
    end

    me = self()

    {:ok, game_pid} =
      Task.start(fn ->
        task_runner(me, {"start", result_game, 0})
      end)

    send(game_pid, "start")

    {:noreply,
     assign(socket,
       player_1_name: Enum.at(modules, 0).name,
       player_2_name: Enum.at(modules, 1).name,
       game_pid: game_pid
     )}
  end

  @impl true
  def handle_event("playback-control", %{"action" => action}, socket)
      when action in ["pause", "play", "forward", "back", "start", "end"] do
    %{:game_pid => game_pid} = socket.assigns

    case game_pid do
      nil ->
        nil

      pid ->
        send(pid, action)
    end

    {:noreply, socket}
  end

  def task_runner(liveview_pid, {action, game, frame_index} = message) do
    frames_last_index = length(game.frames) - 1

    receive do
      act when act in ["play", "forward"] ->
        next_frame_index = min(frames_last_index, frame_index + 1)
        send(liveview_pid, {"display", game, next_frame_index})
        task_runner(liveview_pid, {act, game, next_frame_index})

      "pause" ->
        send(liveview_pid, {"display", game, frame_index})
        task_runner(liveview_pid, {"pause", game, frame_index})

      "back" ->
        next_frame_index = max(0, frame_index - 1)
        send(liveview_pid, {"display", game, next_frame_index})
        task_runner(liveview_pid, {"pause", game, next_frame_index})

      "start" ->
        send(liveview_pid, {"display", game, 0})
        task_runner(liveview_pid, {"pause", game, 0})

      "end" ->
        send(liveview_pid, {"display", game, frames_last_index})
        task_runner(liveview_pid, {"pause", game, frames_last_index})
    after
      200 ->
        if action == "play" do
          send(self(), action)
        end

        task_runner(liveview_pid, message)
    end
  end

  @impl true
  def handle_info({"display", result_game, index}, socket) do
    case get_frame(result_game, index) do
      nil ->
        {:noreply, socket}

      frame ->
        {:noreply,
         assign(
           socket,
           result: result_game,
           frame_index: index,
           last_frame_index: index == length(result_game.frames) - 1,
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
