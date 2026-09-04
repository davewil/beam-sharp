# F29 — the residual prints a pattern: the printer half of ticket 42 and F22

**Status**      **shipped 2026-08-27** — spec written 2026-08-27 ·
                [ENG-266](https://linear.app/davewil/issue/ENG-266). **§1 and §2 were not
                built**, and were not skipped: they turned out not to be needed. See
                "The two decisions in this file", corrected in place below.
**Implements**  [42](../../wayfinder/issues/42-interval-pattern-spelling.md) (a span is a relational
                pattern), [55](../../wayfinder/issues/55-destructure-and-bind.md)/[F22](F22-record-pattern-and-binder.md)
                (a record pattern may name its type), ticket 23 §2 (the lowering). **Decides two
                new things** — see "The two decisions in this file".
**Unblocks**    `check-residual-pasteable.sh` going green ([ENG-263](https://linear.app/davewil/issue/ENG-263),
                which owns the gate and is written first), and six documented diagnostics becoming
                replayable
**Depends on**  F22 (the type-prefix pattern this emits), ticket 42 (the relational pattern this
                emits), ticket 12 §2 (the rule §"The two decisions" extends)

## Why this one now

**Because two surface decisions shipped without their printer, and the symptom has now been
rediscovered three times.**

Ticket 42 settled on 2026-08-15 that an interval residual synthesises as `Classify(<= -1)` —
*"a pattern, with no binder and no guard"* (ticket 42's entry, `wayfinder/issues/42-interval-pattern-spelling.md`) — and the parser was built for
it, in as many words:

> `%% The bound is a LITERAL, and negative bounds are the case that makes this its`
> `%% own nonterminal:` `Classify(<= -1)` `is the residual's own spelling for the`
> `%% negative half of` `int`, `so the diagnostic 23 §2 synthesises has to be`
> `%% something the parser accepts back.` — `bs_parser.yrl`, the comment above the `int_lit`
> productions

Ticket 43 §0 then measured the printer still emitting `Classify(int <= 9 | 11..19 | …)` and recorded
23 §2's lowering as **unbuilt**. F22 shipped the type-prefix record pattern on 2026-08-22; its "what
the compiler gains" lists grammar, AST, checker and emitter, and **`bs_types:to_pattern/1` is not
among them**. ENG-263 then filed the symptom on 2026-08-27 as a discovery.

**That is the shape of this feature's risk, and it is why §"What the compiler gains" below names the
printer explicitly.** A printer is not part of the surface being added, so nothing greps for it and
an F-file's delta list is exactly where it goes missing.

**What makes it now rather than earlier**: the promise is load-bearing in the README.
`README.md:26-28` says the compiler *"hands back the clause head you have not written, **in the
syntax you would write it in**. That is the whole bet of the language."* Round-tripped, one shape in
six survives contact with that sentence.

## Where it starts

Measured 2026-08-27 against a clean clone at `00c9815`. Take the suggested head, paste it back,
recompile:

| Shape | Printed today | Pastes? |
|---|---|---|
| atom union | `Code(:blue) -> ...` | clean |
| bool | `Flag(:false) -> ...` | clean |
| product | `Pair(:false, :false) -> ...` | clean |
| record | `Area({ Kind: :'B2.Tri' }) -> ...` | **compiles, wrong spelling** — see below |
| interval | `Band(0..10) -> ...` | `syntax error before: '..'` |
| interval + prefix | `Classify(int <= 199) -> ...` | `syntax error before: '<='` |
| union in one head | `Classify(… \| …) -> ...` | `syntax error before: '\|'` |
| **list of records** | `Ship([{ Kind: …, Id: int, Total: int }]) -> ...` | **`repeated_in_head`** |

Two rows need reading twice.

**The record row compiles and is still wrong.** `{ Kind: :'B2.Tri' }` is the hand-written form F22
was written to replace — its own comment says writing the minted tag by hand *"makes an erasure
detail load-bearing in source"* (`bs_parser.yrl`, the ticket 55 / F22 comment above `p_rec`).
**A gate that only asked "does it
compile" would bless this row**, which is why ENG-263's gate asserts the spelling and not only
parseability.

**The list row fails hardest and is the F3 bug reached by a new route.** `int` is a lowercase name
in pattern position, so it binds a variable, twice — `bs_check`'s `head_scope/3` raises
`repeated_in_head`. `to_pattern/1`'s own header in `bs_types` says the discriminator form exists
precisely to prevent this. The cause is one line: `pat_parts/1` has pattern-side variants for
tuples (`ts_pat`) and maps (`ms_pat`), but **not for lists** — it reuses `l_str/1`, whose element
printer `sp_items/1` is hardwired to `to_string`.

## One function, two jobs, nine sites

`to_pattern/1` is rendered into nine diagnostic fields, and they do not all have the same job.

Each site is named by the **diagnostic tag** whose `descriptor/2` clause holds the field, because a
tag is stable and a line number is not: this table was first written with line numbers, and by
2026-09-02 every one of the fifteen in this file pointed at something else.

*(Corrected 2026-09-02, ENG-276. The count read **eight** and the `rejected` row covered two call
sites in one line, so the table said eight and enumerated nine. Both `rejected` sites are now
listed, because they belong to different diagnostics — one is an argument a callee refused, the
other a value a record refused.)*

| Site — `descriptor/2` clause for | Field | Job |
|---|---|---|
| `switch_inexhaustive` | `arm` | **description** — already declared so, see below |
| `valve_on_infallible` | `subject` | description |
| `arg_not_accepted` | `rejected` | description — an argument the callee refused |
| `field_value_not_accepted` | `rejected` | description — the same field, a value a record refused |
| `field_absent` | `member` | description |
| `return_not_declared` | `undeclared` | description |
| `bind_may_fail` | `unmatched` | description |
| `arg_not_accepted` | `caller_head` | **paste** |
| `inexhaustive`, `catch_all_over_closed` | `heads` / `pasteable` | **paste** |

The split is already half-discovered. `switch_inexhaustive` deliberately does not route through the
head printer at all — the comment above `message/1`'s `switch_inexhaustive` clause in `bs_diag`:

> *"Deliberately NOT routed through the head printer: that prints `Fn(:cancelled) -> ...`, and a
> switch has no function name and its arrow is `=>`."*

**So the deliverable is the split, not a patch to the renderings.** `to_pattern/1` keeps its meaning
and its callers for the description sites; a new head printer serves the paste sites. Each of the
nine declares which it is, in source, once.

**That split has since happened, and it is visible in the call graph.** `to_pattern/1` is now
reached from the seven description fields only; the two paste fields are served by `heads/3` and
`caller_head/3`. A reader counting `to_pattern` call sites in `bs_diag` today finds seven, not
nine, and the difference is exactly this feature.

## The two decisions in this file

Recorded here because they were taken on 2026-08-27 and this is where the work lands. **Both are
language-surface decisions living in an F-file rather than a ticket** — `map.md`'s index will not
see them, and that is a known cost, flagged rather than absorbed.

**§1 — A pattern may carry a generic type and a binder. NOT BUILT, and not needed.**

**Corrected 2026-08-27, when the feature was built.** The measurement below stands — the narrow
form is 0/0 and the wide form is six reduce/reduce — and the production was still not added,
because the case it was for does not arise.

§1's argument is *"a list pattern constrains a prefix … nothing spells every element"*. That is a
ONE-HEAD argument, and **F29.2, four sections down in this same file, made a residual N heads.**
Once it is N heads, the folded `list<Order>` residual is what it always was in the algebra —
`[] | [Order, ..]` — and it prints as the two clauses an author actually writes:

```csharp
Ship([]) -> ...
Ship([Order o, ..]) -> ...
```

Both are grammatical today. Measured 2026-08-27: pasted back together they drive the residual to
`none` and the module compiles clean. What made the production look necessary was `l_str/1`'s
FOLD — it rejoins `[] | [T, ..]` into `list<T>` so an ordinary list type does not read like a
residual — being inherited by the head channel, where it collapses two spines that each have a
pattern into one that has none. The head channel does not inherit the fold; that is the whole fix,
and it is four lines rather than a grammar change, an AST node, a checker case and an emitter case.

A fixture holds it: `bin/fixtures/residual/WholeList/` is the only roster shape that reaches the
folded residual, and it was added in this commit because the gate had no row for it. Without it
the production would have shipped measured, built, and emitted by nothing.

**It also deleted a soundness question this file never asked.** `list<Order> xs` has no Erlang
pattern; the runtime test is `is_list`, which cannot tell `list<Order>` from `list<Invoice>`. A
`p_typed` checker case would have needed a width rule to stay sound, and §1 does not specify one.

The measurement, kept because it is the reason a wider form is still refused:

```
pattern -> lident '<' type_list '>' lident      // list<Invoice> invs
pattern -> uident '<' type_list '>' lident      // Pair<int> p
```

**Measured, not inferred.** `yecc:file/2` over three grammars on 2026-08-27:

| Grammar | Shift/reduce | Reduce/reduce | Result |
|---|---|---|---|
| `bs_parser.yrl` at `00c9815` | 0 | 0 | baseline |
| `pattern -> type_prim lident` (wide) | 0 | **6** | **does not build** |
| the two productions above (narrow) | 0 | 0 | clean |

The wide form's conflicts are in the leaves: `type_prim -> atom_lit` against `pattern -> atom_lit`,
and `type_prim -> lident` against `pattern -> lident`, unresolvable at the `,` and `}` boundaries —
the parser cannot tell whether `:ok` or `x` begins a type annotation or *is* the pattern.

**The restriction that makes it build also deletes a hazard.** Excluding the bare type name means
`Classify(int n)` — a catch-all wearing a type — never exists. This is why `int n` is *not* in scope
here despite reading like the obvious companion case.

It cannot reuse `p_rec`: `list<Invoice>` is not a record. It needs a new AST node, `p_typed`, with
cases in `bs_check` and the emitter.

**§2 — Ticket 12 §2 extends to the type-annotated binder. MOOT, not unimplemented.**

**Corrected 2026-08-27.** §2 existed to refuse `Ship(list<Invoice> invs)` over a closed residual —
*"a catch-all wearing a type"* that pastes, compiles, is exhaustive and hides an enumerable case.
With §1 not built there is no such pattern to write, and the head the printer emits in its place —
`Ship([])` beside `Ship([Invoice i, ..])` — discriminates on the spine and hides nothing. The
hazard is deleted rather than guarded.

If §1 is ever wanted for its own sake, §2 is its precondition and this paragraph is the record of
why: the rule was designed before the production, and the production was dropped first.

## What the spec had wrong, found by building it

Three, all measured 2026-08-27 and all corrected in place above or below.

**1. `TupleNested` is not a `syntax:<=` row.** "Where it starts" records it as a parse failure. It
parses. `Step((:ok, <= 0))` is refused on MEANING — *"a relational pattern goes where a whole
argument goes … write the comparison as a guard there"* — and the diagnostic names the fix. So a
span at argument position is ticket 42's pattern and a span below it is a **binder plus a hoisted
`when` clause**, which this file did not anticipate and which `i_pat/2` now decides on position.
The printer was emitting a form its own checker rejects.

**2. The gate's paste-back was self-contradictory.** `check-residual-pasteable.sh` pasted
`head -n 1` and demanded rc 0, while its `channels()` asserted `ManyHeads` carries five heads. No
correct compiler satisfies both. It was unreachable before F29 because the `|`-joined head did not
parse, so every multi-head shape stopped at `syntax:|`. Corrected there, dated, with the roster
grown to eleven.

**3. F29.9 is per PRODUCT, not per residual.** A residual can be part spellable and part not:
`Classify(int n, atom a)` leaves one product with forty-one heads and forty whose atom component is
`atom \ (:x)`. Emitting only the heads is a diagnostic wrong by omission, so both keys are carried
and both are capped by ticket 43's rule. Building this also found `{cofinite, []}` — *every* atom,
which a binder spells — being treated as unspellable alongside `{cofinite, [:x]}`, which turned a
forty-one-head diagnostic into a wall of type notation.

**4. `caller_head` was the last site and it was broken the same way.** This file's table names
`arg_not_accepted`'s `caller_head` a **paste** site, and it was reading `to_pattern/1`. So an interval residual
printed `F(int <= 5, _) -> ...` under the heading *"the clause to add here"* — a head that does not
parse, at the one place a reader is most likely to paste from. Nothing had found it, for this
feature's own stated reason: a printer is not part of any surface being added. It now returns a
LIST through the head channel, and `none` where no part of the residual has a pattern, which makes
23 §2's *"where the residual is not expressible the term says so and offers nothing"* reachable
rather than aspirational. The record name reaches it through `head_hint/2` rather than a sixth
element on `arg_not_accepted`, which leaves that diagnostic's shape alone.

## Scenarios

Each is input, command, expected output, exit code.

**F29.1 — an interval residual round-trips.** Over `public Status Classify(int)` with clauses
covering `>= 200 and < 300`, `>= 400 and < 500`, `>= 500`, the printed head is pasted back and the
module compiles clean. The head must contain no `int` prefix and no `..`.

**F29.2 — an interval union prints N head lines.** The residual `int <= 199 | 300..399` prints two
head lines, not one:

```csharp
Classify(<= 199) -> ...
Classify(>= 300 and <= 399) -> ...
```

`or` is available in `rel_pattern` (`bs_parser.yrl`'s `rel_pattern -> rel_pattern 'or' rel_pattern`
production) and is **deliberately not used** — a
line mixing `or` with `join/2`'s `|` truncation would read as two different alternations at once.
Ticket 43's cap counts lines.

**F29.3 — a record residual names its type where the name resolves at the error site.** F22's
spelling, not the discriminator:

```csharp
Area(Tri t) -> ...
```

**F29.4 — and falls back to the discriminator where it does not.** `bs_diag` currently receives a
bare residual, so this scenario is the one that needs plumbing: a reverse map from the minted tag
atom to the source type name, and the set of names `using` brought into scope at that line. Where
the name does not resolve, `{ Kind: :'Shop.Invoice' }` is correct and stays.

**F29.5 — a record inside a list prints a pattern, not a type.** `Ship([Invoice i]) -> ...`, which
has been grammatical since F22 and which the printer has never emitted. Pasted back it compiles;
today it raises `repeated_in_head`.

**F29.6 — an open list of records prints the new binder.** `Ship(list<Invoice> invs) -> ...`, via
§1. This is the scenario the grammar change exists for: a list pattern constrains a *prefix*, so
`[Invoice i, ..]` says "the first one is an Invoice" and nothing spells "every element".

**F29.7 — 12 §2 refuses the over-wide binder.** §2's rule. `Ship(list<Invoice> invs)` over a closed
`[Invoice]` residual is an error with 12 §2's wording, not a passing exhaustive function.

**F29.8 — the bare type words leave the head channel, and stay in `to_string`.** `int`, `tuple`,
`map`, `string`, `binary` and ticket 61's `term` are no longer emitted as heads. **Ticket 61 keeps
its answer for `to_string/1`** — this narrows 61 to the description channel and does not overturn
it. A diff that changes what `to_string` prints has gone too far.

**F29.9 — the description channel is never rendered as a head.** `binary \ string`
(which `bs_types`' `b_str/1` renders, and which has no surface spelling — `b_str/1` says so) and a cofinite atom set are
carried on a separate field and rendered with wording that does not invite a paste. The `pasteable`
key is absent, not empty.

**F29.10 — the prose is a prefix of the term channel.** `bs_diag`'s comment on `heads_prose/2` used
to claim the two *"cannot say different things"*. That was true on content and **false on
completeness**: `pasteable/3` joined at `infinity` while the prose capped at three, from two
separate expressions. This feature made them one expression, so the cap is now the only difference
between them and the prefix property holds by construction. The scenario asserts the prose head
lines are the term list's first three plus the `... (N more)` line.

*(Corrected 2026-09-02, ENG-276: this paragraph described the defect in the present tense after
the fix had shipped, and called the function `pasteable/2` — it is `pasteable/3`.)*

**F29.11 — the seven description sites keep type notation.** `rejected`, `member`, `undeclared`,
`unmatched`, `subject` and the switch `arm` are unchanged by this feature. A diff that alters their
text has confused the two jobs the split exists to separate.

**F29.12 — the six display sites replay.** `README.md:22`, `TOUR.md:150`, `TOUR.md:172`,
`LANGUAGE.md:352-356`, `LANGUAGE.md:513` and `compiler/examples/Wire/wire.bs:8-16`. Their expected
text moves when the printer changes. *Replayed since 2026-09-02*: the four TOUR transcripts and the
two LANGUAGE.md sites carry an `<!-- expect-after: … -->` directive naming the edit that produced
them, and `check-tour.sh` / `check-language.sh` apply it to a copy and compare; `wire.bs:15`'s
sentence is run by `check-residual-pasteable.sh`'s mutation stage. The first replay of the
LANGUAGE.md §3 site found it wrong twice over — a bound the printer does not produce and a line
number from a file that does not exist. `README.md:22` is ENG-264's.

## What the compiler gains

Named explicitly, because this is the section F22 was missing when it left this feature undone.

**This list was written before the build and three of its bullets did not happen.** §1 and §2 were
not built — see the Status line and "The two decisions in this file" — so `p_typed` does not exist
in the AST, `bs_check` gained no case for it and no subtype test, and the emitter gained no case
either. `bs_parser.yrl` gained nothing. The `bs_types` and `bs_diag` bullets are what shipped.
*(Recorded 2026-09-02, ENG-276; the `bs_check` bullet also carried a source line that had drifted.)*

- **`bs_types`** — a head printer split out from `to_pattern/1`; `i_pat/1` beside `i_str/1`;
  `l_pat`/`sp_pat`/`sp_items_pat` beside the `_str` triple; `m_pat/1` reached from the list path;
  the type-word leaves removed from the head side only.
- **`bs_parser.yrl`** — the two productions in §1. Nothing else. The measured conflict count is
  0/0 and a build that reports otherwise means the productions were widened.
- **AST** — `p_typed`, new.
- **`bs_check`** — *(not built: a case for `p_typed`, and §2's subtype test)*; a reverse map
  from minted tag atom to source type name, and the scope set, threaded to the diagnostic for F29.4.
- **Emitter** — a case for `p_typed`.
- **`bs_diag`** — each of the eight sites declares head or description; the description channel as
  a distinct field.

## The gate

**Owed by [ENG-263](https://linear.app/davewil/issue/ENG-263), and written before this feature** —
per the standing rule, and because a check written after the code is written to agree with it.

`compiler/bin/check-residual-pasteable.sh` walks the fixtures corpus at
`compiler/bin/fixtures/residual/`, extracts the suggested head(s) from the **term** channel, pastes
the first back with a body and records the compiler's output **and its exit status**. It asserts the
**preferred** spelling, not only that the text parses — without that it certifies the record row in
§"Where it starts". Its floor is a **shape roster**, not a count: atom, interval, interval-union,
record, record-in-list, tuple-nested, open-list, binary, top, many-heads. A shape the roster names
and the run never saw is red; so is a result the roster does not name, which is what stops the
verdict function degenerating into a lookup table on fixture names.

The exit status is recorded because an empty `.paste` looks identical whether the compiler said
nothing or was never invoked, and this repo has already shipped a check that asserted an absence
against a run that never compiled. `unrun` is a verdict, and `cry_wolf` is the stub that holds it.

**Built 2026-08-27 without the `examples/Wire` mutation stage; the stage landed 2026-09-02.** The
fixtures corpus is the spine and stands alone. The mutation stage deletes each `Classify` clause of
`wire.bs` in turn, reads the residual off the term channel and pastes it back with the clause's own
body, against a second verdict table: six clauses come back as *the same line* — `wire.bs:15`'s
sentence, now run rather than believed — and the open span `Classify(>= 9)` comes back closed on
the domain's top, recorded as `respelled`. The `expect-after` directive that replays the display
sites landed the same day; neither remains open on ENG-263.

`--self-test` drives the verdict function over fabricated diagnostic text — no compiler rebuild —
with five stubs: type-notation (red), the correct form (green), silent (red), cry-wolf (red), and
**over-informed** (red): a stub that knows the right answer for the cases the gate was written
against and type notation for one it was not. The last is the only control that catches a gate whose
verdict is a lookup table of expected strings.

**Corrected 2026-08-27, when the gate was built.** This section said *"F29 is done when that gate
is green"*. **The gate is already green** — and it has to be, because a gate that is red on master
from the moment it lands until F29 ships is one nobody can act on. Its floor is a per-shape
**expected-verdict table**: every shape carries the verdict it produces *today* (`clean`,
`spelling`, `syntax:TOK`, `binds`), and the gate is red if any shape moves **in either direction**.
That guards the shapes that already work, records the six that do not, and makes this feature's
completion checkable:

> **F29 is done when every entry in `expected` in `check-residual-pasteable.sh` reads `clean`.**

A shape that starts pasting is red exactly as loudly as one that stops, so F29's commit must empty
the table in the same change that fixes the printer. The gate was seen red on today's compiler in
both directions and on a missing fixture before it was believed.

**The roster is ten, not nine.** `many-heads` was added: it is the only fixture that reaches the
prose cap, and therefore the only one that can test `heads_prose/2`'s claim that the prose
and term channels *"cannot say different things"* — true on content, **false on completeness**, and
untested until now. Its residual is five heads; the prose prints three and `... (2 more)`.

## Out of scope

- **Deciding whether `..` should have been the span spelling.** Ticket 42 refused it on 2026-08-15
  on meaning, not ambiguity — *"borrow the construct, or don't borrow the glyph"*. The printer
  moves. Reopening 42 is a ticket.
- **`Invoice[]` as a list type spelling.** Raised 2026-08-27 and **never previously considered** —
  grepped across `decisions.md`, `map.md`, `issues/`, `features/`, `LANGUAGE.md` and `CONTEXT.md`;
  every hit is variadic `params T[]`, `byte[]` binary modelling, or C# slice *patterns*. Not
  refused — never raised. It is a type-surface question with a live argument against it (a C# array
  has the O(1) `Length` ticket 54 refused to model, `issues/54-...:106`), and it does not gate this
  feature. → a ticket.
- **`pattern -> type_prim lident` in general.** Measured at six reduce/reduce conflicts. If the
  wide form is ever wanted, it needs the grammar restructured, not the production widened.
- **`int n` as a pattern.** Excluded by §1 deliberately, not by oversight.
- **Truncation as a tunable.** Ticket 43 settled *"no tunable, no flag, no switch"* and the term
  channel is already uncapped, so nothing here needs one.
- **The `switch_inexhaustive` arm gaining a pasteable head.** The comment above `message/1`'s
  `switch_inexhaustive` clause refused it with a reason that still holds: a switch has no function
  name and its arrow is `=>`.
- **README's gating.** [ENG-264](https://linear.app/davewil/issue/ENG-264) owns it; F29.12 moves the
  text, not the gate that would catch it moving.

## Done when

**Every entry in `expected` in `check-residual-pasteable.sh` reads `clean`** — met 2026-08-27,
across **eleven** shapes rather than ten: `WholeList` was added because nothing in the roster
reached the folded list residual. The six that did not paste were `Interval`, `IntervalUnion`,
`TupleNested`, `RecordInList`, `BinTag` and `ManyHeads`, plus the three that compiled with the
wrong spelling (`RecordUnion`, `OpenList`, `TopString`). `Ship(list<Invoice> invs)` is **still a syntax error** — §1 was not
built, see above — `to_string/1` prints exactly what it printed before,
`Classify(int n)` is still a syntax error, the display sites replay, and
`check-residual-pasteable.sh --self-test` has been seen red on all five stubs — including the
over-informed one — with a green on the correct form beside them.

**Two rows compile and are still wrong, not one.** §"Where it starts" recorded only the record row.
`OpenList` — `Shape([int])` — compiles clean at rc 0: `int` is lowercase in pattern position, so it
is a *binder named int*, and for `list<int>` the declared parameter type already constrains the
element, so the pasted clause even behaves correctly. That is why nothing caught it. `TopString` is
the same defect without a list. Measured 2026-08-27.
