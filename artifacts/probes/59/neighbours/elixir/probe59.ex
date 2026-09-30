# Probe 59: what does Elixir emit for typed-looking heads on def vs defp?
defmodule Ord do
  defstruct [:id, :total]
end

defmodule Probe59 do
  @spec spec_only(%Ord{}) :: integer
  def spec_only(o), do: o.total          # @spec is documentation: no guard

  def pub_struct(%Ord{} = o), do: o.total          # struct pattern: a runtime check
  defp priv_struct(%Ord{} = o), do: o.total        # same pattern on defp: also a check

  def pub_guard(o) when is_struct(o, Ord), do: o.total
  defp priv_guard(o) when is_struct(o, Ord), do: o.total

  def pub_int(n) when is_integer(n), do: n + 1
  defp priv_int(n) when is_integer(n), do: n + 1

  def use_all(o, n), do: priv_struct(o) + priv_guard(o) + priv_int(n)
end
