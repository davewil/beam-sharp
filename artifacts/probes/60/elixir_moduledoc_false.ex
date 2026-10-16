defmodule P60.Internal.Helper do
  @moduledoc false
  @doc false
  def secret, do: 42
end
defmodule P60.Public do
  def api, do: P60.Internal.Helper.secret()
end
defmodule P60.Outsider do
  # a module outside the P60 "package" names the hidden one
  def poke, do: P60.Internal.Helper.secret()
end
