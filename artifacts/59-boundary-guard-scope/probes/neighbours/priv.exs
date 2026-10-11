defmodule Priv do
  def pub(x), do: priv(x)          # exported, NO guard
  def pubg(x) when is_integer(x), do: priv(x)   # exported, guard
  defp priv(x) when is_integer(x), do: x + 1    # private, guard
  defp pricom(%{kind: :order} = o), do: o.total   # private, record-ish tag pattern (unused but see below)
  def tagged(o), do: pricom(o)
end
IO.inspect(try do Priv.pub(1.5) rescue e -> e end, label: "pub(1.5) -> private guard runs?")
IO.inspect(try do Priv.pubg(1.5) rescue e -> e end, label: "pubg(1.5) -> exported guard")
IO.inspect(try do Priv.tagged(%{kind: :invoice, total: 9}) rescue e -> e end, label: "tagged(forged kind) -> private tag pattern")
IO.inspect(Priv.tagged(%{kind: :order, total: 9}), label: "tagged(ok)")
# negative control: remove the guard on the private fn -> wrong value goes through silently
defmodule PrivNoGuard do
  def pub(x), do: priv(x)
  defp priv(x), do: x + 1
end
IO.inspect(PrivNoGuard.pub(1.5), label: "control: no guard on defp, pub(1.5)")
# do the compiled BEAM keep the defp guard? count is_integer tests in the beam
{:module, _} = Code.ensure_loaded(Priv)
