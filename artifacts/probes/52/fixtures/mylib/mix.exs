defmodule MyLib.MixProject do
  use Mix.Project
  def project, do: [app: :mylib, version: "0.3.1", elixir: "~> 1.15", deps: []]
  def application, do: [extra_applications: []]
end
