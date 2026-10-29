defmodule App.MixProject do
  use Mix.Project
  def project, do: [app: :app, version: "0.1.0", deps: deps()]
  def application, do: [extra_applications: String.split(System.get_env("EXTRA") || "logger", ",") |> Enum.map(&String.to_atom/1)]
  defp deps, do: (case System.get_env("WITH_DEP") do "1" -> [{:widget_core, path: "../widget"}]; _ -> [] end)
end
