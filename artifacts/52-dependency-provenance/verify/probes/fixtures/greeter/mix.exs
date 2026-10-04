defmodule Greeter.MixProject do
  use Mix.Project
  def project, do: [app: :greeter, version: "0.3.1", elixir: "~> 1.14", deps: [], build_path: System.get_env("GREETER_BUILD", "_build")]
  def application, do: [extra_applications: [:logger]]
end
