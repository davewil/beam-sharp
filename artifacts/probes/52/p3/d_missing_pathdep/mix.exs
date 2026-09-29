defmodule D.MixProject do
  use Mix.Project
  def project, do: [app: :d, version: "0.1.0", elixir: "~> 1.14", deps: [{:gone, path: "../nowhere_at_all"}]]
  def application, do: [extra_applications: [:logger]]
end
