# p2: Elixir 1.14.0 lookups, absent vs stored nil / :nothing / :error.
# Run: elixir p2_elixir_lookup_shapes.exs > p2_elixir_lookup_shapes.out
# Exit 1 if any assertion (comparison of two OBSERVED results) fails.
absent  = %{}
nil_v   = %{k: nil}
nothing = %{k: :nothing}
err_v   = %{k: :error}
kw_abs  = []
kw_nil  = [k: nil]

rows = [
  {"Map.fetch absent",           Map.fetch(absent, :k)},
  {"Map.fetch stored nil",       Map.fetch(nil_v, :k)},
  {"Map.fetch stored :nothing",  Map.fetch(nothing, :k)},
  {"Map.fetch stored :error",    Map.fetch(err_v, :k)},
  {"Map.get/2 absent",           Map.get(absent, :k)},
  {"Map.get/2 stored nil",       Map.get(nil_v, :k)},
  {"Map.get/3 default :nothing, absent",          Map.get(absent, :k, :nothing)},
  {"Map.get/3 default :nothing, stored :nothing", Map.get(nothing, :k, :nothing)},
  {"Access.get absent",          Access.get(absent, :k)},
  {"Access.get stored nil",      Access.get(nil_v, :k)},
  {"Keyword.get absent",         Keyword.get(kw_abs, :k)},
  {"Keyword.get stored nil",     Keyword.get(kw_nil, :k)},
  {"Keyword.fetch absent",       Keyword.fetch(kw_abs, :k)},
  {"Keyword.fetch stored nil",   Keyword.fetch(kw_nil, :k)},
  {"Map.has_key? absent",        Map.has_key?(absent, :k)},
  {"Map.has_key? stored nil",    Map.has_key?(nil_v, :k)}
]
Enum.each(rows, fn {l, r} -> IO.puts(String.pad_trailing(l, 48) <> "-> " <> inspect(r)) end)
r = fn l -> rows |> List.keyfind(l, 0) |> elem(1) end

asserts = [
  {"Map.get/2: absent == stored nil",      r.("Map.get/2 absent") === r.("Map.get/2 stored nil")},
  {"Access.get: absent == stored nil",     r.("Access.get absent") === r.("Access.get stored nil")},
  {"Keyword.get: absent == stored nil",    r.("Keyword.get absent") === r.("Keyword.get stored nil")},
  {"Map.get/3 default :nothing: absent == stored :nothing",
     r.("Map.get/3 default :nothing, absent") === r.("Map.get/3 default :nothing, stored :nothing")},
  {"Map.fetch: absent /= stored nil",      r.("Map.fetch absent") !== r.("Map.fetch stored nil")},
  {"Map.fetch: absent /= stored :error",   r.("Map.fetch absent") !== r.("Map.fetch stored :error")},
  {"Keyword.fetch: absent /= stored nil",  r.("Keyword.fetch absent") !== r.("Keyword.fetch stored nil")},
  {"Map.has_key? separates absent from stored nil",
     r.("Map.has_key? absent") !== r.("Map.has_key? stored nil")}
]
Enum.each(asserts, fn {n, v} -> IO.puts("ASSERT " <> String.pad_trailing(n, 62) <> if(v, do: "holds", else: "FAILS")) end)
if Enum.all?(asserts, &elem(&1, 1)), do: System.halt(0), else: System.halt(1)
