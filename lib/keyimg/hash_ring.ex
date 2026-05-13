defmodule Keyimg.HashRing do
  @max_hash 4_294_967_291

  @type ring_point :: {non_neg_integer(), node()}

  @spec build([node()], pos_integer()) :: [ring_point()]
  def build(nodes, virtual_nodes) when virtual_nodes > 0 do
    nodes
    |> Enum.uniq()
    |> Enum.flat_map(fn n ->
      0..(virtual_nodes - 1)
      |> Enum.map(fn v -> {hash({n, v}), n} end)
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  @spec replicas([ring_point()], term(), pos_integer()) :: [node()]
  def replicas([], _key, _count), do: []

  def replicas(ring, key, count) when count > 0 do
    start_hash = hash(key)
    {before_points, after_points} = Enum.split_while(ring, fn {h, _} -> h < start_hash end)
    traversal = after_points ++ before_points

    traversal
    |> Enum.reduce_while({MapSet.new(), []}, fn {_h, n}, {seen, acc} ->
      if MapSet.member?(seen, n) do
        {:cont, {seen, acc}}
      else
        next_seen = MapSet.put(seen, n)
        next_acc = [n | acc]

        if length(next_acc) >= count do
          {:halt, {next_seen, next_acc}}
        else
          {:cont, {next_seen, next_acc}}
        end
      end
    end)
    |> elem(1)
    |> Enum.reverse()
  end

  @spec hash(term()) :: non_neg_integer()
  def hash(term) do
    :erlang.phash2(term, @max_hash)
  end
end
