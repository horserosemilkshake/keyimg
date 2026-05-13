defmodule KeyimgWeb.Router do
  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", KeyimgWeb do
    pipe_through :api

    get "/health", HealthController, :index
    post "/images", ImageController, :create
    get "/images/:id", ImageController, :show

    post "/uploads", UploadController, :create
    put "/uploads/:id", UploadController, :append
    post "/uploads/:id/complete", UploadController, :complete
    delete "/uploads/:id", UploadController, :abort
  end
end
