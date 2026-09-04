# 50 — Consuming an Elixir library: how is a foreign struct named?

Type: grilling
Status: **resolved 2026-08-26** — [ENG-232](https://linear.app/davewil/issue/ENG-232). Answered by
[ticket 48](48-a-map-type-in-the-prelude.md)'s Q3 (`Kind` absent only) on 2026-08-25: a foreign
struct **is** a `map<atom, term>`, shape 2, with no new surface. See *DECIDED* at the foot. The Req
exemplar this ticket asks for is still owed — naming is settled, the binding is not written.

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

## Can a B# function name contain `!` or `?` — and should it? Settled 2026-08-25

David reframed the previous section: *"I don't think it's a grammar decision per se, it's can a
function name include `!` or `?`"*. Measured in
[`50c`](../prototypes/50c_bang_and_question_spelling.sh), four parts.

### 1. Neither character is idle, and allowing it removes behaviour silently

`!` appears in B#'s lexer only inside `!=`; `?` is a token used in exactly one production — ticket
26 §4's tripwire, which catches `Notes?: int` and redirects it to `Notes: option<T>`. Built as a
throwaway leex scanner rather than reasoned about, because a lexer conflict is measured:

```
"a != b"        -> [{ident,"a"},'!=',{ident,"b"}]
"a!=b"          -> [{bang_ident,"a!"},'=',{ident,"b"}]
"a! = b"        -> [{bang_ident,"a!"},'=',{ident,"b"}]
"Notes?: int"   -> [{q_uident,"Notes?"},':',{ident,"int"}]
"Notes ?: int"  -> [{uident,"Notes"},'?',':',{ident,"int"}]
```

Lines 2 and 3 are **identical token streams**: with a bang in identifiers, `a!=b` stops being a
comparison, and since `=` is *match* (F8) it silently becomes a match expression. Line 4: `Notes?:`
becomes one token, so `field_decl -> uident '?' ':' type_expr` can never fire and the tripwire 26 §4
paid for is disarmed — the field is simply named `Notes?`.

**Neither case is an error. Both quietly delete behaviour that exists today**, which is a stronger
argument than "the character is taken", and it is the same argument twice.

### 2. `get` and `get!` are two functions, so an alias is required, not a workaround

Req exports **18** bang functions. Measured against a stub returning a real transport error:

| | |
|---|---|
| `Req.get/1` | `{:error, %Mint.TransportError{reason: :nxdomain}}` — a **value** |
| `Req.get!/1` | **raises** `Mint.TransportError` |

Two exports, two contracts. A module wanting both needs two B# names whatever the grammar allows.

### 3. What the conventions actually say

Elixir's official naming-conventions page, quoted rather than recalled:

> "Functions that return a boolean are named with a trailing question mark."

> "Type checks and other boolean checks that are allowed in guard clauses are named with an `is_`
> prefix… precisely to indicate that they are allowed in guard clauses."

> "A trailing question mark should not be used in combination with the `is_` prefix."

> "A trailing bang (exclamation mark) signifies a function or macro where failure cases raise an
> exception. They most often exist as a 'raising variant' of a function that returns `:ok`/`:error`
> tuples (or `nil`)."

<!-- hexdocs.pm/elixir/naming-conventions.html; verified against lib/elixir/pages/references/naming-conventions.md on main and at tag v1.20.0 -->

Three corrections this survey owes against how the question was first put here:

- **The bang's definition is only *"failure cases raise an exception"*.** The pairing with error
  tuples is *"most often"* — descriptive, not definitional. *"raises instead of returning an error
  tuple"* is a stronger claim than the source supports.
- **A non-bang counterpart is explicitly optional**: *"In some situations, you may have bang
  functions without a non-bang counterpart."* `50c` measured 11 unpaired bangs in the stdlib sample,
  and that **confirms** the documented rule rather than finding an exception to it.
- **`is_` is a naming signal, not a mechanism.** `defguard` is what makes something guard-usable;
  `Map.has_key?/2` is barred from guards because it is an ordinary remote call, not because of how it
  is spelled. Measured: `is_map/1` in a guard is allowed, `Map.has_key?/2` is `REFUSED`.

`50c` also swept 18 stdlib modules for a counterexample to `? -> boolean` and found **none** in 66
returning arity-1 calls.

### 4. The decision, and why it is not a close call

Elixir's two suffixes encode **three** facts. B# already carries all three, in the **signature**
rather than the name:

| Elixir encodes in the name | B# carries in the type |
|---|---|
| `!` — failure cases raise | `result<T, foreign_error>`, and F19 **emits the `try`** |
| `?` — returns a boolean | the signature says `bool` |
| `is_` vs `?` — guard-valid or not | **no such distinction exists** |

The third row is measured: a user function in a B# guard is refused outright, so nothing
user-written is guard-valid and there is no fact for a suffix to advertise. Elixir needs two
spellings because *some* of its predicates are guard-usable; B# needs none, because none are.

> The refusal is right and the *diagnostic* is not — it is erlc's text on a `.bs` line, and it
> arrives with a `function 'Even'/1 is unused` warning about a function that is used, just
> illegally. Raised separately; it matters here because that message is the **only** place a user
> ever meets the rule that makes this row empty.
>
> <!-- ENG-251 -->

**So nothing the convention carries is left over.** It is an artefact of a language with no
signature to read. Adopting it here would duplicate a checked fact with an unchecked one and let the
two disagree — nothing would stop `Fetch!` being declared to return a plain value.

**Settled: neither character enters a B# identifier, and neither gains meaning in B#.** They stay
what they are, characters in somebody else's atom, and the `using` block needs a way to bind a B#
name to that atom. Ticket 32 already established that *"a foreign function is declared, and the
declaration carries both spellings"* — this is that principle meeting a name B# cannot spell, and
the foreign half is a quoted atom, which is a restricted context rather than an expression, so it
carries none of §1's cost.

### One mismatch to carry into the spec, which is not a blocker

The bang governs **semantic** failure only — *"Errors that come from invalid argument types, or
similar, must always raise regardless if the function has a bang or not."* B#'s
`result<T, foreign_error>` emits a `try` that catches **both**. So declaring a bang function that way
is right, but the B# type is *broader* than the convention it stands in for, and the spec should say
so rather than implying they name the same set of failures.

### Not decided here: what the B# aliases should be called

C# and Elixir invert this convention — Elixir is `get` (returns) / `get!` (raises); C# is
`TryGetValue` (returns) / `Get` (throws), where the bare name is the throwing one. So *"the plain
name is the safe one"* is an Elixir assumption a C#-shaped audience will not share. That is a
tier-1-versus-tier-2 naming question and it wants deciding deliberately.

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

---

## Answer — shape 2, by ticket 48's Q3. Recorded 2026-08-26

**This ticket is answered, and it was answered elsewhere.** [Ticket 48](48-a-map-type-in-the-prelude.md)
closed on 2026-08-25 with *"Q3 — which tag does it exclude? **`Kind` absent only**"*, and 48's own
resolution names the consequence as execution rather than a decision: *"Q3 settles ticket 50 …
Record it there."* This section is that recording. Nothing new is decided here.

**A foreign aggregate gets no name of its own. It is a `map<atom, term>`, and that works with no new
surface.** Shape 2 above, exactly as its *Sharpened 2026-08-25* note predicted: because the excluded
tag is `Kind` and **not** `__struct__`, the map type says nothing about `__struct__`, and
[`48e`](../prototypes/48e_dict_vs_two_tags.exs) measured that an Elixir struct is therefore a member
of it. `%Req.Response{}` is a `map<atom, term>` a clause head can take.

The fork this ticket identified is worth keeping visible, because 48 could have closed it and did
not. Had 48 declared **both** tags absent — an option that was available, and works — an Elixir
struct would have been excluded from the map type and shape 2 would not exist at all. The two
tickets really were one question, as this file argued three times; the answer arrived through 48.

**Shapes 1 and 3 are not chosen, and they exit differently:**

- **Shape 1, the `[external] record` declaration, stays unbuilt** — and its measured silent trap is
  now a **defect report rather than a design option**, since nothing will be built that could hit it.
- **Shape 3, `ValidateAs<T>` at the boundary, remains available and is not refused.** It is the right
  tool where a caller wants a real record and will pay the traversal knowingly; what 11 refused was
  paying it *implicitly in a clause head*, which shape 2 does not do.

**What this does not settle.** The exemplar David asked for is still owed — this decides how a
foreign struct is *named*, not that the Req binding has been written. The requirement above stands
unchanged, Req rather than Jason, with `Req.Test` stubbing and no real HTTP call.

## Decisions entry

<!-- This ticket's entry. wayfinder/decisions.md is GENERATED from blocks like this
     one and carries only the first sentence; the whole entry is read here. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [Consuming an Elixir library: how is a foreign struct named?](issues/50-naming-a-foreign-struct.md)
  — **a foreign aggregate gets no name of its own: it is a `map<atom, term>`, and that works with no
  new surface.** This ticket was answered elsewhere and the recording is the point — ticket 48's Q3
  chose `Kind` absent only, and because the excluded tag is **not** `__struct__`, the map type says
  nothing about `__struct__` and an Elixir struct is a member of it. `%Req.Response{}` is a
  `map<atom, term>` a clause head can take. **The fork is worth keeping visible because 48 could have
  closed it and did not**: had 48 declared *both* tags absent — available, and it works — a struct
  would have been excluded and this shape would not exist. The two tickets really were one question.
  Settled separately here: **neither `!` nor `?` may appear in a B# function name**, so `Req.get!`
  cannot be named at all and an alias is required rather than a workaround. Resolved 2026-08-26.
```
