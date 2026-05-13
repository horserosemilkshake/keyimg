defmodule KeyimgWeb.UploadController do
  use Phoenix.Controller, formats: [:json]

  alias Keyimg.Service

  def create(conn, _params) do
    ttl_opts =
      case read_json_body(conn) do
        {:ok, %{"ttl_seconds" => ttl}} when is_integer(ttl) -> [ttl_seconds: ttl]
        _ -> []
      end

    case Service.create_upload(ttl_opts) do
      {:ok, upload_id} -> json(conn, %{upload_id: upload_id})
    end
  end

  def append(conn, %{"id" => upload_id}) do
    with {:ok, body, _conn} <- read_full_body(conn),
         :ok <- Service.append_upload(upload_id, body) do
      json(conn, %{status: "ok"})
    else
      {:error, :upload_not_found} -> json_error(conn, 404, :upload_not_found)
      {:error, reason} -> json_error(conn, 400, reason)
      _ -> json_error(conn, 400, :invalid_body)
    end
  end

  def complete(conn, %{"id" => upload_id}) do
    {content_type, opts} =
      case read_json_body(conn) do
        {:ok, payload} ->
          ct = Map.get(payload, "content_type", "application/octet-stream")

          ttl_opts =
            case Map.get(payload, "ttl_seconds") do
              ttl when is_integer(ttl) -> [ttl_seconds: ttl]
              _ -> []
            end

          {ct, ttl_opts}

        _ ->
          {"application/octet-stream", []}
      end

    case Service.complete_upload(upload_id, content_type, opts) do
      {:ok, image_id} -> json(conn, %{id: image_id})
      {:error, :upload_not_found} -> json_error(conn, 404, :upload_not_found)
      {:error, reason} -> json_error(conn, 400, reason)
    end
  end

  def abort(conn, %{"id" => upload_id}) do
    case Service.abort_upload(upload_id) do
      :ok -> json(conn, %{status: "aborted"})
      {:error, :upload_not_found} -> json_error(conn, 404, :upload_not_found)
      {:error, reason} -> json_error(conn, 400, reason)
    end
  end

  defp read_full_body(conn, acc \\ "") do
    case Plug.Conn.read_body(conn) do
      {:ok, chunk, conn} -> {:ok, acc <> chunk, conn}
      {:more, chunk, conn} -> read_full_body(conn, acc <> chunk)
      {:error, reason} -> {:error, reason}
    end
  end

  defp read_json_body(conn) do
    with {:ok, body, _conn} <- read_full_body(conn),
         {:ok, payload} <- Jason.decode(body) do
      {:ok, payload}
    end
  end

  defp json_error(conn, status, reason) do
    conn
    |> put_status(status)
    |> json(%{error: to_string(reason)})
  end
end
