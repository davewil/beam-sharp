defmodule Scope do
  defmodule Order do
    defstruct [:id, :total]
  end

  # def vs defp, identical heads: a struct pattern (tag test) and an is_integer guard
  def pub_rec(%Order{} = o), do: o.total
  defp priv_rec(%Order{} = o), do: o.total

  def pub_int(n) when is_integer(n), do: n * 2
  defp priv_int(n) when is_integer(n), do: n * 2

  # callers: one passes list elements (unproven), one a proven value
  def run(xs), do: Enum.map(xs, &priv_rec/1) ++ Enum.map(xs, &priv_int/1)
  defp only_proven(n) when is_integer(n), do: n * 2
  def run_only(n) when is_integer(n), do: only_proven(n)
  def run_proven(n) when is_integer(n), do: priv_int(n)
end
