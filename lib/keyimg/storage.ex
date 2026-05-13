defmodule Keyimg.Storage do
  @spec path_for_image(String.t()) :: String.t()
  def path_for_image(image_id) do
    root = Application.fetch_env!(:keyimg, :storage_root)
    <<a::binary-size(2), b::binary-size(2), _rest::binary>> = String.pad_trailing(image_id, 4, "0")
    Path.join([root, "images", a, b, image_id])
  end

  @spec temp_path_for_upload(String.t()) :: String.t()
  def temp_path_for_upload(upload_id) do
    root = Application.fetch_env!(:keyimg, :storage_root)
    Path.join([root, "uploads", "tmp_#{upload_id}"])
  end

  def ensure_dirs! do
    root = Application.fetch_env!(:keyimg, :storage_root)
    File.mkdir_p!(Path.join(root, "images"))
    File.mkdir_p!(Path.join(root, "uploads"))
  end

  def write_image!(id, binary) do
    path = path_for_image(id)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, binary)
    path
  end

  def read_image(id) do
    File.read(path_for_image(id))
  end

  def delete_image(id) do
    _ = File.rm(path_for_image(id))
    :ok
  end

  def append_to_temp!(path, chunk) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, chunk, [:append, :binary])
  end
end
