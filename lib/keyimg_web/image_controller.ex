defmodule KeyimgWeb.ImageController do
  use Phoenix.Controller, formats: [:json]

  alias Keyimg.Service

  def create(conn, _params) do
    content_type =
      conn
      |> get_req_header("content-type")
      |> List.first()
      |> normalize_content_type()

    with {:ok, body, _conn} <- read_full_body(conn),
         {:ok, id} <- Service.put_image(body, content_type, ttl_options(conn)) do
      json(conn, %{id: id})
    else
      {:error, :too_large} -> json_error(conn, 413, :too_large)
      {:error, :invalid_content_type} -> json_error(conn, 400, :invalid_content_type)
      {:error, reason} -> json_error(conn, 400, reason)
      _ -> json_error(conn, 400, :invalid_body)
    end
  end

  def show(conn, %{"id" => id}) do
    case Service.get_image(id) do
      {:ok, image} ->
        conn
        |> put_resp_content_type(image.content_type)
        |> send_resp(200, image.body)

      {:error, :not_found} ->
        json_error(conn, 404, :not_found)

      {:error, :expired} ->
        json_error(conn, 410, :expired)

      {:error, reason} ->
        json_error(conn, 500, reason)
    end
  end

  defp read_full_body(conn, acc \\ "") do
    case Plug.Conn.read_body(conn) do
      {:ok, chunk, conn} -> {:ok, acc <> chunk, conn}
      {:more, chunk, conn} -> read_full_body(conn, acc <> chunk)
      {:error, reason} -> {:error, reason}
    end
  end

  defp ttl_options(conn) do
    case get_req_header(conn, "x-ttl-seconds") |> List.first() do
      nil -> []
      ttl -> [ttl_seconds: String.to_integer(ttl)]
    end
  rescue
    _ -> []
  end

  defp normalize_content_type(nil), do: "application/octet-stream"

  defp normalize_content_type(value) do
    value
    |> String.split(";", parts: 2)
    |> hd()
    |> String.trim()
  end

  defp json_error(conn, status, reason) do
    conn
    |> put_status(status)
    |> json(%{error: to_string(reason)})
  end
end
