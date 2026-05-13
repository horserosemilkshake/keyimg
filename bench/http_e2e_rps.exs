Logger.configure(level: :warning)

Application.put_env(:keyimg, KeyimgWeb.Endpoint,
  Application.get_env(:keyimg, KeyimgWeb.Endpoint, [])
  |> Keyword.put(:server, true)
)

Mix.Task.run("app.start")

:inets.start()
:ssl.start()

base_url = System.get_env("BASE_URL", "http://127.0.0.1:4000")
duration_s = System.get_env("DURATION") |> case do
  nil -> 5
  value -> String.to_integer(value)
end

concurrency = System.get_env("CONCURRENCY") |> case do
  nil -> System.schedulers_online() * 8
  value -> String.to_integer(value)
end

payload_size = System.get_env("PAYLOAD_BYTES") |> case do
  nil -> 256
  value -> String.to_integer(value)
end

payload = :binary.copy(<<120>>, payload_size)
post_url = to_charlist(base_url <> "/images")

headers = [{~c"content-type", ~c"image/png"}]

{:ok, {{_, 200, _}, _headers, body}} =
  :httpc.request(:post, {post_url, headers, ~c"image/png", payload}, [], body_format: :binary)

%{"id" => image_id} = Jason.decode!(body)

get_url = to_charlist(base_url <> "/images/" <> image_id)
end_time = System.monotonic_time(:millisecond) + duration_s * 1000
counter = :atomics.new(1, signed: false)

workers =
  for _ <- 1..concurrency do
    Task.async(fn ->
      run = fn run_fun ->
        if System.monotonic_time(:millisecond) < end_time do
          case :httpc.request(:get, {get_url, []}, [], body_format: :binary) do
            {:ok, {{_, 200, _}, _h, _resp_body}} ->
              :atomics.add(counter, 1, 1)
              run_fun.(run_fun)

            _ ->
              :ok
          end
        end
      end

      run.(run)
    end)
  end

Enum.each(workers, &Task.await(&1, duration_s * 2000))

total = :atomics.get(counter, 1)
rps = total / duration_s

IO.puts("http e2e benchmark")
IO.puts("base_url=#{base_url}")
IO.puts("duration_s=#{duration_s}")
IO.puts("concurrency=#{concurrency}")
IO.puts("payload_bytes=#{payload_size}")
IO.puts("total_ops=#{total}")
IO.puts("rps=#{Float.round(rps, 2)}")
