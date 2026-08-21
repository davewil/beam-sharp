# 50 — Consuming an Elixir library: how is a foreign struct named?

Type: grilling
Status: open — [ENG-232](https://linear.app/davewil/issue/ENG-232)

Raised 2026-08-21 by David: *"Req is one of the most used Elixir libraries, I'd like an exemplar
importing that and proving the beam-sharp bindings all work."* This sharpens the standing fog patch
*"Consuming Gleam and Elixir libraries"* into the one question that blocks it.

## What is already measured

[`50a`](../prototypes/50a-elixir-ffi/Elx/elx.bs), against the built compiler:

| question | result |
|---|---|
| Does the FFI surface admit an **Elixir** module? | **Yes.** `using :'Elixir.String' { binary upcase(binary s) }` compiles and type-checks — ticket 32 made the module an atom, and an Elixir module *is* an atom with an `Elixir.` prefix. No new surface |
| Does it run? | **No.** `crashed: error:undef` — nothing puts Elixir's `ebin` on the escript's code path, and `bsc` has no flag that could. → **[ticket 51](51-a-build-and-dependency-tool.md)** |
| Can a foreign **map** be read? | **Yes.** `:maps.get` declared `term get(atom k, term m)` pulls `200` out of `#{status => 200, …}`; the caller narrows at each use, which is ticket 11's boundary rule working as designed |
| Can a **record pattern** match an Elixir struct? | **No — and this is the question** |

## The question

`Req.get!/1` returns `%Req.Response{}`. On the BEAM that is a map carrying
`__struct__ => 'Elixir.Req.Response'`. A beam-sharp record mints its tag **from its own qualified
type name** (ticket 26), so `record Response { Status: int }` declared here mints
`Kind => 'MyApp.Response'` and **cannot match the foreign value** — the tags differ, and by design,
because that minting is what gives aggregates identity.

So today a binding to Req reads every field through `:maps.get` as a `term`. **That works and it
proves the wrong thing**: the exemplar David asked for would demonstrate that the *call* succeeds
while demonstrating the language has no way to **name what comes back**.

**Does a foreign aggregate get a name, and if so, whose tag does it carry?**

Three shapes, none costed:

1. **A foreign record declaration** — `[external] record Req.Response { Status: int, Body: term }`
   binding the tag to `'Elixir.Req.Response'` instead of minting one. Smallest surface, and it makes
   the clause head work unchanged, which is the language's whole dispatch story.
2. **A map type** — read the struct as an ordinary open map, keys narrowed at use. This is
   **[ticket 48](48-a-map-type-in-the-prelude.md)** and the two tickets may be one question:
   [`31e`](../prototypes/31e_elixir_maps_vs_structs.exs) measured that `__struct__` and `Kind` are the
   *same mechanism* — a hidden tag key making otherwise-identical maps disjoint — and that a map type
   declaring the tag **absent** stays disjoint from every struct.
3. **`ValidateAs<T>` at the boundary** — validate the foreign map into a native record once, then
   work with a real record. Honest, and it costs a traversal whose size a foreign sender chooses,
   which is exactly what ticket 11 refused to put in a clause head.

## Why this is the better forcing case than the one that raised 48

Ticket 48 was raised by middleware, where `list<(atom, term)>` already carried the state, so the
gap was ergonomic. **Here it is structural**: there is no substitute that lets a foreign aggregate be
dispatched on, and dispatch is the language's defining feature. Resolve 48 and 50 together, or fold
one into the other.

## Notes

**Req is the hardest possible first binding, and that is why David chose it** (2026-08-21, when this
suggested `Jason` as an easier start: *"I picked Req exactly for that reason"*). Do not substitute a
smaller library to get a green binding sooner.

The reasoning is the one ticket 25 already records against itself. 25a *"constructed a shape to
answer the question instead of writing the workload honestly, which is the one failure ticket 25
exists to prevent"* — and picking `Jason` because it is easy is that failure wearing different
clothes. A binding story that works for Jason and not for Req is not a binding story: Jason returns
maps and lists and exercises almost none of the surface. Req exercises **all** of it at once — an
Elixir module atom, a struct return, nested aggregates inside it, a dependency tree of several
packages, and an application with a supervision tree that must be started before the first call.

So the decision this ticket reaches is made against the real requirement rather than a subset that
would need revisiting. That is the whole argument for the exemplars, applied to the FFI.

**The exemplar must not make a real HTTP call.** Req ships `Req.Test` and a `plug:` option for
stubbing; a gate that reaches the network is flaky by construction.
