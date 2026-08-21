# 31b — Does a hidden tag key make a record disjoint from a plain map?
#
# Raised by David during ticket 31: "our records have the hidden Kind doesn't
# that help?" B# mints a `Kind` key onto every record (ticket 26), and Elixir
# does the identical thing with `__struct__`. So the question of whether
# `map<K,V>` can coexist with records has a shipping answer to measure.
#
# Measured against Elixir 1.19.5, Module.Types.Descr — the same instrument
# tickets 10 and 15 used.

alias Module.Types.Descr

int = Descr.integer()
_atom = Descr.atom()

show = fn label, result ->
  IO.puts(String.pad_trailing(label, 58) <> inspect(result))
end

IO.puts("\n--- 1. what a PATTERN means: open, not closed ---")
# `%{a: 1}` in a pattern matches ANY map carrying a, so the pattern type is open.
open_a = Descr.open_map(a: int)
closed_a = Descr.closed_map(a: int)
show.("open %{a: int} is a subtype of closed %{a: int}?", Descr.subtype?(open_a, closed_a))
show.("closed %{a: int} is a subtype of open %{a: int}?", Descr.subtype?(closed_a, open_a))

IO.puts("\n--- 2. a struct is a map carrying a hidden tag ---")
# %Order{a: 1} is %{__struct__: Order, a: 1} — closed, with the tag key.
order = Descr.closed_map(__struct__: Descr.atom([Order]), a: int)
invoice = Descr.closed_map(__struct__: Descr.atom([Invoice]), a: int)
show.("Order disjoint from Invoice (identical fields)?", Descr.disjoint?(order, invoice))

IO.puts("\n--- 3. THE COLLISION: does an open map pattern match a struct? ---")
show.("open %{a: int} disjoint from %Order{a: int}?", Descr.disjoint?(open_a, order))
show.("%Order{} is a subtype of open %{a: int}?", Descr.subtype?(order, open_a))

IO.puts("\n--- 4. does CLOSING the map exclude the struct? ---")
show.("closed %{a: int} disjoint from %Order{a: int}?", Descr.disjoint?(closed_a, order))

IO.puts("\n--- 5. can a map type say the tag key is ABSENT? ---")
# This is the question that decides whether `map<K,V>` and records can be
# disjoint types in B# rather than merely different spellings.
no_tag = Descr.open_map([{:__struct__, Descr.not_set()}, {:a, int}])
show.("open %{a: int, __struct__: not_set} vs %Order{}?", Descr.disjoint?(no_tag, order))
show.("...and does it still admit a plain %{a: 1}?", Descr.subtype?(closed_a, no_tag))
