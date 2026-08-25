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
| Does it run? | **Yes, since 2026-08-21** — `ERL_LIBS` alone, no compiler change. See **[ticket 51](51-a-build-and-dependency-tool.md)**, which measured it against the real Req tree |
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

**CONFIRMED AGAINST REQ ITSELF — 2026-08-21.** This is no longer reasoning from what a struct *is*;
[`51a`](../prototypes/51a-code-path/Req/req.bs) calls `Req.new/1` for real and reads the value back:

| | |
|---|---|
| `:maps.get(:'__struct__', resp)` | **`:'Elixir.Req.Request'`** |
| `:maps.get(:method, resp)` | `:get` |
| `:maps.is_key(:'Kind', resp)` | **`:false`** |

The last row is the whole ticket in one measurement. The value carries Elixir's tag, does not carry
beam-sharp's, and there is no clause head that can dispatch on it.

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

   > **Sharpened 2026-08-25 — "the tag" is two tags, and which one you name decides this ticket.**
   > That last clause is true only if the key declared absent is `__struct__`. Ticket 48's actual
   > proposal declares **`Kind`** absent, which says nothing about `__struct__`, and measured
   > ([`48e`](../prototypes/48e_dict_vs_two_tags.exs)) an Elixir struct **is** then a member of the
   > map type. So this candidate does not merely *coexist* with 48 — **48's own wording already
   > grants it**, for free and possibly by accident. The alternative, declaring both tags absent, is
   > also available and also works, and it shuts this candidate off: an unrestricted open map, the
   > obvious fallback, admits a B# record and an Elixir struct alike and so cannot separate them.
   > **Whichever way 48 words its map type decides whether shape 2 here exists at all**, which is
   > the strongest form yet of this ticket's own request to be resolved alongside it.
3. **`ValidateAs<T>` at the boundary** — validate the foreign map into a native record once, then
   work with a real record. Honest, and it costs a traversal whose size a foreign sender chooses,
   which is exactly what ticket 11 refused to put in a clause head.

## What `Req.get!` actually hands back, and what B# can say about it — 2026-08-25

David: *"let's examine the result from `Req.get!` in Elixir — what does it return, an Elixir struct
or map? if I call `Req.get!` from B# what do I get, record or dict?"*
[`50b`](../prototypes/50b_what_req_get_hands_back.sh) answers both against a live Req 0.7.3, with
the adapter **stubbed** so nothing reaches the network — this ticket's own rule — and the stub's
values coming back verbatim is how that is known.

### Elixir side: the question has no "or" in it

| | |
|---|---|
| `is_struct?` | **true** |
| `is_map?` | **true** |
| `:maps.get(:'__struct__', …)` | `Req.Response` |
| `:maps.is_key(:'Kind', …)` | `:false` |
| keys | `[:__struct__, :body, :headers, :private, :status, :trailers]` |

**A struct is a map.** There is no struct term on the BEAM, so "struct or map" is not a choice the
runtime offers — it is a map carrying one extra key. That is the same mechanism as a beam-sharp
record's minted `Kind`, which 31e already measured.

**And one call returns both kinds, nested.** The response is a *tagged* map; its `body` is a
**plain** map (`%{"id" => 7, "ok" => true}`, no `__struct__`) and so are its `headers`. So a binding
to Req needs an answer for tagged foreign aggregates *and* for untagged foreign maps at the same
time, from a single call. That is this ticket and ticket 48 arriving together in one value.

### B# side: neither, and one of the refusals is silent

| declaration | result |
|---|---|
| `map<atom, term> new(…)` | **refused** — *"no type named map takes a type argument"* |
| `dict<atom, term> new(…)` | **refused** — *"no type named dict takes a type argument"* |
| `term new(…)` (control) | accepted |
| **`Response new(…)`, a record** | **accepted** |

That last row is the finding. The compiler **type-checks a record-typed foreign return** — and then,
run against the live value:

    Tag()       -> :'Elixir.Req.Request'      (control: the call works)
    HasKind()   -> :false                     (control: no beam-sharp tag)
    Dispatch()  -> crashed: error:function_clause

**So shape 1 is not merely absent — its naive form is accepted and then fails at run time with no
diagnostic.** The clause head the compiler checked cannot match the value the function returns.
This ticket already argued that a minted tag cannot match a foreign one; what is new is that
nothing *says so* at the declaration, which makes it a silent trap rather than a refusal. Whatever
shape this ticket picks, **the plain form wants a diagnostic** — the compiler knows records are
tagged and knows a foreign function cannot mint the tag, so it has everything it needs to refuse.

### And `Req.get!` cannot be named at all

The bang is an ordinary character in an Erlang atom — `'Elixir.Req':'get!'/2` — and B# has no
spelling for it. Both forms measured:

| | |
|---|---|
| `term get!(…)` | **refused** — `illegal characters "!("` |
| `term :'get!'(…)` | **refused** — `syntax error before: 'get!'` |

A bang-free neighbour in the same block compiles, so this is the bang and not the probe. **This
blocks the exemplar this ticket exists to serve** — `get!`, `fetch!`, `put!` and friends are the
Elixir convention for the raising variant, and `Req.get!` is precisely the call the requested Req
exemplar would make. Raised separately; it is an FFI-surface gap rather than a naming decision.

<!-- ENG-250 -->

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
