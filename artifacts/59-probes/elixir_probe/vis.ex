defmodule Vis do
  def pub(n) when is_integer(n), do: :ok
  defp priv(n) when is_integer(n), do: :ok
  def call_priv(n), do: priv(n)
end
