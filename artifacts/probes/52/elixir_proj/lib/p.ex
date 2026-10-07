defmodule P do
  def a, do: NoSuchLib.Thing.frob(1)
  def b, do: :crypto.strong_rand_bytes(1)
  def c, do: :no_such_erl_mod.frob(1)
end
