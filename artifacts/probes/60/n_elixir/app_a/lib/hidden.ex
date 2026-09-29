defmodule AppA.Hidden do
  @moduledoc false
  @doc false
  def secret(n), do: n * 2
  defp really_private(n), do: n
  def uses_private(n), do: really_private(n)
end
