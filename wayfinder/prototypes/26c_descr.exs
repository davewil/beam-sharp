# Is Elixir 1.19's struct type NOMINAL, or a structural map type over a singleton tag?
# Ticket 10 already read Module.Types.Descr directly for its normalisation rule, so this
# follows that precedent rather than inferring from the warning text.
alias Module.Types.Descr
d = Descr.open_map([{:__struct__, Descr.atom([Order])}, {:id, Descr.integer()}])
IO.inspect(d, label: "descr for a struct-shaped map", limit: :infinity)
IO.puts("\nIs the tag an atom SINGLETON in the type?")
IO.inspect(Descr.atom([Order]), label: "  Descr.atom([Order])")
IO.puts("\nDo two struct types with the same fields but different tags intersect?")
a = Descr.open_map([{:__struct__, Descr.atom([Order])}, {:id, Descr.integer()}])
b = Descr.open_map([{:__struct__, Descr.atom([Invoice])}, {:id, Descr.integer()}])
IO.inspect(Descr.empty?(Descr.intersection(a, b)), label: "  disjoint?")
IO.puts("\nAnd with the tag removed from both?")
a2 = Descr.open_map([{:id, Descr.integer()}])
b2 = Descr.open_map([{:id, Descr.integer()}])
IO.inspect(Descr.equal?(a2, b2), label: "  equal without tag?")
