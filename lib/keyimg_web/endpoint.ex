defmodule KeyimgWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :keyimg

  plug Plug.RequestId
  plug KeyimgWeb.Router
end
