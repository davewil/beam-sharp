defmodule AppB.MixProject do
  use Mix.Project
  def project, do: [app: :app_b, version: "0.1.0", elixir: "~> 1.14", deps: [{:app_a, path: "../app_a"}]]
  def application, do: []
end
