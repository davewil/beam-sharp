# PROTOTYPE 48m — how does Elixir handle maps under set-theoretic typing, and
# what does that say about ticket 48's "precision is the unknown"?
#
# Throwaway. Ticket 48, after Q1/Q2 were decided. David: "I need to see again
# how Elixir handles maps with pattern matching and set-theoretic typing."
#
# Elixir is the sharpest comparison available, and a better one than Gleam: it
# is the only shipped system with BOTH map patterns AND a set-theoretic type
# system. 31e and 48e used `Module.Types.Descr` for tag questions. This probe
# asks the two STRUCTURAL questions those did not:
#
#   1. Does Descr have an UNBOUNDED KEY DOMAIN, and where does it live?
#   2. Is its subtraction EXACT on the case B# gives up on?
#   3. Does Elixir enforce EXHAUSTIVENESS at all?
#
# Question 3 is the one that decides how much of 1 and 2 transfers. B# spends
# precision on proving clause sets complete; if Elixir spends it somewhere else,
# its exactness does not tell us how much B# needs.
#
#   elixir wayfinder/prototypes/48m_elixir_maps_under_descr.exs
#
# Elixir 1.19.5 / OTP 28. Run from the repo root.

require Module.Types.Descr
alias Module.Types.Descr, as: D

int = D.integer()

show = fn label, v -> IO.puts("    " <> String.pad_trailing(label, 46) <> inspect(v)) end

IO.puts(~S"""

===============================================================
0. CONTROLS — can this instrument report both answers?
===============================================================
""")
show.("disjoint?(integer, atom)  expect TRUE", D.disjoint?(int, D.atom()))
show.("disjoint?(integer, integer) expect FALSE", D.disjoint?(int, int))
show.("empty?(A \\ A)  expect TRUE", D.empty?(D.difference(D.closed_map([{:a, int}]), D.closed_map([{:a, int}]))))
show.("empty?(A)      expect FALSE", D.empty?(D.closed_map([{:a, int}])))

IO.puts(~S"""

===============================================================
1. THE UNBOUNDED KEY DOMAIN — it exists, and it is not a
   separate member kind
===============================================================

    Descr's map representation is a BDD of pairs `{tag_or_domain, fields}`,
    where tag_or_domain is `:closed`, `:open`, OR A MAP FROM DOMAIN KEYS TO
    TYPES, and `fields` is the finite atom-keyed part. There are twelve domain
    key types: binary, integer, float, atom, tuple, map, list, fun, pid, port,
    reference, empty_list.

    So the thing ticket 48 called "a second member kind" is, in the one shipped
    set-theoretic implementation, A THIRD VALUE OF THE EXISTING TAG SLOT.
    B#'s `{closed | open, #{atom() => ty()}}` is the same shape minus that
    third case.
""")

dom = D.open_map([{D.domain_key(:binary), int}])
named = D.closed_map([{:a, int}])
show.("a binary-keyed domain map is a map?", D.subtype?(dom, D.open_map()))
show.("a named-field map is a map?", D.subtype?(named, D.open_map()))
show.("domain map disjoint from named map?", D.disjoint?(dom, named))

IO.puts(~S"""

===============================================================
2. IS SUBTRACTION EXACT ON THE CASE B# SURRENDERS?
===============================================================

    bs_types.erl m_minus, last clause:

        m_minus({open, FA}, {closed, _FB}) ->
            %% "these fields, plus at least one more" is not something this
            %% algebra can name. Keep the minuend whole.
            [{open, FA}].

    B# over-approximates because its map part is a FLAT LIST of members with
    no negation node. Elixir keeps negations SYMBOLIC in the BDD. Same
    subtraction, both instruments:
""")

openA = D.open_map([{:a, int}])      # a: integer, and possibly more
closedA = D.closed_map([{:a, int}])  # exactly a: integer, nothing else
diff = D.difference(openA, closedA)  # "a: integer AND at least one more key"

show.("closedA is a subtype of openA?", D.subtype?(closedA, openA))
show.("GAVE UP (diff == openA)?", D.equal?(diff, openA))
show.("diff excludes closedA?", D.disjoint?(diff, closedA))
show.("diff still within openA?  (sound)", D.subtype?(diff, openA))
show.("diff empty?  (not degenerate)", D.empty?(diff))
show.("diff still admits %{a, b}?", D.subtype?(D.closed_map([{:a, int}, {:b, int}]), diff))

exact? = not D.equal?(diff, openA) and D.disjoint?(diff, closedA) and
         D.subtype?(diff, openA) and not D.empty?(diff)

IO.puts("")
if exact? do
  IO.puts("    ==> EXACT. The case B# cannot name, Elixir names. The imprecision")
  IO.puts("        is therefore NOT inherent to set-theoretic maps — it is a")
  IO.puts("        consequence of the flat-list representation B# chose.")
else
  IO.puts("    ==> NOT exact — re-read before relying on the writeup.")
end

IO.puts(~S"""

===============================================================
3. DOES ELIXIR ENFORCE EXHAUSTIVENESS?  (the disanalogy)
===============================================================

    Measured by compiling, not by reasoning. A function with a clause for
    %{a: _} and NO clause for %{b: _} and no catch-all:

        def pick(%{a: _}), do: :saw_a

    compiles at EXIT 0 with NO WARNING. Elixir does not prove clause sets
    complete. What it does instead is INFER THE DOMAIN from the clauses and
    check CALLERS against it — calling `pick(%{b: 1})` warns:

        given types:     -%{a: not_set(), b: integer()}-
        but expected:    dynamic(%{..., a: term()})

    So Elixir spends its precision on call-site checking, not on totality.

    WHAT THAT MEANS FOR TICKET 48. Elixir's exactness proves the imprecision
    is FIXABLE. It does not prove B# needs it fixed, because Elixir is never
    asked to close a residual. B# is the one asking a question Elixir does not
    ask, so the precision budget has to be decided on B#'s own terms.
""")
