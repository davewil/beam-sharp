defmodule WarnProbe do
  defp inc(n) when is_integer(n), do: n + 1
  def bad(), do: inc(:a)            # private callee, wrong kind, statically visible
  def okpub(x), do: inc(x)
  def pub_inc(n) when is_integer(n), do: n + 1
  def bad_pub(), do: __MODULE__.pub_inc(:a)
end
