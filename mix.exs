defmodule Keyimg.MixProject do
  use Mix.Project

  def project do
    [
      app: :keyimg,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto, :inets, :ssl],
      mod: {Keyimg.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:phoenix, "~> 1.7"},
      {:phoenix_pubsub, "~> 2.1"},
      {:plug_cowboy, "~> 2.7"},
      {:libcluster, "~> 3.5"},
      {:horde, "~> 0.9"},
      {:meck, "~> 0.9", only: :test}
    ]
  end
end
