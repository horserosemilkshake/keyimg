defmodule Keyimg.HashRingTest do
  use ExUnit.Case, async: true

  alias Keyimg.HashRing

  test "replica selection is deterministic and unique" do
    nodes = [:"n1@host", :"n2@host", :"n3@host", :"n4@host"]
    ring = HashRing.build(nodes, 64)

    key = "same-key"
    selected_a = HashRing.replicas(ring, key, 3)
    selected_b = HashRing.replicas(ring, key, 3)

    assert selected_a == selected_b
    assert length(selected_a) == 3
    assert Enum.uniq(selected_a) == selected_a
  end

  test "minimal movement when one node leaves" do
    full_nodes = [:"n1@host", :"n2@host", :"n3@host", :"n4@host"]
    fewer_nodes = [:"n1@host", :"n2@host", :"n3@host"]

    full_ring = HashRing.build(full_nodes, 128)
    fewer_ring = HashRing.build(fewer_nodes, 128)

    keys = Enum.map(1..1_000, &"k-#{&1}")

    changed =
      keys
      |> Enum.count(fn key ->
        HashRing.replicas(full_ring, key, 1) != HashRing.replicas(fewer_ring, key, 1)
      end)

    assert changed < 400
  end
end
