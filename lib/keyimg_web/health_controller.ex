defmodule KeyimgWeb.HealthController do
  use Phoenix.Controller, formats: [:json]

  def index(conn, _params) do
    json(conn, %{status: "ok", node: to_string(node())})
  end
end
