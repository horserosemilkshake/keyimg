defmodule Keyimg.Service do
  alias Keyimg.Cache
  alias Keyimg.Cluster
  alias Keyimg.Metadata
  alias Keyimg.Storage
  alias Keyimg.UploadCoordinator

  @type image_result ::
          {:ok, %{id: String.t(), body: binary(), content_type: String.t(), size: non_neg_integer()}}
          | {:error, :not_found | :expired}

  @spec put_image(binary(), String.t(), keyword()) :: {:ok, String.t()} | {:error, atom()}
  def put_image(binary, content_type, opts \\ []) when is_binary(binary) and is_binary(content_type) do
    Storage.ensure_dirs!()

    with :ok <- validate_size(binary),
         :ok <- validate_content_type(content_type) do
      hash = :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)

      case find_existing_by_hash(hash) do
        {:ok, existing_id} ->
          {:ok, existing_id}

        :error ->
          ttl_seconds = Keyword.get(opts, :ttl_seconds, Application.fetch_env!(:keyimg, :default_ttl_seconds))
          now = now_s()
          expires_at = now + ttl_seconds
          id = random_id()

          storage_nodes = Cluster.replicas_for(hash)

          image = %{
            id: id,
            content_hash: hash,
            storage_nodes: storage_nodes,
            size: byte_size(binary),
            content_type: content_type,
            created_at: now,
            expires_at: expires_at
          }

          if node() in storage_nodes do
            put_local_image(image, binary)
          end

          replicate_to_nodes(image, binary)
          {:ok, id}
      end
    end
  end

  @spec get_image(String.t()) :: image_result()
  def get_image(id) do
    with {:ok, image} <- find_image(id),
         :ok <- ensure_not_expired(image),
         {:ok, body} <- fetch_body_from_nodes(id, image.storage_nodes) do
      {:ok, %{id: id, body: body, content_type: image.content_type, size: image.size}}
    else
      :error -> {:error, :not_found}
      {:error, :enoent} -> {:error, :not_found}
      {:error, :expired} -> {:error, :expired}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec create_upload(keyword()) :: {:ok, String.t()}
  def create_upload(opts \\ []) do
    Storage.ensure_dirs!()

    ttl_seconds = Keyword.get(opts, :ttl_seconds, Application.fetch_env!(:keyimg, :default_ttl_seconds))
    now = now_s()
    expires_at = now + ttl_seconds
    upload_id = random_id()
    temp_path = Storage.temp_path_for_upload(upload_id)

    upload = %{
      upload_id: upload_id,
      status: :pending,
      temp_path: temp_path,
      received_bytes: 0,
      hash_state: nil,
      created_at: now,
      expires_at: expires_at
    }

    :ok = Metadata.upsert_upload(upload)
    case UploadCoordinator.ensure_started(upload_id) do
      :ok -> :ok
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      other -> raise "failed to start upload coordinator: #{inspect(other)}"
    end
    {:ok, upload_id}
  end

  @spec append_upload(String.t(), binary()) :: :ok | {:error, atom()}
  def append_upload(upload_id, chunk) when is_binary(chunk) do
    with {:ok, upload} <- Metadata.get_upload(upload_id),
         :ok <- ensure_upload_pending(upload),
         :ok <- validate_received_size(upload.received_bytes + byte_size(chunk)),
         :ok <- UploadCoordinator.append(upload_id, chunk) do
      :ok
    else
      :error -> {:error, :upload_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec complete_upload(String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, atom()}
  def complete_upload(upload_id, content_type, opts \\ []) do
    with {:ok, temp_path} <- UploadCoordinator.complete(upload_id),
         {:ok, body} <- File.read(temp_path),
         {:ok, id} <- put_image(body, content_type, opts) do
      _ = File.rm(temp_path)
      {:ok, id}
    else
      :error -> {:error, :upload_not_found}
      {:error, :enoent} -> {:error, :upload_missing_tempfile}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec abort_upload(String.t()) :: :ok | {:error, atom()}
  def abort_upload(upload_id) do
    UploadCoordinator.abort(upload_id)
  end

  # test-only helpers for HTTP multi-node behavior validation
  def put_remote_image_meta(image), do: Metadata.upsert_image(image)
  def set_remote_hash(content_hash, image_id), do: :ets.insert(:keyimg_hash_index, {content_hash, image_id})

  @spec cleanup_expired() :: :ok
  def cleanup_expired do
    now = now_s()

    Metadata.all_images()
    |> Enum.filter(&(&1.expires_at <= now))
    |> Enum.each(fn image ->
      _ = Metadata.delete_image(image.id, image.content_hash)
      _ = Storage.delete_image(image.id)
      Cache.delete({:image, image.id})
      Cache.delete({:hash, image.content_hash})
      Cache.delete({:body, image.id})
    end)

    Metadata.all_uploads()
    |> Enum.filter(&(&1.expires_at <= now))
    |> Enum.each(fn upload ->
      :ok = Metadata.delete_upload(upload.upload_id)
      _ = File.rm(upload.temp_path)
    end)

    :ok
  end

  def get_image_meta_remote(id) do
    Metadata.get_image(id)
  end

  def get_image_body_remote(id) do
    fetch_body(id)
  end

  def get_image_id_by_hash_remote(hash) do
    Metadata.get_image_id_by_hash(hash)
  end

  defp find_existing_by_hash(hash) do
    case Cache.get({:hash, hash}) do
      {:ok, id} -> {:ok, id}
      :error ->
        case Metadata.get_image_id_by_hash(hash) do
          {:ok, id} ->
            Cache.put({:hash, hash}, id)
            {:ok, id}

          :error ->
            find_existing_by_hash_remote(hash)
        end
    end
  end

  defp find_existing_by_hash_remote(hash) do
    timeout = Application.fetch_env!(:keyimg, :rpc_timeout_ms)
    rpc = rpc_module()

    Cluster.nodes()
    |> Enum.reject(&(&1 == node()))
    |> Enum.reduce_while(:error, fn n, _acc ->
      case rpc.call(n, __MODULE__, :get_image_id_by_hash_remote, [hash], timeout) do
        {:ok, id} -> {:halt, {:ok, id}}
        _ -> {:cont, :error}
      end
    end)
  end

  defp find_image(id) do
    case fetch_image(id) do
      {:ok, image} -> {:ok, image}
      :error -> find_image_remote(id)
    end
  end

  defp find_image_remote(id) do
    timeout = Application.fetch_env!(:keyimg, :rpc_timeout_ms)
    rpc = rpc_module()

    Cluster.nodes()
    |> Enum.reject(&(&1 == node()))
    |> Enum.reduce_while(:error, fn n, _acc ->
      case rpc.call(n, __MODULE__, :get_image_meta_remote, [id], timeout) do
        {:ok, image} ->
          Cache.put({:image, id}, image)
          Cache.put({:hash, image.content_hash}, id)
          {:halt, {:ok, image}}

        _ ->
          {:cont, :error}
      end
    end)
  end

  defp fetch_image(id) do
    case Cache.get({:image, id}) do
      {:ok, image} -> {:ok, image}
      :error ->
        case Metadata.get_image(id) do
          {:ok, image} ->
            Cache.put({:image, id}, image)
            Cache.put({:hash, image.content_hash}, id)
            {:ok, image}

          :error ->
            :error
        end
    end
  end

  defp ensure_not_expired(image) do
    if image.expires_at > now_s(), do: :ok, else: {:error, :expired}
  end

  defp fetch_body(id) do
    case Cache.get({:body, id}) do
      {:ok, body} -> {:ok, body}
      :error ->
        case Storage.read_image(id) do
          {:ok, body} = result ->
            maybe_cache_body(id, body)
            result

          error ->
            error
        end
    end
  end

  defp fetch_body_from_nodes(id, storage_nodes) do
    local_first =
      case storage_nodes do
        nil -> [node()]
        [] -> [node()]
        nodes -> ([node()] ++ nodes) |> Enum.uniq()
      end

    timeout = Application.fetch_env!(:keyimg, :rpc_timeout_ms)
    rpc = rpc_module()

    local_first
    |> Enum.reduce_while(:error, fn n, _acc ->
      result =
        if n == node() do
          fetch_body(id)
        else
          rpc.call(n, __MODULE__, :get_image_body_remote, [id], timeout)
        end

      case result do
        {:ok, body} ->
          maybe_cache_body(id, body)
          {:halt, {:ok, body}}

        _ ->
          {:cont, :error}
      end
    end)
  end

  defp ensure_upload_pending(upload) do
    if upload.status == :pending, do: :ok, else: {:error, :upload_not_pending}
  end

  defp validate_size(binary) do
    validate_received_size(byte_size(binary))
  end

  defp validate_received_size(size) do
    max_size = Application.fetch_env!(:keyimg, :max_image_size)
    if size <= max_size, do: :ok, else: {:error, :too_large}
  end

  defp validate_content_type(content_type) do
    if String.contains?(content_type, "/"), do: :ok, else: {:error, :invalid_content_type}
  end

  defp random_id do
    9
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 9)
  end

  defp now_s do
    System.system_time(:second)
  end

  defp maybe_cache_body(id, body) do
    if Application.fetch_env!(:keyimg, :body_cache_enabled) do
      Cache.put({:body, id}, body)
    end
  end

  defp put_local_image(image, body) do
    _path = Storage.write_image!(image.id, body)
    {:ok, :ok} = Metadata.upsert_image(image)
    Cache.put({:image, image.id}, image)
    Cache.put({:hash, image.content_hash}, image.id)
    maybe_cache_body(image.id, body)
    :ok
  end

  defp replicate_to_nodes(image, body) do
    timeout = Application.fetch_env!(:keyimg, :rpc_timeout_ms)
    rpc = rpc_module()

    image.storage_nodes
    |> Enum.reject(&(&1 == node()))
    |> Enum.each(fn n ->
      Task.start(fn ->
        _ = rpc.call(n, __MODULE__, :replicate_from_peer, [image, body], timeout)
      end)
    end)
  end

  defp rpc_module do
    Application.get_env(:keyimg, :rpc_module, :rpc)
  end

  # Cluster replication endpoint used by owner nodes.
  def replicate_from_peer(image, body) do
    put_local_image(image, body)
    :ok
  end
end
