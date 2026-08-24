# PROTOTYPE 48e — does a `dict` type admit an Elixir struct?
#
# Throwaway. Tickets 48 and 50, the question that joins them.
#
# 31e measured that a map type declaring a tag key ABSENT is disjoint from
# every map carrying it, while still admitting plain maps. Ticket 48 then
# proposed that `dict<K, V>` be internally "open map, `Kind` absent", which
# keeps it disjoint from every B# record by construction.
#
# But there are TWO tags in play, not one, and they are different atoms:
#
#     a B# record      is a map carrying  Kind        => :'MyApp.Response'
#     an Elixir struct is a map carrying  __struct__  => :'Elixir.Req.Response'
#
# So a dict defined as "`Kind` absent" says nothing at all about `__struct__`.
# The question David asked: does `dict` therefore ADMIT a foreign struct?
#
# That matters in both directions. If it admits one, ticket 50's candidate 2
# ("read the foreign struct as an ordinary open map") works for free — and
# `dict` stops distinguishing a real dictionary from somebody else's struct.
#
#   elixir wayfinder/prototypes/48e_dict_vs_two_tags.exs
#
# Measured against Elixir's Module.Types.Descr, the instrument tickets 10, 15
# and 31e used. Run from the repo root.

alias Module.Types.Descr

int = Descr.integer()

show = fn label, result ->
  IO.puts("    " <> String.pad_trailing(label, 62) <> inspect(result))
end

IO.puts("""

===============================================================
0. CONTROLS — can this instrument report BOTH answers?
===============================================================
    A probe that only ever says `true` is decoration. These four
    establish that disjoint?/2 and subtype?/2 each return both
    values on this instrument before any result below is read.
""")

show.("disjoint?(integer, atom) — should be TRUE", Descr.disjoint?(int, Descr.atom()))
show.("disjoint?(integer, integer) — should be FALSE", Descr.disjoint?(int, int))
show.("subtype?(integer, integer) — should be TRUE", Descr.subtype?(int, int))
show.("subtype?(integer, atom) — should be FALSE", Descr.subtype?(int, Descr.atom()))

# ---------------------------------------------------------------------------
# The four shapes.
# ---------------------------------------------------------------------------

# A B# record: a map carrying the minted `Kind` (ticket 26).
bs_record =
  Descr.closed_map([
    {:Kind, Descr.atom([:"MyApp.Response"])},
    {:Status, int}
  ])

# An Elixir struct: a map carrying `__struct__`, and NO `Kind`.
# 51a measured both halves of that against the real Req on 2026-08-21 —
# :maps.get(:'__struct__', resp) is :'Elixir.Req.Request', and
# :maps.is_key(:'Kind', resp) is false.
ex_struct =
  Descr.closed_map([
    {:__struct__, Descr.atom([:"Elixir.Req.Response"])},
    {:status, int}
  ])

# An ordinary map, carrying neither tag. This is what a dict is FOR.
plain_map = Descr.closed_map([{:status, int}])

# Candidate A — ticket 48's proposal as written: "open map, `Kind` absent".
dict_kind_absent =
  Descr.open_map([
    {:Kind, Descr.not_set()}
  ])

# Candidate B — the stricter version, excluding BOTH tags.
dict_both_absent =
  Descr.open_map([
    {:Kind, Descr.not_set()},
    {:__struct__, Descr.not_set()}
  ])

IO.puts("""

===============================================================
1. CANDIDATE A — dict = "open map, `Kind` absent"
   (ticket 48's proposal, exactly as written)
===============================================================
""")

show.("disjoint from a B# record?", Descr.disjoint?(dict_kind_absent, bs_record))
show.("admits a plain map?", Descr.subtype?(plain_map, dict_kind_absent))
IO.puts("")
show.("ADMITS an Elixir struct?", Descr.subtype?(ex_struct, dict_kind_absent))
show.("...i.e. disjoint from an Elixir struct?", Descr.disjoint?(dict_kind_absent, ex_struct))

IO.puts("""

===============================================================
2. CANDIDATE B — dict = "open map, BOTH tags absent"
===============================================================
""")

show.("disjoint from a B# record?", Descr.disjoint?(dict_both_absent, bs_record))
show.("disjoint from an Elixir struct?", Descr.disjoint?(dict_both_absent, ex_struct))
show.("still admits a plain map?", Descr.subtype?(plain_map, dict_both_absent))

IO.puts("""

===============================================================
3. THE COST OF B — can a foreign struct still be read at all?
===============================================================
    If dict excludes __struct__, then ticket 50's candidate 2
    ("read the foreign struct as an ordinary open map") needs a
    DIFFERENT type to land in. An unrestricted open map is the
    obvious one — check it still takes both.
""")

open_anything = Descr.open_map([])
show.("unrestricted open map admits an Elixir struct?", Descr.subtype?(ex_struct, open_anything))
show.("unrestricted open map admits a B# record?", Descr.subtype?(bs_record, open_anything))
show.("...so it does NOT separate them", not Descr.disjoint?(bs_record, open_anything))

IO.puts("""

===============================================================
4. Is a B# record distinguishable from an Elixir struct at all?
===============================================================
    Both are tagged maps. If the two tags did not keep them
    apart, the whole scheme would be in trouble.
""")

show.("B# record disjoint from Elixir struct?", Descr.disjoint?(bs_record, ex_struct))

IO.puts("\ndone.\n")
