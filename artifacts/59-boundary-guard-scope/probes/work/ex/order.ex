defmodule Order do
  @enforce_keys [:total]
  defstruct [:total, status: :draft]

  # exported, struct pattern in the head
  def e(%Order{} = o), do: p(o)
  # private, the author wrote the SAME pattern
  defp p(%Order{total: t}), do: t
  # nested: exported takes a wrapper and hands the field on
  def w(%{order: o}), do: p(o)
  # escape: private function returned as a value
  def esc, do: &p/1

  def r(n) when is_integer(n), do: q(n)
  defp q(n) when is_integer(n), do: n * 2
end
