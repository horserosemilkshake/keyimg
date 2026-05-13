defmodule Keyimg.HordeCoordinator do
  use GenServer

  @registry Keyimg.HordeRegistry
  @supervisor Keyimg.HordeSupervisor

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    :net_kernel.monitor_nodes(true)
    send(self(), :sync_members)
    {:ok, state}
  end

  @impl true
  def handle_info({:nodeup, _node}, state) do
    send(self(), :sync_members)
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodedown, _node}, state) do
    send(self(), :sync_members)
    {:noreply, state}
  end

  @impl true
  def handle_info(:sync_members, state) do
    members =
      ([node()] ++ Node.list())
      |> Enum.uniq()
      |> Enum.map(fn n -> {Keyimg.HordeRegistry, n} end)

    Horde.Cluster.set_members(@registry, members)

    supervisor_members =
      ([node()] ++ Node.list())
      |> Enum.uniq()
      |> Enum.map(fn n -> {Keyimg.HordeSupervisor, n} end)

    Horde.Cluster.set_members(@supervisor, supervisor_members)
    {:noreply, state}
  end
end
