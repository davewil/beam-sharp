defmodule ConsumerU.MixProject do
  use Mix.Project
  def project, do: [app: :consumer_u, version: "0.1.0", elixir: "~> 1.14", deps: []]
  def application, do: [extra_applications: [:logger]]
end
