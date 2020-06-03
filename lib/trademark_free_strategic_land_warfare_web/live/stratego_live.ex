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

    {:ok, assign(socket, rows: Board.new().rows, modules: Enum.zip(player_modules, module_names))}
  end

  @impl true
  def handle_event("modules-selected", %{"modules" => modules_data}, socket) do
    result =
      modules_data
      |> Enum.map(&(&1["id"] |> String.to_atom()))
      |> TrademarkFreeStrategicLandWarfare.Game.go()

    require IEx
    IEx.pry()

    {:noreply, assign(socket, modules: modules_data)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    case search(query) do
      %{^query => vsn} ->
        {:noreply, redirect(socket, external: "https://hexdocs.pm/#{query}/#{vsn}")}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "No dependencies found matching \"#{query}\"")
         |> assign(results: %{}, query: query)}
    end
  end

  defp search(query) do
    if not TrademarkFreeStrategicLandWarfareWeb.Endpoint.config(:code_reloader) do
      raise "action disabled when not in development"
    end

    for {app, desc, vsn} <- Application.started_applications(),
        app = to_string(app),
        String.starts_with?(app, query) and not List.starts_with?(desc, ~c"ERTS"),
        into: %{},
        do: {app, vsn}
  end
end
