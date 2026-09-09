# 70 — Prior art on refusing an undiscriminable union: Elm, Gleam, TypeScript, Elixir, CDuce, Dialyzer

Research for [ticket 70](../issues/70-a-container-of-indiscriminable-members.md), 2026-09-09.
Asked by David while Round 1 was open, before answering it: *"Is there any prior art in Elixir,
Erlang, Gleam, Elm for this kind of typing example?"*

**The survey's answer is that there is none, and the reason is worth more than the answer.** No
other language in this set is *asked* the question ticket 70 asks, because each is missing at
least one of the three properties that produce it. So there is no external practice to defer to,
and the decision is B#'s own.

**Everything below is either MEASURED, CITED, or CARRIED, and the three are never mixed in one
sentence.** *Measured* means a probe run for this file produced the output quoted. *Cited* means a
primary source was fetched for this file and says it. *Carried* means this repo's own earlier
research says it, with its primary citations there and not re-fetched here — that third category
is new to this survey, and it exists because four of the seven arms were already surveyed and
re-deriving them would create a second source of truth for text already under version control.

| arm | instrument | what it can show |
|---|---|---|
| beam-sharp | the built `bsc` at `ea7f896` | **measured**, entirely |
| Gleam | [tour.gleam.run, custom types](https://tour.gleam.run/data-types/custom-types/), fetched 2026-09-09 | **cited** — formation only |
| Elm | [guide.elm-lang.org, custom types](https://guide.elm-lang.org/types/custom_types.html), fetched 2026-09-09 | **cited** — formation only |
| TypeScript | [research 07](07-csharp15-and-ts-unions.md) §3.2-3.3 | **carried** — handbook quotations live there |
| Elixir | [research 04](04-crossclause-exhaustiveness.md) §2 | **carried** — changelog, source comment, five probes live there |
| CDuce | [research 04](04-crossclause-exhaustiveness.md), pattern-form table | **carried** — the CDuce manual is cited there, not run here |
| Erlang / Dialyzer | [research 13](13-dialyzer-on-emitted-specs.md) | **carried** — no Dialyzer was run for this file |
| the nominal escape | [ticket 09](../issues/09-union-representation.md) §5 | **carried**, and measured *there* |

---

## Summary — the three properties, and who has all three

The question only arises for a language that has **all** of:

1. **structural, open unions** — `A | B` formed at a use site, with no constructor and no
   declaration;
2. **proved exhaustiveness** — the compiler must decide whether a clause set covers the union, so
   it must know whether the members can be told apart;
3. **a pattern vocabulary bounded by the runtime** — here, what a BEAM guard decides in O(1).

| | structural unions | proves exhaustiveness | runtime-bounded patterns | asks 70's question |
|---|---|---|---|---|
| **Elm** | no | yes | — | **no** |
| **Gleam** | no | yes | — | **no** |
| **TypeScript** | yes | no | yes | **no** |
| **Elixir** | yes | **not shipped** | yes | **no** |
| **CDuce** | yes | yes | **no** | **no** |
| **Erlang / Dialyzer** | n/a | no | n/a | **no** |
| **beam-sharp** | yes | yes | yes | **yes** |

Every other row is missing a column. B# is the only one with all three, and the third was chosen
deliberately: ticket 09 settled the criterion *"with **BEAM guards as the vocabulary** for what
`discriminable` means"* (09:374).

---

## Arm 1 — beam-sharp, measured at `ea7f896`

The situation itself, anchored to a run rather than to the ticket's prose:

```csharp
type Slot = map<string, int> | map<string, binary>              // REFUSED at the declaration
type Rows = list<map<string, int>> | list<map<string, binary>>  // compiles
```

`Rows` is `Slot` inside a list. A body that *uses* the binding is boxed in, and the last door is
shut by the compiler's own advice:

```csharp
public map<string, int> Head(Rows b)
Head([m, ..t]) -> m
```
> `error: Head returns a value its signature does not declare`
> `  the signature its clauses justify:`
> `    public map<string, int> | map<string, binary> Head(Rows b)`

Pasting that repair is refused by the declaration checker, because the repair *is* `Slot`. Nothing
unsound gets through — no `map<string, binary>` reaches a `map<string, int>` position — but the
author is admitted to a state with no legal exit, one container level past the declaration that
would have told them.

---

## Arm 2 — Elm and Gleam: the situation cannot be written

Both are nominal. Every variant of a custom type carries its own named constructor, so two members
are always tellable apart, and a union of two arbitrary existing types has no spelling at all.

**Gleam**, cited:

> A custom type is defined with the `type` keyword followed by the name of the type and a
> constructor for each *variant* of the type. ... Both the type name and the names of the
> constructors start with uppercase letters.
> — [tour.gleam.run, custom types](https://tour.gleam.run/data-types/custom-types/)

**Elm**, cited:

> ```elm
> type User
>     = Regular String
>     | Visitor String
> ```
> The `UserStatus` type has two **variants**.
> — [guide.elm-lang.org, custom types](https://guide.elm-lang.org/types/custom_types.html)

Neither source shows a tagless union, and neither documents one.

**This escape was examined and refused for beam-sharp on BEAM-specific grounds, and that is the
finding that matters here.** Ticket 09 §5, carried:

> Nominal identity is unenforceable across the Erlang boundary. ... A nominal union would be
> compile-time-true and runtime-false, reintroducing ticket 06's third outcome — *silent
> unsoundness* — by design.

with local evidence measured *there* (Elixir 1.19.5 / OTP 28, `prototypes/16a_elixir_protocol_dispatch.exs`):
a hand-built plain map `%{__struct__: Admin, name: "forged", age: 99}` dispatches as an `Admin` and
satisfies `is_struct/2`, having gone through no constructor.

**So Elm and Gleam offer beam-sharp no route.** They avoid ticket 70 by paying a price this project
measured and declined, for reasons that have nothing to do with ticket 70.

---

## Arm 3 — TypeScript: the same formation, and its answer is "leave it"

TypeScript is the closest structural analogue — unions formed at a use site, no declaration, no
tag, compatibility structural and open. It is the only row that could have faced 70's question,
and it does not, because it proves no exhaustiveness.

Carried from research 07, quoting the handbook:

> When every type in a union contains a common property with literal types, TypeScript considers
> that to be a *discriminated union*, and can narrow out the members of the union.

and research 07's own reading of the consequence:

> narrowing is **not** "compute the subset of the union consistent with this observation". It is a
> fixed catalogue of recognised syntactic guard forms, and a union whose shape does not match a
> recognised form **narrows not at all**.

**So the precedent for "leave it" exists, and it arrives bundled.** TypeScript's escape hatch for a
union it cannot narrow is a user-supplied type predicate whose body the compiler never checks —
research 07: *"`pet is Fish` whose body is `return true;` compiles clean under `--strict` and
crashes at runtime."* B# has no such construct and would not admit one. The half of TypeScript's
answer that makes leaving it tolerable is a half B# has already refused.

---

## Arm 4 — Elixir: the same algebra, and nothing yet asks

Elixir's set-theoretic types are the nearest relative of B#'s algebra. The question does not arise
because the shipped compiler does not check exhaustiveness. Carried from research 04:

> **Elixir v1.20 does *not* check exhaustiveness today, and the literature invites you to believe
> it does.** ... The shipped compiler ships **redundancy only**: the v1.20 changelog entry is
> `[Kernel] Detect and warn on redundant clauses`, with no exhaustiveness entry, the source
> carries the comment *"The mode may also control exhaustiveness checks in the future (to be
> decided)"*, and five non-exhaustive constructions compiled silently on v1.20.1.

Nothing in Elixir has to decide whether two members can be told apart, because nothing has to prove
a clause set covers them. **If Elixir ships exhaustiveness it inherits this question** — and in a
harder form, because it has no signatures for multi-clause functions (research 04).

---

## Arm 5 — CDuce: the theory does not impose the constraint

CDuce is where B#'s type algebra comes from, and it is the arm that shows the constraint is the
BEAM's rather than set theory's. Carried from research 04's table of CDuce pattern forms:

> **Record / map** `{l1=q1; ...; _=q0}` — a **cofinite** map from labels to pattern nodes ... the
> catch-all node ... may only perform a **type test**.

A CDuce pattern performs type tests at arbitrary depth, so `{a = Int}` and `{a = String}` are
discriminable *by a pattern* there. CDuce compiles to its own runtime and can afford the test.

**Nothing in semantic subtyping forbids forming an undiscriminable union.** What varies between
languages in this family is what the runtime can be asked at a clause head — and ticket 09 fixed
that, for B#, at what a BEAM guard decides in O(1).

---

## Arm 6 — Erlang and Dialyzer: never asks, by construction

Dialyzer computes **success typings** and reports only provable errors. It never demands that a
union's members be tellable apart, and it performs no exhaustiveness check that would need them to
be. Carried from research 13, whose finding runs the other way — that B#'s emitted specs are
*subtypes* of Dialyzer's success typings, i.e. strictly more precise.

**No Dialyzer run was made for this file.** The claim above is a property of what Dialyzer is, not
a measurement of what it does with `#{string() => integer()} | #{string() => binary()}`. A session
that wants that measurement should make it rather than cite this sentence.

---

## What this survey does not decide

**It does not answer Q1.** It removes one thing that might have looked like an answer: *"what does
everyone else do"* is not available as a tiebreak, because nobody else is asked. What is left is
the argument ticket 70 already had — that `Slot` is refused, `Rows` is `Slot` one container level
out, and the compiler currently prints a repair it refuses.

**Two things it does add.**

1. **"Leave it" is TypeScript's answer, and TypeScript pairs it with an unsound escape hatch.**
   That is not an argument against leaving it. It is a note that the precedent is not transferable
   whole, and that B# leaving it would be leaving it *without* the release valve the precedent
   comes with.

2. **"Refuse it" costs nothing permanent.** `Slot`'s own diagnostic says the refusal *"lifts when a
   pattern form for these members ships"* — ticket 48's map pattern, deferred at Q2 and tracked as
   [ENG-323](https://linear.app/davewil/issue/ENG-323). Under either answer both refusals lift
   together on that day. The choice is about what an author meets *until* then.

**It does not re-survey what research 04 and 07 already established.** A session that needs the
primary sources should read those files rather than this one: they carry the citations, and this
file carries only the comparison.
