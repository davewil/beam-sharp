# 54 — List length in the algebra: a proved-exhaustive program that crashes

Type: grilling
Status: **resolved 2026-08-21, and built the same day** — [ENG-236](https://linear.app/davewil/issue/ENG-236).
See [Answer](#answer) at the end. The build is
[F20](../../compiler/features/F20-list-length.md), which carries the representation, and five
things the decision did not know until code was written — including a correction to this file.

Raised 2026-08-21 from [prototype 53a](../prototypes/53a-closed-list-patterns.md), which set out
to test [ticket 53](53-a-route-table-needs-a-closed-list-pattern.md)'s premise and found this
instead.

## The repro, in two clauses

```csharp
module Gap

public atom Shape(list<int> xs)

Shape([])          -> :empty
Shape([a, b, ..t]) -> :many
```

```
$ bsc --src-root . Gap                 # compiles clean, no diagnostic
$ bsc --src-root . Gap Shape '[7]'
crashed: error:function_clause
```

**The compiler proved this exhaustive and it crashes on a value of the declared type.** No
catch-all was refused, no warning was printed, and `list<int>` is as ordinary as a type gets.

## Why

`bs_types` represents a list as `{nil_flag, elem}` — empty-or-not, plus an element type. There
is **nowhere to put a length**. Measured, over `list<int>`:

| pattern | checker subtracts | actually matches |
|---|---|---|
| `[]` | the empty list | the empty list — agrees |
| `[a, ..t]` | all non-empty | all non-empty — agrees |
| `[a, b, ..t]` | all non-empty | length >= 2 — **over-subtracts, and this is the crash** |
| `[a, ..[]]` | nothing | length exactly 1 — **under-subtracts** |

The two forms TOUR §5 demonstrates are exactly the two the representation can express. Both
others are silently approximated, in whichever direction falls out — and one of those directions
is unsound.

The under-subtracting half is visible too: `[]` alone, `[]` plus `[a, ..[]]`, and `[]` plus
`[a, ..[]]` plus `[a, b, ..[]]` all leave the identical residual `[int, ..]`. Adding
closed-length clauses moves nothing.

## Question

**How much of list length does the algebra model?**

---

## Answer

**None of it. The algebra does not measure length — it decomposes the cons cell, and length
falls out.** That is candidate 5, which this ticket did not list, and it is what the only
surveyed language that gets this right actually does. The rest position becomes a **marker**, so
`[a, b]` means exactly-two and `..[]` is retired: **ticket 08 is reversed on that point.**

Six decisions, in the order they were taken.

### 1. The asymmetry with binaries is deliberate and now stated

[Ticket 30](30-binaries-as-a-parsing-grammar.md) already answered this question for the
structurally identical case and answered it the *other* way. `bin_part()` says so in its own
comment — *"Sizes are deliberately absent"* — and the consequence is a decided rule: a `_` over a
binary is always legal, a binary's residual is always open, a catch-all is always required.
**"The one sharp edge of this design, and it is deliberate."**

Lists get the opposite answer, and the reason is that the two sequences enter the language
differently. **A binary's size is erased by design** — `payload:size` binds a `binary` and nothing
downstream knows its length; there is no sized binary type and 30 refused one. **A list's length
is not erased: it is the pattern language's own discriminant.** `[a, ..[]]` shipped as a length
claim the checker then declined to read. That is a different failure from declining to model
something nobody can write, and 54 says so out loud rather than letting it contradict 30 silently.

### 2. Candidate 5 — decompose the cons — and candidates 1 and 2 are dominated

Four languages were run, not recalled. Same program in each:

| | catches it? | how it names the missing case |
|---|---|---|
| Erlang/OTP 28 | **no** — `erlc` silent, **Dialyzer passes** | — |
| Elixir 1.19.5 | **no** — compiles clean, crashes | — |
| C# 13 / Roslyn | **yes**, CS8509 | **`{ Length: 1 }`** — length as a *quantity* |
| Gleam 1.18.1 | **yes**, hard error | **`[_]`** — length as a *pattern* |

**Elixir is the finding that should sting.** It ships Castagna's set-theoretic type system — the
same theory `bs_types` rests on — and it has the identical hole, for the identical reason. This
is not a mistake the state of the art avoids; it is a hole the state of the art shares.

**Gleam does not solve it with a length.** Probed rather than assumed, and the decisive case is
`[] / [_] / [True, _, ..]` over `List(Bool)`, whose residual is **`[False, _, ..]`** — a length
and an element value in one pattern. No length interval can express that. Gleam's `List(Int)`
holds an element type and nothing else; length falls out of decomposing `Cons(head, tail)`
recursively. Confirmed at depth 3 (residual `[_, _]`), on closed composition (`[]`+`[_]`+`[_,_,..]`
is silently exhaustive), and on symptom five below, which Gleam does not exhibit.

**C# is candidate 2, living, and it works** — because `Length` is a real O(1) property of an
array, so the type system can name it and a programmer can write `{ Length: 1 }`. **beam-sharp has
no `Length`**: there is no `length` anywhere in the language — no guard, no refinement, no type
spelling. Candidate 2 would put a quantity in the algebra that nothing in the source language can
name, and it would still be **strictly weaker than candidate 5** on precisely the case
[ticket 53](53-a-route-table-needs-a-closed-list-pattern.md) exists to serve: a route table
discriminates on element values at positions, which is `[False, _, ..]`'s shape. Gleam prints the
residual for that table as four writable heads — `[]`, `[_]`, `[_, _]`, `[_, _, _, ..]` — which is
the property that makes a residual a clause you can paste. **Candidate 2 buys the machinery and
leaves the route table unchecked.** Candidates 1 and 2 are two rungs of a ladder that stops below
the height the language already advertises.

**The mechanism is already in the tree.** `product_minus/2` in `bs_types.erl` is the exact n-way
product-difference rule — `⋃ᵢ (A1∩B1) × … × (Aᵢ\Bᵢ) × … × An` — already exact, already recursive
through `subtract/2`, applied to tuples and maps today. A non-empty list is a product
`elem × list<T>`. Candidate 5 is that rule applied to a constructor the representation refuses to
treat as a product. **The new work is termination, not an algorithm.**

### 3. The rest is a marker, and `[a, b]` means exactly-two

Ticket 08 settled prefix-plus-rest with the rest as an ordinary pattern; ticket 53 discovered that
this made `..[]` legal — *"available the whole time"*, found by probing, never designed. Reopened
here with more insight, and reversed.

**`[a, b]` is what every reference language means by exactly-two, and B# was alone in refusing it.**
Run, not recalled:

| | `[a, b]` against `[1,2,3]` |
|---|---|
| Erlang | exactly two — `error:{badmatch,[1,2,3]}` |
| Elixir | exactly two — `MatchError` |
| C# 13 | exactly two — `[_, _]` rejects a 3-array |
| Gleam | exactly two |
| **B#** | **refused** — *"a list pattern needs a rest"* |

This was never a borrow-from-C# question. It is the one place the C# family and the BEAM family
**agree**, and B# diverged from both.

**And the refusal was worse than a divergence — it recommended a meaning change.** The diagnostic
says *"write `[h, ..t]`"*. Someone who writes `[a, b]` meaning exactly-two is told to write
`[a, b, ..t]`, which means two-or-more; and `[a, b, ..t]` is precisely the form decision 2 shows
the checker gets wrong. **This ticket's four-line repro is reachable by following the compiler's
own advice.** It is not a program written perversely; it is what you get by writing the obvious
thing and doing what you were told.

The new grammar, matching C# and Gleam:

```
[a, b]        exactly two
[a, b, ..]    two or more, tail discarded
[a, b, ..t]   two or more, tail bound to t
```

`..[]`, `..[b, ..t]` and `..== ys` become **ungrammatical**. Nothing is lost: `..[b, ..t]` is
`[a, b, ..t]`, `..[7]` is `[a, 7]`, and `..== ys` is a guard — the guard form was run and gives
identical results. **The repo contains no rest position holding anything but a variable, `_`, or
`[]`**, so the capability being deleted is used nowhere.

**And it makes candidate 5 terminate by construction**, which is what `bs_types.erl`'s warning
against a recursive list part was guarding: the unfold depth is `lists:max/1` over the prefix
lengths written in the clause set, with `..` meaning *stop here, fold the tail*. A syntactic,
finite, directly-readable number.

**The bound is per nesting level, not one flat number.** Over `list<list<int>>`, `[[a, b], ..]`
has an outer prefix of 1 and an inner prefix of 2, and the depths are independent — the bound
follows the element type down. Read literally as a single max it would unfold the outer spine two
deep and the inner one not at all, which is the over-subtraction this ticket exists to remove,
wearing a fix.

### 4. The grammar change is free — measured, with the harness self-tested

| grammar | `yecc:file/2` |
|---|---|
| current `bs_parser.yrl` | **0 conflicts, 0 warnings** |
| rest-as-marker | **0 conflicts, 0 warnings** |
| marker + fix-it error productions | **0 conflicts, 0 warnings** |
| control, deliberate ambiguity | **`error` — 1 reduce/reduce, state 104** |

The control is there because a quiet build proves nothing. With it, the zeros are a measurement.

**`[a, b]` needs no grammar change at all.** `plist_items -> pattern` already yields `Rest = nil`,
so `[a, b]` has always parsed — ticket 28 put C#'s collection spelling in deliberately and the
grammar comment names all three forms. **The refusal is one `erlang:error` in `bs_check`.** Half
of this decision is deleting four lines.

The retirement path was measured too, generated and run against the real lexer:

```
[a, ..[]]        REJECTED: `..[]` is retired -- a closed list is written `[a, b]`, with no rest
[a, ..[b, ..t]]  REJECTED: a rest is `..` or `..name` -- write the elements in the prefix instead
[a, b] / [a, b, ..] / [a, .._] / [] / [..t]      PARSE
```

**A second site**: `to_match` converts an *expression* list into a pattern for destructuring binds
and recurses into the rest. Restrict `plist_items` alone and `var [a, ..[]] = xs` survives, where
nobody will look for it.

### 5. The closed-residual catch-all rule applies to lists, with no exemption

A catch-all is legal only over an open residual — [ticket 12](12-totality-vs-let-it-crash.md) §2 —
and that rule is live and strict: over `bool` it is an error that names the missing case. Under
candidate 5 it reaches lists. `list<bool>` with clauses `[]`, `[a, b, ..]`, `_` leaves a residual
of *lists of exactly one bool*, which is `[:true]` and `[:false]` — **closed and inhabited**. Same
three clauses: a warning today, an error tomorrow, demanding `F([true])` and `F([false])`.

**Uniform, no list exemption.** The rule is written so the **residual** decides, never the type
constructor, and *"every value left here comes from a type you declared"* is exactly true of
`[:true]`/`[:false]`. Exempting lists would mean the algebra knows the residual is closed and the
checker deliberately looks away — the shape of the defect this ticket exists to remove.

One cost, taken knowingly: it bites on **closed element types** — `list<int>` and `list<string>`
are unaffected, since an unbounded element keeps the residual open.

**The second cost this ticket predicted does not exist — measured during F20 and corrected here.**
It warned that the rule would multiply against [ticket 43](43-residual-summarised-form.md)'s
`?RESIDUAL_CASES` cap: *"a four-atom union at length two is sixteen heads, so the cap starts doing
real work"*. It prints **two**:

```
F([:a | :b | :c | :d] | [:a | :b | :c | :d, :a | :b | :c | :d]) -> ...
```

A spine holds a union **at each position** rather than enumerating the cross-product, so a residual
grows with the number of missing *lengths*, not with the number of missing value combinations. The
cap is untouched and the residual is still a clause you can paste. The prediction was made from the
shape of the decision rather than from the representation, which did not exist yet.

### 6. There are five symptoms, not two, and the fifth is the worst

The ticket named the crash and the invisible closed clause. Three more were measured.

| # | symptom | status |
|---|---|---|
| 1 | `[]` + `[a, b, ..t]` proved exhaustive, crashes on `[7]` | in the ticket |
| 2 | `[]`, `[]`+`[a, ..[]]`, `[]`+`[a, ..[]]`+`[a, b, ..[]]` leave the **identical** residual | in the ticket |
| 3 | the residual `[int, ..]` cannot name a length, so the diagnostic cannot state the missing case | new |
| 4 | the refusal of `[a, b]` recommends a form with different semantics — see decision 3 | new |
| 5 | **a correct program is told it is wrong** | new |

Symptom 5, measured:

```csharp
Shape([])          -> :empty
Shape([a, b, ..t]) -> :many
Shape([a, ..t])    -> :one      // bsc: "clause 3 of Shape is unreachable"
```

`bsc` calls clause 3 unreachable. **`erlc` is silent** — and it is not shy, it emits its own
unreachable warning on the mirror-image module. And `Shape([7])` returns `:one`: **the clause the
compiler called unreachable is the clause that runs.** Gleam accepts the same three clauses in the
same order with no warning.

For the clean-room handoff this is the more damaging half. A fleet implementing from the spec does
not get a crash it can debug; it gets told a correct clause is dead, and deletes it.

## What must be built

**Built as [F20](../../compiler/features/F20-list-length.md), 2026-08-21.** The list kept below as
written; what actually changed, and the five things measured only during the build, are in the
feature file. The headline: the repro is now an error naming `Shape([int]) -> ...`, the route table
is written `["orders", id]` and checked, and 458 tests pass.

1. **`bs_types`** — the list part gains a spine. A non-empty list is a product `elem × tail`,
   subtracted by the existing `product_minus/2`; the fold marker terminates it. `l_open/1` and
   `l_str/1` follow.
2. **`bs_parser.yrl`** — `plist_items -> '..' | '..' '_' | '..' lident`, plus the two fix-it error
   productions, plus the same restriction inside `to_match`.
3. **`bs_check`** — delete the `list_pattern_needs_rest` raise; `Rest = nil` becomes *closed*
   rather than an error. `pattern_type` for `p_list` credits per-prefix instead of `cons(term())`.
4. **`bs_diag`** — the residual prints as writable heads (`[int]`, `[int, int, ..]`), and the
   orphaned `list_pattern_needs_rest` message clause is deleted with its tag.
5. **tree-sitter** — `rest_pattern` becomes a marker, and `grammar.json`, `node-types.json` and
   `parser.c` are **regenerated**; editing `grammar.js` alone leaves three committed artifacts stale.

## The gate

**A new gate, `check-list-length.sh`** — not `<!-- check: -->` blocks in LANGUAGE.md. Measured
reason: `bsc` **exits 0 on a warning-only module**, so a doc block, which asserts only that a
block compiles, cannot see probe 3.

Three probes, asserted on the diagnostic and not the exit code:

1. `[]` + `[a, b, ..]` is **inexhaustive**, and the residual **names `[int]`**. Asserting the
   residual text is what separates candidate 5 from candidate 1's *make the repro red*.
2. `[]` + `[a]` + `[a, b, ..]` is **exhaustive and silent** — the composition half, and the probe a
   fires-on-everything check would fail.
3. `[]` + `[a, b, ..]` + `[a, ..]` produces **no unreachable warning** — symptom 5, which no other
   probe covers and no doc block can express.

**`--self-test` needs two stubs, not one.** A checker crediting every cons as all-non-empty fails
1 and 3 and passes 2; a checker crediting nothing for a cons fails 2 and passes 1. One stub proves
the gate sees one direction, and this ticket's whole warning is that the two directions have one
root and get fixed independently.

## Blast radius — measured

| | count |
|---|---|
| `..[]` in **live B# source** | **4 lines**, all `examples/exemplars/25a-http-api-server/route.bs:12-15` |
| `..[]` in `compiler/test/` | **zero** |
| multi-element prefix cons in `compiler/test/` | **zero** — every list pattern in the suite is single-element |
| rest holding anything but a var or `_` | **4**, all `..[]` |
| tests asserting the residual string `[int, ..]` | **zero** |
| tests covering `list_pattern_needs_rest` | **zero** — but `check-diagnostics.sh` covers its deletion in both directions |
| `..[]` in prose (LANGUAGE.md, wayfinder, exemplar READMEs) | ~30 |
| stale comments asserting the old rule | **1** — `compiler/test/lists_tests.erl:12-13`, *"Ticket 08 settled prefix-plus-rest only"*, now false. No gate reads a comment, so it has to be fixed by hand |

**One confirmed red gate**: `check-language.sh`. LANGUAGE.md's `Dispatch` block is an untagged
` ```csharp ` block containing both `..[]` forms, and it goes red the moment `..[]` is illegal.

**`check-exemplar-frontier.sh` is not at risk** — checked rather than assumed: `create_order.bs`
sorts before `route.bs` and already fails at the lexer, so it stays the first diagnostic and the
`FRONTIER` record holds.

**A trap that turned out not to be one — corrected 2026-08-21 during F20.** This ticket claimed
that deleting `list_pattern_needs_rest` would leave its `message/1` clause orphaned unseen, because
`check-diagnostics.sh` asserted only that every minted tag has a message. **That is false**, and it
was written from a summary rather than from the file. The gate checks *both* directions — its
third section reports *"message/1 renders tags descriptor/2 never mints"*, and it carries a control
that builds exactly that defect. The dead-diagnostic sweep was already automated. The lesson is the
one this repo keeps relearning: a claim about a gate is worth no more than the last time someone
opened it.

## Premises measured

Three of this ticket's own claims were checked before anything was decided. The repro crashes as
written; the three closed-length clause sets do leave an identical residual; the defect site is
one clause in `bs_check`. **The fourth is false**: *"449 tests pass today with the wrong behaviour.
Some may encode it"* — **none do**. The suite contains no multi-element prefix cons and no `..[]`
at all, so the wrong behaviour is not encoded anywhere in it. What the suite has instead is a
**hole**: nothing tests the diagnostic this ticket deletes.

## Consequences for other tickets

- **[Ticket 53](53-a-route-table-needs-a-closed-list-pattern.md) is answered.** Its surviving
  question was the read cost of `..[]` — *"punctuation neither audience recognises"* — parked
  behind this one because sugar over a form the checker cannot see would make the surface read
  like C# while the guarantee stayed absent. Both halves land together: the checker sees the form,
  and the spelling becomes `["orders", id]`. **It is not sugar** — `[a, b]` is the primary
  spelling and `..[]` is gone, not deprecated.
- **[Ticket 08](08-head-and-guard-syntax.md) is amended.** Prefix-plus-rest survives; *the rest is
  an ordinary pattern* does not.
- **[Ticket 30](30-binaries-as-a-parsing-grammar.md) stands.** Binaries keep the opposite answer
  and now have a stated reason rather than an accident of two tickets not meeting.

## Decisions entry

<!-- This ticket's entry. wayfinder/decisions.md is GENERATED from blocks like this
     one and carries only the first sentence; the whole entry is read here. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [List length in the algebra: a proved-exhaustive program that crashes](issues/54-list-length-in-the-algebra.md) —
  **the algebra models none of it, because it decomposes the cons cell instead of measuring it.**
  That is a fifth candidate the ticket did not list, and it is what the one surveyed language that
  gets this right actually does. Four languages were run rather than recalled: **Erlang does not
  catch it** (`erlc` silent, **Dialyzer passes**), **Elixir 1.19.5 does not catch it** — which is
  the finding that should sting, since it ships Castagna's set-theoretic types, *the same theory
  `bs_types` rests on*, and has the identical hole for the identical reason — **C# catches it and
  names `{ Length: 1 }`**, **Gleam catches it and names `[_]`**. The two that work disagree only on
  vocabulary, and the disagreement follows the data structure: a C# array has an O(1) `Length` to
  talk about, a cons chain has none. **beam-sharp has no `Length` either** — there is no `length`
  anywhere in the language, no guard, no refinement, no type spelling — so candidate 2 would put a
  quantity in the algebra that nothing in the source can name. **And candidate 2 is dominated**:
  Gleam's residual for `[] / [_] / [True, _, ..]` is `[False, _, ..]`, a length and an element value
  in one pattern, which no interval can express and which is exactly the shape a route table needs.
  Candidate 2 buys the machinery and leaves ticket 53's table unchecked. **The mechanism was already
  in the tree**: `product_minus/2` is the exact n-way product-difference rule, already recursive
  through `subtract/2`, applied to tuples and maps and simply never to the cons cell — so the new
  work is termination, not an algorithm. **The rest position becomes a marker and `[a, b]` means
  exactly-two**, reversing ticket 08 on that point and retiring `..[]`. This was never a
  borrow-from-C# question: **`[a, b]` is exactly-two in Erlang, Elixir, C# and Gleam alike** — the
  one place the two families agree — and B# alone refused it. **The refusal was worse than a
  divergence, because it recommended a meaning change**: *"write `[h, ..t]`"* turns an exactly-two
  pattern into a two-or-more one, and that is precisely the form the checker gets wrong — **the
  four-line repro is reachable by following the compiler's own advice.** Marker-rest also makes the
  decomposition terminate by construction, which is what `bs_types.erl`'s warning against a
  recursive list part was guarding: unfold depth is `lists:max/1` over the prefix lengths written.
  **Measured free**: `yecc:file/2` reports 0 conflicts on the current grammar, 0 on marker-rest, 0
  with fix-it error productions added, against a control that reports 1 reduce/reduce — and **`[a,
  b]` needs no grammar change at all**, since `plist_items -> pattern` already yields `Rest = nil`
  and the refusal is one `erlang:error` in `bs_check`. **Ticket 12 §2 reaches lists with no
  exemption**: a `list<bool>` residual of exactly-one-bool is closed and inhabited, so a catch-all
  over it becomes an error naming `[true]` and `[false]` — the residual decides, never the type
  constructor. It bites only on closed element types, and it makes ticket 43's cap do real work.
  **Five symptoms, not two**, and the new fifth is the worst: `[] / [a, b, ..t] / [a, ..t]` has
  clause 3 reported **unreachable** while `erlc` stays silent and `Shape([7])` returns `:one` —
  *the clause the compiler called dead is the clause that runs*, which for the clean-room handoff is
  more damaging than a crash, since a fleet deletes it. **One of this ticket's own premises was
  false**: *"449 tests pass today with the wrong behaviour, some may encode it"* — **none do**; the
  suite has no multi-element prefix cons and no `..[]` at all. What it has is a hole, since
  **nothing tests the diagnostic this deletes**, and `check-diagnostics.sh` only checks that every
  tag has a message, so an orphaned message stays green forever. Blast radius in live source is
  **four lines** (`25a/route.bs`), plus one confirmed red gate — LANGUAGE.md's `Dispatch` block is
  untagged and must compile.
```
