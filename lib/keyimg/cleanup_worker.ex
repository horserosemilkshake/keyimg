defmodule Keyimg.CleanupWorker do
  use GenServer

  alias Keyimg.Service

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    schedule_cleanup()
    {:ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    :ok = Service.cleanup_expired()

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    interval = Application.fetch_env!(:keyimg, :cleanup_interval_ms)
    Process.send_after(self(), :cleanup, interval)
  end
end
