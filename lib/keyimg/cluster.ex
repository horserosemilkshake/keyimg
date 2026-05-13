defmodule Keyimg.Cluster do
  use GenServer

  alias Keyimg.HashRing

  @name __MODULE__

  defstruct ring: [], nodes: [node()]

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: @name)
  end

  @spec nodes() :: [node()]
  def nodes do
    GenServer.call(@name, :nodes)
  end

  @spec replicas_for(term(), pos_integer() | nil) :: [node()]
  def replicas_for(key, count \\ nil) do
    GenServer.call(@name, {:replicas, key, count})
  end

  @impl true
  def init(_) do
    :net_kernel.monitor_nodes(true)
    {:ok, rebuild_state()}
  end

  @impl true
  def handle_info({:nodeup, _n}, _state), do: {:noreply, rebuild_state()}

  @impl true
  def handle_info({:nodedown, _n}, _state), do: {:noreply, rebuild_state()}

  @impl true
  def handle_call(:nodes, _from, state) do
    {:reply, state.nodes, state}
  end

  @impl true
  def handle_call({:replicas, key, count}, _from, state) do
    replica_count = count || Application.fetch_env!(:keyimg, :replica_count)
    selected = HashRing.replicas(state.ring, key, min(replica_count, length(state.nodes)))
    {:reply, selected, state}
  end

  defp rebuild_state do
    nodes = ([node()] ++ Node.list()) |> Enum.uniq() |> Enum.sort()
    vnode_count = Application.fetch_env!(:keyimg, :hash_ring_vnodes)
    ring = HashRing.build(nodes, vnode_count)
    %__MODULE__{ring: ring, nodes: nodes}
  end
end
