# Does Elixir's PATTERN position fold constant arithmetic (2 + 3) the way
# Erlang's does (2+3 -> literal 5), or is that refused / only unary minus
# tolerated?
defmodule PatternArith do
  def f(2 + 3), do: :two_plus_three
  def f(_), do: :other
end

IO.inspect(PatternArith.f(5), label: "f(5) via pattern `2 + 3`")
