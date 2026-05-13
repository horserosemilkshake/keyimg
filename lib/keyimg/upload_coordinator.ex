defmodule Keyimg.UploadCoordinator do
  use GenServer

  alias Keyimg.Metadata

  @registry Keyimg.HordeRegistry
  @supervisor Keyimg.HordeSupervisor

  def child_spec(upload_id) do
    %{
      id: {:upload_coordinator, upload_id},
      start: {__MODULE__, :start_link, [upload_id]},
      restart: :transient,
      type: :worker
    }
  end

  def start_link(upload_id) do
    GenServer.start_link(__MODULE__, upload_id, name: via(upload_id))
  end

  def ensure_started(upload_id) do
    case GenServer.whereis(via(upload_id)) do
      nil ->
        Horde.DynamicSupervisor.start_child(@supervisor, child_spec(upload_id))

      _pid ->
        :ok
    end
  end

  def append(upload_id, chunk) do
    with :ok <- ensure_started(upload_id) do
      GenServer.call(via(upload_id), {:append, chunk})
    end
  end

  def complete(upload_id) do
    with :ok <- ensure_started(upload_id) do
      GenServer.call(via(upload_id), :complete)
    end
  end

  def abort(upload_id) do
    with :ok <- ensure_started(upload_id) do
      GenServer.call(via(upload_id), :abort)
    end
  end

  def via(upload_id), do: {:via, Horde.Registry, {@registry, {:upload, upload_id}}}

  @impl true
  def init(upload_id) do
    {:ok, %{upload_id: upload_id}}
  end

  @impl true
  def handle_call({:append, chunk}, _from, state) do
    result =
      case Metadata.get_upload(state.upload_id) do
        {:ok, upload} when upload.status == :pending ->
          Keyimg.Storage.append_to_temp!(upload.temp_path, chunk)
          updated = %{upload | received_bytes: upload.received_bytes + byte_size(chunk)}
          :ok = Metadata.upsert_upload(updated)
          :ok

        {:ok, _upload} ->
          {:error, :upload_not_pending}

        :error ->
          {:error, :upload_not_found}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:complete, _from, state) do
    result =
      case Metadata.get_upload(state.upload_id) do
        {:ok, %{status: :pending} = upload} ->
          :ok = Metadata.upsert_upload(%{upload | status: :complete})
          {:ok, upload.temp_path}

        {:ok, _upload} ->
          {:error, :upload_not_pending}

        :error ->
          {:error, :upload_not_found}
      end

    {:stop, :normal, result, state}
  end

  @impl true
  def handle_call(:abort, _from, state) do
    result =
      case Metadata.get_upload(state.upload_id) do
        {:ok, upload} ->
          :ok = Metadata.upsert_upload(%{upload | status: :aborted})
          _ = File.rm(upload.temp_path)
          :ok

        :error ->
          {:error, :upload_not_found}
      end

    {:stop, :normal, result, state}
  end
end
