defmodule Lib.Internal do
  @moduledoc false
  @doc false
  def secret, do: 42
end
defmodule App do
  def go, do: Lib.Internal.secret()
end
IO.inspect(App.go(), label: "elixir: @moduledoc false module called from anywhere")
