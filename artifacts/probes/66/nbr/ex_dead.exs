defmodule P do
  defstruct [:id]
  def f(_), do: 1
  def f(%P{}), do: 2
  def g(c) when is_struct(c, P) or is_struct(c, Q), do: :ab
end
defmodule Q, do: defstruct([:id])
