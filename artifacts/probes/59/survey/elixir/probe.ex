defmodule Probe do
  defmodule Order do
    defstruct [:id, :total]
  end

  def pub_cents(o), do: o.total * 100
  defp priv_cents(o), do: o.total * 100
  def via_priv(o), do: priv_cents(o)

  # the idiomatic Elixir guard, written by the author, on exported and private alike
  def pub_inc(n) when is_integer(n), do: n + 1
  defp priv_inc(n) when is_integer(n), do: n + 1
  def run_inc(n), do: priv_inc(n)
  def struct_pub(%Order{} = o), do: o.total
  defp struct_priv(%Order{} = o), do: o.total
  def struct_via(o), do: struct_priv(o)
end
