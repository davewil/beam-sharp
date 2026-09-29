defmodule E.MixProject do
  use Mix.Project
  def project, do: [app: :e, version: "0.1.0", elixir: "~> 1.14", deps: [{:dd, path: "../d_dep"}]]
  def application, do: [extra_applications: [:logger]]
end
