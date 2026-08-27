# F29 — the residual prints a pattern: the printer half of ticket 42 and F22

**Status**      **not started** — spec written 2026-08-27 ·
                [ENG-266](https://linear.app/davewil/issue/ENG-266)
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
*"a pattern, with no binder and no guard"* (`decisions.md:991-993`) — and the parser was built for
it, in as many words:

> `%% The bound is a LITERAL, and negative bounds are the case that makes this its`
> `%% own nonterminal:` `Classify(<= -1)` `is the residual's own spelling for the`
> `%% negative half of` `int`, `so the diagnostic 23 §2 synthesises has to be`
> `%% something the parser accepts back.` — `bs_parser.yrl:462-465`

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
detail load-bearing in source"* (`bs_parser.yrl:499-501`). **A gate that only asked "does it
compile" would bless this row**, which is why ENG-263's gate asserts the spelling and not only
parseability.

**The list row fails hardest and is the F3 bug reached by a new route.** `int` is a lowercase name
in pattern position, so it binds a variable, twice — `bs_check.erl:1250` raises `repeated_in_head`.
`to_pattern/1`'s own header (`bs_types.erl:1030-1040`) says the discriminator form exists precisely
to prevent this. The cause is one line: `pat_parts/1` has pattern-side variants for tuples
(`ts_pat`) and maps (`ms_pat`), but **not for lists** — it reuses `l_str/1`, whose element printer
`sp_items/1` is hardwired to `to_string` (`bs_types.erl:965`).

## One function, two jobs, eight sites

`to_pattern/1` is rendered into eight diagnostic fields, and they do not all have the same job:

| Site | Field | Job |
|---|---|---|
| `bs_diag.erl:171` | `arm` (switch) | **description** — already declared so, see below |
| `bs_diag.erl:174` | `subject` | description |
| `bs_diag.erl:192`, `:208` | `rejected` | description — an argument the callee refused |
| `bs_diag.erl:213` | `member` | description |
| `bs_diag.erl:221` | `undeclared` | description |
| `bs_diag.erl:226` | `unmatched` | description |
| `bs_diag.erl:1151` | `caller_head` | **paste** |
| `bs_diag.erl:1091-1106` | `heads` / `pasteable` | **paste** |

The split is already half-discovered. `switch_inexhaustive` deliberately does not route through the
head printer at all (`bs_diag.erl:566-568`):

> *"Deliberately NOT routed through the head printer: that prints `Fn(:cancelled) -> ...`, and a
> switch has no function name and its arrow is `=>`."*

**So the deliverable is the split, not a patch to the renderings.** `to_pattern/1` keeps its meaning
and its callers for the description sites; a new head printer serves the paste sites. Each of the
eight declares which it is, in source, once.

## The two decisions in this file

Recorded here because they were taken on 2026-08-27 and this is where the work lands. **Both are
language-surface decisions living in an F-file rather than a ticket** — `map.md`'s index will not
see them, and that is a known cost, flagged rather than absorbed.

**§1 — A pattern may carry a generic type and a binder.** One production, admitted narrowly:

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

**§2 — Ticket 12 §2 extends to the type-annotated binder.** A `p_typed` binder whose type is
strictly wider than the residual, over a **closed** residual, is the same defect as `_` and gets the
same error. Without this, `Ship(list<Invoice> invs)` over a residual of `[Invoice]` — a list of
exactly one — pastes, compiles, is exhaustive, and hides an enumerable case. That is precisely what
12 §2 exists to prevent, in a form harder to spot. The test goes where one already runs,
`bs_check.erl:2302`.

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

`or` is available in `rel_pattern` (`bs_parser.yrl:454-455`) and is **deliberately not used** — a
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
(`bs_types.erl:1006-1009`, which has no surface spelling and says so) and a cofinite atom set are
carried on a separate field and rendered with wording that does not invite a paste. The `pasteable`
key is absent, not empty.

**F29.10 — the prose is a prefix of the term channel.** `bs_diag.erl:1100-1101` claims the two
*"cannot say different things"*; they differ in completeness, because `pasteable/2` joins at
`infinity` (`:1104-1106`) while the prose caps at three in two places (`:1122-1136`). The scenario
asserts the prose head lines are the term list's first three plus the `... (N more)` line.

**F29.11 — the seven description sites keep type notation.** `rejected`, `member`, `undeclared`,
`unmatched`, `subject` and the switch `arm` are unchanged by this feature. A diff that alters their
text has confused the two jobs the split exists to separate.

**F29.12 — the six display sites replay.** `README.md:22`, `TOUR.md:150`, `TOUR.md:172`,
`LANGUAGE.md:352-356`, `LANGUAGE.md:513` and `compiler/examples/Wire/wire.bs:8-16`. Their expected
text moves when the printer changes; three of them need ENG-263's `expect-after` directive before
they are runnable at all.

## What the compiler gains

Named explicitly, because this is the section F22 was missing when it left this feature undone.

- **`bs_types`** — a head printer split out from `to_pattern/1`; `i_pat/1` beside `i_str/1`;
  `l_pat`/`sp_pat`/`sp_items_pat` beside the `_str` triple; `m_pat/1` reached from the list path;
  the type-word leaves removed from the head side only.
- **`bs_parser.yrl`** — the two productions in §1. Nothing else. The measured conflict count is
  0/0 and a build that reports otherwise means the productions were widened.
- **AST** — `p_typed`, new.
- **`bs_check`** — a case for `p_typed`; §2's subtype test at `bs_check.erl:2302`; a reverse map
  from minted tag atom to source type name, and the scope set, threaded to the diagnostic for F29.4.
- **Emitter** — a case for `p_typed`.
- **`bs_diag`** — each of the eight sites declares head or description; the description channel as
  a distinct field.

## The gate

**Owed by [ENG-263](https://linear.app/davewil/issue/ENG-263), and written before this feature** —
per the standing rule, and because a check written after the code is written to agree with it.

`compiler/bin/check-residual-pasteable.sh` walks a fixtures corpus plus a mutation stage over
`examples/Wire`, extracts the suggested head(s), pastes them back and requires a clean compile on
the term channel and a prefix relation on the prose. It asserts the **preferred** spelling, not only
that the text parses — without that it certifies the record row in §"Where it starts". Its floor is
a **shape roster**, not a count: atom, interval, interval-union, record, record-in-list,
tuple-nested, open-list, binary, top. A shape the roster names and the run never saw is red.

`--self-test` drives the verdict function over fabricated diagnostic text — no compiler rebuild —
with five stubs: type-notation (red), the correct form (green), silent (red), cry-wolf (red), and
**over-informed** (red): a stub that knows the right answer for the cases the gate was written
against and type notation for one it was not. The last is the only control that catches a gate whose
verdict is a lookup table of expected strings.

**F29 is done when that gate is green**, and the gate is believed only once it has been seen red on
today's compiler.

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
- **The `switch_inexhaustive` arm gaining a pasteable head.** `bs_diag.erl:566-568` refused it with
  a reason that still holds: a switch has no function name and its arrow is `=>`.
- **README's gating.** [ENG-264](https://linear.app/davewil/issue/ENG-264) owns it; F29.12 moves the
  text, not the gate that would catch it moving.

## Done when

The eight shapes in §"Where it starts" round-trip, `Ship(list<Invoice> invs)` is a legal clause head
with a measured conflict count of 0/0, `to_string/1` prints exactly what it printed before,
`Classify(int n)` is still a syntax error, the six display sites replay, and
`check-residual-pasteable.sh --self-test` has been seen red on all five stubs — including the
over-informed one — with a green on the correct form beside them.
