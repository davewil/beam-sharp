# P9: how do Elixir and Erlang treat a module that is "internal"?  Run: elixir p9_elixir_erlang_internal.exs
defmodule Lib.Internal.Helper do
  @moduledoc false
  def round_total(x), do: x + 1
end

defmodule Lib.Api do
  def api, do: Lib.Internal.Helper.round_total(41)
end

defmodule Outsider do
  # no relationship to Lib at all
  def peek, do: Lib.Internal.Helper.round_total(1)
end

IO.puts("Lib.Api.api()        = #{Lib.Api.api()}")
IO.puts("Outsider.peek()      = #{Outsider.peek()}   (compiled with no warning or error above this line)")
# (attempt 1 also fetched this module's docs chunk: modules defined in a script have no beam on disk, so fetch_docs errors; see p9.attempt1-failed.out)

# how widely the convention is used inside Elixir's own standard library
mods = Application.spec(:elixir, :modules)
hidden = Enum.count(mods, fn m -> match?({:docs_v1, _, _, _, :hidden, _, _}, Code.fetch_docs(m) |> case do {:error, _} -> nil; d -> d end) end)
IO.puts("elixir app: #{length(mods)} modules, #{hidden} carry @moduledoc false (hidden from docs, still callable)")

# Erlang: erts_internal is documented as not for use; nothing stops a call
IO.inspect(:erts_internal.cmp_term(1, 2), label: ":erts_internal.cmp_term(1, 2) from user code")
