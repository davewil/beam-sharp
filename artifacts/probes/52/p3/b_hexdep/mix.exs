defmodule B.MixProject do
  use Mix.Project
  def project, do: [app: :b, version: "0.1.0", elixir: "~> 1.14", deps: [{:req, "~> 0.4"}]]
  def application, do: [extra_applications: [:logger]]
end
