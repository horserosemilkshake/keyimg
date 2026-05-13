import Config

base_tmp = Path.join(System.tmp_dir!(), "keyimg_test")

config :keyimg,
  storage_root: Path.join(base_tmp, "storage"),
  max_image_size: 2 * 1024 * 1024,
  default_ttl_seconds: 2,
  body_cache_enabled: true,
  replica_count: 2,
  hash_ring_vnodes: 32,
  rpc_timeout_ms: 1_000,
  crdt_entry_ttl_ms: 30_000,
  crdt_gossip_interval_ms: 200,
  cleanup_interval_ms: 5_000,
  rate_limit_capacity: 1_000,
  rate_limit_window_ms: 60_000,
  mnesia_dir: Path.join(base_tmp, "mnesia")

config :libcluster,
  topologies: [
    keyimg: [
      strategy: Cluster.Strategy.Epmd,
      config: [hosts: []]
    ]
  ]

config :keyimg, KeyimgWeb.Endpoint,
  server: false,
  http: [ip: {127, 0, 0, 1}, port: 4002]

config :keyimg, KeyimgWeb.Endpoint,
  adapter: Phoenix.Endpoint.Cowboy2Adapter
