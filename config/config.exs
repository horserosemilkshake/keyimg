import Config

cluster_hosts =
  System.get_env("KEYIMG_CLUSTER_NODES", "")
  |> String.split(",", trim: true)
  |> Enum.map(&String.to_atom/1)

config :libcluster,
  topologies: [
    keyimg: [
      strategy: Cluster.Strategy.Epmd,
      config: [hosts: cluster_hosts]
    ]
  ]

config :keyimg,
  storage_root: "/tmp/keyimg",
  max_image_size: 10 * 1024 * 1024,
  default_ttl_seconds: 24 * 60 * 60,
  body_cache_enabled: true,
  replica_count: 3,
  hash_ring_vnodes: 128,
  rpc_timeout_ms: 2_000,
  crdt_entry_ttl_ms: 5 * 60_000,
  crdt_gossip_interval_ms: 1_000,
  cleanup_interval_ms: 60_000,
  rate_limit_capacity: 100,
  rate_limit_window_ms: 60_000,
  mnesia_dir: "./.mnesia"

config :keyimg, KeyimgWeb.Endpoint,
  url: [host: "127.0.0.1"],
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT", "4000"))],
  secret_key_base: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
  server: true,
  render_errors: [formats: [json: KeyimgWeb.ErrorJSON], layout: false],
  pubsub_server: Keyimg.PubSub,
  live_view: [signing_salt: "keyimgsalt"]
