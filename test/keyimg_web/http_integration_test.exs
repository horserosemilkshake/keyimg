defmodule KeyimgWeb.HttpIntegrationTest do
  use ExUnit.Case, async: false

  import Plug.Test
  import Plug.Conn

  alias Keyimg.{Cache, Metadata, Service, Storage}
  alias KeyimgWeb.Endpoint

  defmodule RpcFake do
    def set_handler(fun) when is_function(fun, 5) do
      :persistent_term.put({__MODULE__, :handler}, fun)
      :ok
    end

    def clear_handler do
      :persistent_term.erase({__MODULE__, :handler})
      :ok
    end

    def call(node, module, fun, args, timeout) do
      case :persistent_term.get({__MODULE__, :handler}, nil) do
        nil -> {:badrpc, :nodedown}
        handler -> handler.(node, module, fun, args, timeout)
      end
    end
  end

  setup do
    :ok = Metadata.clear_all()
    :ok = Cache.clear()
    File.rm_rf!(Application.fetch_env!(:keyimg, :storage_root))
    Storage.ensure_dirs!()
    Application.put_env(:keyimg, :rpc_module, :rpc)
    RpcFake.clear_handler()
    :ok
  end

  test "POST/GET images over HTTP" do
    conn =
      conn(:post, "/images", "hello-http")
      |> put_req_header("content-type", "image/png")
      |> Endpoint.call([])

    assert conn.status == 200
    %{"id" => id} = Jason.decode!(conn.resp_body)

    conn = conn(:get, "/images/" <> id) |> Endpoint.call([])
    assert conn.status == 200
    assert conn.resp_body == "hello-http"
    assert List.first(Plug.Conn.get_resp_header(conn, "content-type")) =~ "image/png"
  end

  test "resumable upload over HTTP" do
    create_conn =
      conn(:post, "/uploads", ~s({"ttl_seconds": 30}))
      |> put_req_header("content-type", "application/json")
      |> Endpoint.call([])

    assert create_conn.status == 200
    %{"upload_id" => upload_id} = Jason.decode!(create_conn.resp_body)

    append1 = conn(:put, "/uploads/" <> upload_id, "partA") |> Endpoint.call([])
    append2 = conn(:put, "/uploads/" <> upload_id, "partB") |> Endpoint.call([])

    assert append1.status == 200
    assert append2.status == 200

    complete_conn =
      conn(:post, "/uploads/" <> upload_id <> "/complete", ~s({"content_type":"image/gif"}))
      |> put_req_header("content-type", "application/json")
      |> Endpoint.call([])

    assert complete_conn.status == 200
    %{"id" => image_id} = Jason.decode!(complete_conn.resp_body)

    get_conn = conn(:get, "/images/" <> image_id) |> Endpoint.call([])
    assert get_conn.status == 200
    assert get_conn.resp_body == "partApartB"
  end

  test "cross-node dedup through remote hash lookup path" do
    hash = :crypto.hash(:sha256, "remote-dedup") |> Base.encode16(case: :lower)

    remote_image = %{
      id: "REMOTE123",
      content_hash: hash,
      storage_nodes: [node()],
      size: byte_size("remote-dedup"),
      content_type: "image/png",
      created_at: System.system_time(:second),
      expires_at: System.system_time(:second) + 3600
    }

    :meck.new(Keyimg.Cluster, [:passthrough])
    :meck.expect(Keyimg.Cluster, :nodes, fn -> [node(), :remote@node] end)

    Application.put_env(:keyimg, :rpc_module, RpcFake)

    RpcFake.set_handler(fn
      :remote@node, Keyimg.Service, :get_image_id_by_hash_remote, [^hash], _timeout ->
        {:ok, "REMOTE123"}

      :remote@node, Keyimg.Service, :get_image_meta_remote, ["REMOTE123"], _timeout ->
        {:ok, remote_image}

      _n, _m, _f, _a, _t ->
        {:badrpc, :nodedown}
    end)

    conn =
      conn(:post, "/images", "remote-dedup")
      |> put_req_header("content-type", "image/png")
      |> Endpoint.call([])

    assert conn.status == 200
    assert Jason.decode!(conn.resp_body) == %{"id" => "REMOTE123"}

    :meck.unload(Keyimg.Cluster)
    Application.put_env(:keyimg, :rpc_module, :rpc)
    RpcFake.clear_handler()
  end

  test "remote read fallback path over HTTP" do
    image = %{
      id: "REMOTEFALL",
      content_hash: "h",
      storage_nodes: [:remote@node],
      size: 12,
      content_type: "image/png",
      created_at: System.system_time(:second),
      expires_at: System.system_time(:second) + 3600
    }

    {:ok, :ok} = Service.put_remote_image_meta(image)

    Application.put_env(:keyimg, :rpc_module, RpcFake)

    RpcFake.set_handler(fn
      :remote@node, Keyimg.Service, :get_image_body_remote, ["REMOTEFALL"], _timeout ->
        {:ok, "remote-bytes"}

      _n, _m, _f, _a, _t ->
        {:badrpc, :nodedown}
    end)

    conn = conn(:get, "/images/REMOTEFALL") |> Endpoint.call([])

    assert conn.status == 200
    assert conn.resp_body == "remote-bytes"

    Application.put_env(:keyimg, :rpc_module, :rpc)
    RpcFake.clear_handler()
  end
end
