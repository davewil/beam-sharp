# 64_untagged_vs_tagged.exs
# CLAIM: the collapse is a property of UNTAGGED unions in a set-theoretic type algebra, not of lookups or of B#:
#   T | :nothing == T whenever :nothing ⊆ T; a TAGGED success ({:ok, T} | :absent) never equals T, nests, and
#   survives at T = term. Measured on a shipping implementation of the same theory (Elixir 1.18.5 Module.Types.Descr).
# REFUTED if: any "collapsed?" line under TAGGED prints true, or any under UNTAGGED at T=term/atom prints false;
#   or the nest line under TAGGED prints false.
# Control: UNTAGGED at T=int (expected false = survives).
alias Module.Types.Descr
nothing = Descr.atom([:nothing]); absent = Descr.atom([:absent]); ok = Descr.atom([:ok])
t_term = Descr.term(); t_atom = Descr.atom(); t_int = Descr.integer()
untag = fn t -> Descr.union(t, nothing) end
tag   = fn t -> Descr.union(Descr.tuple([ok, t]), absent) end
row = fn label, a, b -> IO.puts(String.pad_trailing(label, 42) <> to_string(Descr.equal?(a, b))) end
IO.puts("-- UNTAGGED  T | :nothing  equal to bare T?")
row.("T=int  (control, expect false)", untag.(t_int), t_int)
row.("T=atom", untag.(t_atom), t_atom)
row.("T=term", untag.(t_term), t_term)
row.("nest option<option<int>> == option<int>", untag.(untag.(t_int)), untag.(t_int))
IO.puts("-- TAGGED  {:ok,T} | :absent  equal to bare T?")
row.("T=int", tag.(t_int), t_int)
row.("T=atom", tag.(t_atom), t_atom)
row.("T=term", tag.(t_term), t_term)
row.("nest found<found<int>> == found<int>", tag.(tag.(t_int)), tag.(t_int))
