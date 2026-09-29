defmodule C.MixProject do
  use Mix.Project
  def project, do: [app: :c, version: "0.1.0", elixir: "~> 1.14"]
  def application, do: [extra_applications: [:logger]]
end
