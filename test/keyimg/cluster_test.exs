defmodule Keyimg.ClusterTest do
  use ExUnit.Case, async: false

  alias Keyimg.Cluster

  test "cluster returns bounded replica set" do
    replica_count = Application.fetch_env!(:keyimg, :replica_count)
    replicas = Cluster.replicas_for("abc")

    assert length(replicas) >= 1
    assert length(replicas) <= replica_count
    assert Enum.uniq(replicas) == replicas
  end
end
