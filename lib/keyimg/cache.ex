defmodule Keyimg.Cache do
  use GenServer

  @table :keyimg_cache

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get(key) do
    case :ets.lookup(@table, key) do
      [{^key, value}] -> {:ok, value}
      [] -> :error
    end
  end

  def put(key, value) do
    :ets.insert(@table, {key, value})
    :ok
  end

  def delete(key) do
    :ets.delete(@table, key)
    :ok
  end

  def clear do
    :ets.delete_all_objects(@table)
    :ok
  end

  @impl true
  def init(_) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{}}
  end
end
