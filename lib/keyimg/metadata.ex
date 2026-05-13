defmodule Keyimg.Metadata do
  use GenServer

  @images_table :keyimg_images
  @uploads_table :keyimg_uploads
  @hash_index_table :keyimg_hash_index

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def upsert_image(image) do
    :ets.insert(@images_table, {image.id, image})
    :ets.insert(@hash_index_table, {image.content_hash, image.id})
    {:ok, :ok}
  end

  def get_image(id) do
    case :ets.lookup(@images_table, id) do
      [{^id, image}] -> {:ok, image}
      [] -> :error
    end
  end

  def get_image_id_by_hash(content_hash) do
    case :ets.lookup(@hash_index_table, content_hash) do
      [{^content_hash, image_id}] -> {:ok, image_id}
      [] -> :error
    end
  end

  def delete_image(id, content_hash) do
    :ets.delete(@images_table, id)
    :ets.delete(@hash_index_table, content_hash)
    {:ok, :ok}
  end

  def all_images do
    :ets.tab2list(@images_table)
    |> Enum.map(fn {_id, image} -> image end)
  end

  def upsert_upload(upload) do
    :ets.insert(@uploads_table, {upload.upload_id, upload})
    :ok
  end

  def get_upload(upload_id) do
    case :ets.lookup(@uploads_table, upload_id) do
      [{^upload_id, upload}] -> {:ok, upload}
      [] -> :error
    end
  end

  def delete_upload(upload_id) do
    :ets.delete(@uploads_table, upload_id)
    :ok
  end

  def all_uploads do
    :ets.tab2list(@uploads_table)
    |> Enum.map(fn {_id, upload} -> upload end)
  end

  def clear_all do
    :ets.delete_all_objects(@images_table)
    :ets.delete_all_objects(@uploads_table)
    :ets.delete_all_objects(@hash_index_table)
    :ok
  end

  @impl true
  def init(_) do
    ensure_table(@images_table)
    ensure_table(@uploads_table)
    ensure_table(@hash_index_table)
    {:ok, %{}}
  end

  defp ensure_table(name) do
    case :ets.whereis(name) do
      :undefined -> :ets.new(name, [:named_table, :public, :set, read_concurrency: true, write_concurrency: true])
      _tid -> :ok
    end
  end
end
