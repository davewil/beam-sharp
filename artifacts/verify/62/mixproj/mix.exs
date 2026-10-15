defmodule Mixproj.MixProject do
  use Mix.Project

  def project do
    [
      app: :mixproj,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: [{:shop_b, path: "../shop_b", compile: "mkdir -p ../mixproj/_build/dev/lib/shop_b/ebin && cp ebin/* ../mixproj/_build/dev/lib/shop_b/ebin/"}]
    ]
  end

  def application, do: [extra_applications: [:logger]]
end
