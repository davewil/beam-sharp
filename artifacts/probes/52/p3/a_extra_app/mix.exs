defmodule A.MixProject do
  use Mix.Project
  def project, do: [app: :a, version: "0.1.0", elixir: "~> 1.14"]
  def application, do: [extra_applications: [:logger, :nope_app]]
end
