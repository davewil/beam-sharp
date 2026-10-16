# 64 / P2 — how Elixir/Erlang report "absent" when the value type is `term`.
m = %{a: nil, b: false, c: :nothing, d: :error}
IO.inspect(Map.get(m, :a), label: "Map.get present-but-nil      ")
IO.inspect(Map.get(m, :zzz), label: "Map.get absent               ")
IO.inspect(Map.get(m, :c), label: "Map.get present value :nothing")
IO.inspect(Map.fetch(m, :a), label: "Map.fetch present-but-nil    ")
IO.inspect(Map.fetch(m, :zzz), label: "Map.fetch absent             ")
IO.inspect(Map.fetch(m, :d), label: "Map.fetch present :error     ")
IO.inspect(:maps.find(:a, m), label: "maps:find present-but-nil    ")
IO.inspect(:maps.find(:zzz, m), label: "maps:find absent             ")
# can a caller distinguish absent from present for a bare `term | :nothing` encoding?
bare = fn k -> case Map.fetch(m, k) do {:ok, v} -> v; :error -> :nothing end end
IO.inspect({bare.(:c), bare.(:zzz), bare.(:c) == bare.(:zzz)}, label: "bare encoding: {present :nothing, absent, indistinguishable?}")
