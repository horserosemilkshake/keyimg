defmodule Keyimg.Application do
  use Application

  @impl true
  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies, [])

    children = [
      {Phoenix.PubSub, name: Keyimg.PubSub},
      {Cluster.Supervisor, [topologies, [name: Keyimg.ClusterSupervisor]]},
      {Horde.Registry, [name: Keyimg.HordeRegistry, keys: :unique, members: []]},
      {Horde.DynamicSupervisor, [name: Keyimg.HordeSupervisor, strategy: :one_for_one, members: []]},
      Keyimg.HordeCoordinator,
      Keyimg.UploadCoordinator,
      Keyimg.CrdtGCounter,
      Keyimg.Cluster,
      Keyimg.Metadata,
      Keyimg.Cache,
      Keyimg.RateLimiter,
      {Keyimg.CleanupWorker, []},
      KeyimgWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Keyimg.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    KeyimgWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
