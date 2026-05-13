defmodule Keyimg.CrdtGCounter do
  use GenServer

  @name __MODULE__

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: @name)
  end

  @spec increment(term()) :: non_neg_integer()
  def increment(key) do
    GenServer.call(@name, {:increment, key})
  end

  @spec value(term()) :: non_neg_integer()
  def value(key) do
    GenServer.call(@name, {:value, key})
  end

  def merge_snapshot(remote_entries) when is_map(remote_entries) do
    GenServer.cast(@name, {:merge, remote_entries})
  end

  @impl true
  def init(_) do
    schedule_gossip()
    {:ok, %{entries: %{}}}
  end

  @impl true
  def handle_call({:increment, key}, _from, state) do
    now = System.monotonic_time(:millisecond)
    current = Map.get(state.entries, key, %{counts: %{}, updated_at: now})
    node_count = Map.get(current.counts, node(), 0) + 1
    counts = Map.put(current.counts, node(), node_count)
    updated = %{counts: counts, updated_at: now}
    entries = Map.put(state.entries, key, updated)

    total = counts |> Map.values() |> Enum.sum()
    {:reply, total, %{state | entries: entries}}
  end

  @impl true
  def handle_call({:value, key}, _from, state) do
    total =
      state.entries
      |> Map.get(key, %{counts: %{}})
      |> Map.get(:counts)
      |> Map.values()
      |> Enum.sum()

    {:reply, total, state}
  end

  @impl true
  def handle_cast({:merge, remote_entries}, state) do
    {:noreply, %{state | entries: merge_entries(state.entries, remote_entries)}}
  end

  @impl true
  def handle_info(:gossip, state) do
    pruned = prune_entries(state.entries)

    Enum.each(Node.list(), fn n ->
      :rpc.cast(n, __MODULE__, :merge_snapshot, [pruned])
    end)

    schedule_gossip()
    {:noreply, %{state | entries: pruned}}
  end

  defp merge_entries(local, remote) do
    Map.merge(local, remote, fn _key, left, right ->
      counts =
        Map.merge(left.counts, right.counts, fn _node, l, r -> max(l, r) end)

      %{counts: counts, updated_at: max(left.updated_at, right.updated_at)}
    end)
  end

  defp prune_entries(entries) do
    now = System.monotonic_time(:millisecond)
    ttl = Application.fetch_env!(:keyimg, :crdt_entry_ttl_ms)

    entries
    |> Enum.reject(fn {_key, value} -> now - value.updated_at > ttl end)
    |> Map.new()
  end

  defp schedule_gossip do
    interval = Application.fetch_env!(:keyimg, :crdt_gossip_interval_ms)
    Process.send_after(self(), :gossip, interval)
  end
end
