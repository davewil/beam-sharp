defmodule Probe.MixProject do
  use Mix.Project
  def project do
    tracers = if System.get_env("WITH_TRACER") == "1", do: [Probe.Friends], else: []
    [app: :probe, version: "0.1.0", elixir: "~> 1.15", deps: [], elixirc_options: [tracers: tracers]]
  end
  def application, do: []
end

if System.get_env("WITH_TRACER") == "1" do
  Code.eval_file(Path.join(__DIR__, "mix_tracer.exs.txt"))
end
