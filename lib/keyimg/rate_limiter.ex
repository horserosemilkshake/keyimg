defmodule Keyimg.RateLimiter do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def allow?(ip) do
    now = System.monotonic_time(:millisecond)
    window = Application.fetch_env!(:keyimg, :rate_limit_window_ms)
    capacity = Application.fetch_env!(:keyimg, :rate_limit_capacity)

    key = {:rate_limit, ip, div(now, window)}
    count = Keyimg.CrdtGCounter.increment(key)

    count <= capacity
  end

  @impl true
  def init(_) do
    {:ok, %{}}
  end
end
