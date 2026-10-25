# P4: Elixir @moduledoc false / @doc false: documentation-only, does the compiler refuse a caller?
defmodule Shop.Internal.Tax do
  @moduledoc false
  def recompute(n), do: div(n, 5)
end
defmodule Shop.Public do
  @moduledoc "public"
  @doc false
  def helper(n), do: n
  def gross(n), do: n + Shop.Internal.Tax.recompute(n)
end
defmodule Outsider do
  def probe(n), do: {Shop.Internal.Tax.recompute(n), Shop.Public.helper(n)}
end
IO.inspect(Outsider.probe(50), label: "outsider calls hidden module + hidden fun")
IO.inspect(:erlang.function_exported(Shop.Public, :helper, 1), label: "@doc false fun exported in export table")
