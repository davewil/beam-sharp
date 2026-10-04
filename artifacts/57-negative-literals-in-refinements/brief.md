# Decision brief: ticket 57 / ENG-239 — a refinement cannot say `-5`, though a pattern can

Prepared 2026-10-04 against `master` at `662e92f`. Nothing under `wayfinder/` or `compiler/` was
edited; both fixes were built on copies in the scratchpad. Every claim below cites a probe in
`probes/` with its captured `.out` beside it. Where a claim is not reproduced it is in
*Claims not reproduced / caveats*.

## Bottom line

**Recommendation: fold `-N` in the expression grammar's `negate/2` action (one line), stop at a
literal, and fix the refinement message separately.** The ticket frames the choice as *grammar*
versus *checker*. Measuring it showed the gap is wider than refinements, which changes the
question: `-5` is not a constant **anywhere** in the compiler except patterns, so four other
things fail today that the ticket does not list (below). A fold at the expression-grammar action
repairs all of them with no checker or emitter change; a fold in the checker has to be repeated at
three sites, and a fold at two of them is **unsound** (probe 08).

This is David's call. The brief gives the program that compiles under each answer.

## What the ticket says that is no longer true, and what is still true

| Ticket claim | Status | Probe |
|---|---|---|
| The table of five refinements (3 refused, 2 accepted) | **Reproduced exactly** on this checkout | 01, 00 |
| AST is `{e_op,'-',{e_int,0},{e_int,5}}` | **Stale.** Since F51 it is `{e_neg,L,{e_int,L,5}}` (`bs_parser.yrl:589,945`). The conclusion stands: still not a constant | 02 |
| Pattern `<= -1` compiles | Reproduced (`int_lit -> '-' integer`, `bs_parser.yrl:470`) | 01, 02 |
| "`refine/3` must error, not silently widen" | Still right, and unaffected by any option here | — |
| `subtract(-10..10, 0)` is `-10..-1 | 1..10` | Reproduced by the ticket's own probe 38b | 00 |
| Same literal in a guard | **Not in the ticket.** Compiles and runs, but earns **no coverage credit** | 03 |

## Four symptoms the ticket does not list (all the same root: `-5` is `e_neg`, not a literal)

1. **A guard comparand gets no coverage credit.** `F(n) when n >= -5 -> ...; F(n) when n < -5 -> ...`
   over `int` is "not exhaustive"; the same with `5` is accepted. A catch-all after it is also not
   flagged unreachable (probe 03, 06).
2. **The compiler's own printed residual cannot be pasted back.** `LANGUAGE.md` §3 (lines 449–465)
   promises *delete a clause and the compiler hands back the clause to paste*. The head it prints
   is `Classify((:ok, n)) when n <= -1 -> ...`. Pasting exactly that (with a body) gives **the same
   error again, forever**. The same program with positive bounds closes (probe 17: `Deleted` and
   `Pasted` both refused on the unpatched `bsc`; `PastedPos` accepted). This is the residual
   doctrine failing on a shipped example today, not "the next feature over a signed domain".
3. **The emitter's kind test is skipped for a negative literal.** `bs_emit.erl:700–711`
   (`kind_expr/2`) says it mirrors the shapes `bs_check:comparison/1` reads, so an ordering guard
   over `int | atom` gets an `is_integer` test (an atom is `>` every number in term order). With
   `n >= 5`, `F(:x)` returns `:other`; with `n >= -5`, `F(:x)` returns **`:hi`** (probe 08, `base`).
   This is a pre-existing divergence, independent of any fix.
4. **A negative literal as a *value* is typed `int`, not `-5..-5`** (`type_of({e_neg,..})` returns
   `bs_types:int()`, `bs_check.erl:2874–2885`; `{e_int,..}` returns the singleton, line 2867).
   So even once `Delta` is declarable, `Id(-5)` and `Delta Zero() -> -5` are **refused** if only
   the refinement reader is fixed (probe 07).

## Sub-decisions

Ordered; where one gates another, the gating one is asked alone.

**S1 (gating). Where does `-N` become a constant: in the expression grammar, or in the checker?**
Everything else follows from it. Asked as programs in *Options*.

**S2 (follows S1). How far does the fold go?** Measured fold-extent table (probe 04, 05):
`-5`, `-(5)`, `(-5)`, `- -5` are the "literal" tier; `2 + 3`, `0 - 5`, `2 * 3` the "arithmetic" tier;
`value >= n`, `value + 1 >= 5`, `value >= 5 - value` never. Existing neighbours stop in different
places (*Neighbours*). A control (probe 14) shows `Id(2 + 3)` into `Pos` is refused **today with
positive numbers**: the value typer does not fold binary arithmetic either, so folding it in a
comparand only would make the refinement reader smarter than the typer.

**S3 (falls out of S1). Guard comparand vs refinement parity.** Both go through
`alternatives/1`. A fix that touches only `refine/3` leaves them disagreeing (probe 03/07/17 with
`refine_only`).

**S4 (independent of S1; follows it). The `opaque_refinement` text.** It says *"comparisons on
`value`, joined with `and`/`or`"*. After any fix, `value >= 2 + 3` and `value >= n` are still
refused and *are* comparisons on `value`. The text must name the real rule: the other side of a
comparison is an integer literal (or an atom for `==` / `!=`).

**S5. `value != 0`, disjoint ranges, and `==`.** No decision needed; measured. `value != 0` is accepted
and genuinely excludes zero; `value <= 3 or value >= 10` is accepted (probe 01). After either fix
`value >= 1 or value <= -1` is accepted, and `value >= -5 and value <= -10` is correctly refused
as `empty_refinement`, not `opaque_refinement` (probe 04). `value == -3` stays refused after the fix
but for another reason (S6): the message becomes `bad range type`.

**S6. Found on the way, not this ticket, no ticket hits:** `type T = int where value == 3` is
refused today with `compile: a.bs:0: bad range type` — a *positive* literal, so not sign-related.
OTP's `erl_lint` rejects a range whose bounds are equal (`erl_lint.erl:3432–3436`), and Erlang
confirms it for `3..3` and `-3..-3` (probe 20). `grep -rn "bad range type" wayfinder/issues
compiler/features` finds nothing. Raise a ticket; do not fold it into this one.

## Options

All three are real builds. The programs below were run; outputs are in the probe files named.

### Option A — fold in the expression grammar: `negate(_, {e_int,IL,N}) -> {e_int,IL,-N}`

The existing line above it already does this for floats (`bs_parser.yrl:944`, F51: *"A negated
float LITERAL folds to the literal"*). It is **not** the ticket's "narrow the refinement grammar":
a refinement stays `expr_low` (`bs_parser.yrl:221`), so refinement and guard still share one
grammar and one meaning. It narrows nothing; it changes what `-5` *parses to*, everywhere.
`{e_int,_,Negative}` is already a legal AST value: `bs_emit.erl:669` builds one from `p_rel`.

Compiler delta: **one clause in `bs_parser.yrl`** (+ `leex/yecc` regeneration). No change to
`bs_check.erl`, `bs_emit.erl` or `bs_diag.erl`.

Compiles under A, refused today (and under B-minimal / C):
```csharp
type Delta = int where value >= -100 and value <= 100
public int Id(Delta d)
Id(d) -> d
public int Go()
Go() -> Id(-5)                 // A: accepted, prints -5.   B-min: refused, "argument 1 is not covered ... int <= -101 | int >= 101"
```
(probe 07: `NegCall` accepted on `grammar`, refused on `checker_min`, `checker_wide`, `refine_only`.)

And the shipped doctrine closes (probe 17: `Pasted` accepted on `grammar`).

Refused under A, accepted under B-wide:
```csharp
type T = int where value >= 2 + 3       // A: opaque_refinement (arithmetic tier); B-wide: accepted
```

*Strongest counterargument.* **It changes the type of every `-N` expression in the language, not
just refinements.** `-5` goes from `int` to `-5..-5`. The one measured behaviour change outside
refinements (probe 19): `x / -0` is now refused at compile time as "always zero" (it ran and
crashed with `badarith` before, while `x / 0` was already refused). It is the correct answer, but
it is a behaviour change made by a parser edit, and the clean-room handoff will have to *say* "a `-` directly before an integer
literal is part of the literal" in the spec. Also, `- 5` with a space folds too, because the
parser, not the lexer, does it (the same is true of the float fold today). Diagnostics that quote
the literal point at the digit's column, not the `-`'s (the prototype reused the digit's position;
using the `-` position is a one-word change, not measured).

### Option B — fold in the checker: a `const_int/1` read by `comparison/1`

Three variants were built, because the first one turned out not to be a fix.

- **B-minimal** — `const_int({e_int,..})` and `const_int({e_neg,..})` read by `comparison/1`
  only. Fixes the table and guard credit. **Leaves symptoms 3 and 4, and makes 3 unsound**: the
  checker now *credits* `n >= -5` as an int range, while the emitter (`kind_expr/2`, which only
  recognises `{e_int,..}`) emits no `is_integer` test, so `F(:a)` over `int | atom` hits the
  `n >= -5` clause although the checker proved it could not (probe 08, `checker_min`: `:int_hi`,
  expected `:a`). That is the exact hole `bs_emit.erl:690–699` documents as the reason the mirror
  exists.
- **B-wide** — the same plus `+ - *` over constants. Also accepts `value >= 2 + 3`, `0 - 5`, `2 * 3`
  (probe 04); not `/`, `%`. Same unsoundness as B-minimal.
- **B-full** — B-minimal plus `type_of({e_neg,_,{e_int,..}})` returning the singleton and
  `kind_expr/2` rewritten to call `bs_check:const_int/1` (export it). Reaches parity with A on
  every probe in 01, 03, 07, 08, 17 and 18.

Compiler delta for B-full: **three sites that must stay mirrored** — `bs_check.erl`
`comparison/1`, `bs_check.erl` `type_of/3`, `bs_emit.erl` `kind_expr/2` — plus the new exported
function. The refinement stays an `expr`, which is the stated intent at the `refinement` rule
(`bs_parser.yrl:218-221`; the ticket says `bs_check.erl`, but the comment lives in the parser).

Compiles under B-wide, refused under A:
```csharp
type T = int where value >= 2 + 3
```
Compiles under A and B-full, **miscompiles** under B-minimal (probe 08):
```csharp
public atom F(int | atom n)
F(n) when n >= -5 -> :int_hi
F(n) when n < -5  -> :int_lo
F(:a) -> :a                    // B-min: checker says F(:a) reaches here; runtime returns :int_hi
F(_) -> :other
```

*Strongest counterargument.* **It is the answer that matches the ticket's own design principle,
and Erlang does it this way** (parser leaves `{op,_,'-',{integer,..}}`; `erl_lint` folds via
`erl_eval:partial_eval`, `erl_lint.erl:2134–2147`). A checker fold keeps the AST faithful to the
source (`-5` stays a negation node, which F51 deliberately made its own node), and a spec for
other implementers can say "constants are folded by the checker", which is the more general rule
if arithmetic constants are ever wanted (`value >= 2 + 3`). Against that: Erlang's emitter
inherits the fold from a *later* pass that all consumers share; here the emitter has its own
mirror of the checker's shapes, so the fold has to be repeated rather than inherited.

### Option C — narrow the fold to the refinement site (the ticket's first option, as a proxy)

A true "narrow the refinement grammar" was **not built**: yecc has no clean way to give
`refinement` its own comparand nonterminal without duplicating the `and`/`or` precedence ladder,
and the ticket itself argues against it. The proxy built is *fold `-N` inside `refine/3` before
`alternatives/1`* (variant `refine_only`), which is the same behaviour at the same site.

Result: the ticket's whole table is fixed (probe 01, `refine_only`) — and **symptoms 1–4 all
remain** (probe 03, 07, 08, 17 `refine_only`: the guard still uncredited, `Id(-5)` still refused,
the printed residual still not closable). The refinement and the guard now *disagree about what
`-5` means*, which is the split the comment at `bs_parser.yrl:218-221` exists to prevent.

*Strongest counterargument.* It is the smallest change that makes the ticket's stated repro
compile, and it cannot change the type of any expression outside a refinement, so it has no
behavioural blast radius.

## Evidence: what each fix breaks and does not

EUNIT_SECTION

## Measured cost (probe 15, `measure.escript`)

Load-independent metric is reductions; wall ms were taken on a machine with load average 12–23
(other sessions' `bsc`/`rebar3` were running) and are not comparable. 1000 refinements, lex+parse
then `bs_check:check/1`, median of 9:

| file | variant | parse reductions | check reductions |
|---|---|---|---|
| 1000 non-negative refinements | base | 520,275 | 416,913 |
| | grammar (A) | 526,145 (+1.1%) | 416,715 (0%) |
| | checker_full (B-full) | 521,134 (+0.2%) | 420,602 (+0.9%) |
| 1000 signed refinements | base | 556,954 | 33,579 (**stops at the first refusal**) |
| | grammar (A) | 554,667 | 417,061 |
| | checker_full | 553,572 | 423,080 |
| 1000 guards with a negative result literal | base | 387,444 | 4,843,371 |
| | grammar (A) | 388,057 (+0.2%) | 4,581,074 (-5.4%) |
| | checker_full | 392,288 (+1.3%) | 4,666,328 (-3.7%) |

All within a few percent; none is a reason to prefer an option. (The +1.1% parse delta on a file
with no negatives cannot come from the new clause; it is measurement noise at this size.)

AST and diagnostic shape (probe 21, 06): under A, `value >= -5` reaches the checker as
`{e_op,L,'>=',{e_var,L,value},{e_int,L,-5}}`; under B the AST is unchanged
(`{e_neg,L,{e_int,L,5}}`). The refusal diagnostic (`opaque_refinement`) keeps its tag and first line in
all variants for the forms that remain refused (probe 04/05; not byte-compared).

## Neighbours (real installed sources; file:line only where a file was opened)

| Language | `-5` in a pattern | in a guard / expression | arithmetic (`2 + 3`) in a pattern | in a type range |
|---|---|---|---|---|
| **Erlang/OTP 28** | accepted. Parser leaves `{op,_,'-',{integer,..}}` (probe 10); `erl_lint:is_pattern_expr` folds via `erl_eval:partial_eval` (`stdlib-7.0/src/erl_lint.erl:2134–2147`) | accepted; the Core Erlang guard comparand is the literal `-5` and `h(X) when X >= 2+3` shows `5`; BEAM asm has `{integer,-5}` (probe 10). Which pass folds it was not isolated; `sys_core_fold.erl:896–921` (`fold_call_2`/`fold_lit_args`) folds all-literal BIF calls | **accepted** (`g(2+3)`) | `-5..5` and `(1+1)..(2*5)` accepted; `erl_lint.erl:3432–3436` requires `X < Y` |
| **Elixir 1.14** (OTP 25; tickets used 1.19.5) | accepted; quoted form is a unary call `{:-,_,[5]}` (probe 11) | accepted | **refused**: `cannot invoke remote function :erlang.+/2 inside a match` | `@type r :: -5..5` compiled |
| **Gleam 1.12** (tickets used 1.18.1) | accepted; generated Erlang `-5 ->` | accepted; generated `N when N >= -5`; `n >= 2 + 3` passes through as `(2 + 3)` | **syntax error** (`2 + 3 -> ...`) | n/a |
| **Elm 0.19.2** | **not reproduced** — registry unreachable (probe 13) | — | — | — |

Reading: three of three reproduced neighbours accept `-5` in patterns *and* guards, so a language
where a pattern takes `-5` and a guard silently does not (today's B#) is the odd one out. On
arithmetic they split: Erlang folds anything constant; Elixir and Gleam refuse it in patterns. So
"`-5` yes, `2 + 3` no" has two precedents; "everything constant" has one (Erlang, which has a
shared later pass to do it).

## Recommendation

**Option A**, with the message fix (S4) landed with it, and S6 raised separately.

1. It is the only answer that fixes all four symptoms without editing the emitter's mirror: the
   checker, emitter and typer already agree on `{e_int,_,N}` for any `N`.
2. It keeps the ticket's own principle (one grammar for refinement and guard), because it narrows
   nothing; the ticket's dichotomy missed that the fold can sit in the *expression* action, as the
   float fold already does.
3. B-full reaches the same place with three mirrored edits, and B-minimal/wide, the shortest
   checker patches, are unsound (probe 08). If David prefers B for the "constants are the
   checker's job" principle, it must be B-full and the emitter site must have a test that the
   gate sees fail first (CLAUDE.md: the failing test and gate come first).
4. Stop at the literal tier. `Id(2 + 3)` into a refined parameter is refused today even with
   positive numbers (probe 14), so folding arithmetic in a comparand alone would make the
   refinement reader smarter than the value typer. If arithmetic constants are wanted, that is a
   separate question about the typer, not about refinements.

What A costs, stated so it is not a surprise: `-5` becomes a singleton type everywhere;
`x / -0` becomes a compile-time refusal (probe 19); the spec must say a `-` before an integer
literal belongs to the literal. If David does not want to change the type of `-5` outside
refinements, the answer is B-full, not C.

### What each option needs before it can land (per CLAUDE.md)

- A failing test and a gate first. Suggested scenarios (all runnable today as failing): the ticket
  table (probe 01), the printed-residual round trip (probe 17), the `int | atom` kind test
  (probe 08). Probe 17 is the strongest because it is the shipped doctrine.
- F2's scenarios are all non-negative (the ticket's claim); I did not re-count them (see caveats).

## Claims not reproduced / caveats

- **Elm**: could not be exercised. `package.elm-lang.org` returns 403 through the proxy and
  `~/.elm` has no cached packages, so `elm make` stops before parsing (probe 13). No Elm
  statement is made in this brief beyond that.
- **Elixir**: only `.beam` files are installed (`/usr/lib/elixir`); no Elixir source was opened,
  so no file:line is cited for it. Version 1.14.0 on OTP 25 (its beams do not load on OTP 28),
  not the tickets' 1.19.5. Behaviour only.
- **Gleam**: 1.12.0, not 1.18.1.
- **Option C is a proxy.** A real narrowed refinement grammar in `bs_parser.yrl` was not built.
- **The eunit runs** were done per module, retried on failure, because the machine was shared
  (load average up to 23 on 4 vCPU; foreign `bsc`/`rebar3` processes from other sessions) and one
  whole-suite `rebar3 eunit` aborts on the first 5 s timeout (every variant, including the
  unpatched copy, aborted after ~230–300 tests in the first attempt; logs kept as
  `probes/eunit_whole_suite_aborted_*.log`). The first per-module attempt also failed
  `cli_tests` and `body_check_tests` on the **unpatched** copy for environmental reasons
  (`LANG` not UTF-8; the test wants `../aoc` beside the copy); both were fixed in the runner and
  the numbers below are from the rerun. EUNIT_COVERAGE_CAVEAT
- **`checker_min`, `checker_wide`, `refine_only` were probed but not run through eunit.** B-wide
  is a superset of B-minimal's behaviour; B-full is the variant a proposal would have to be.
- **The F51 float fold's interaction**: `-0.0` and `-x` are untouched in every variant (probe 19,
  `NegFloatStill`). I did not test floats beyond that.
- **The clean-room handoff effect** (what the spec must say) is argued, not measured.
- **Diagnostic columns under A**: the prototype keeps the digit's position for the folded literal;
  I did not measure what a diagnostic would print with the `-`'s position.
- **Wall-clock timing** is not reported as evidence: see the load note. Reductions are.
- **Ticket claim that every F2 scenario is non-negative** was not re-counted.
- **`ENG-239` state in Linear** was not read; the Linear tools were not used.

## Probe index

| # | file | what it settles | output |
|---|---|---|---|
| 00 | `00_ticket_own_probe_38b.out` | the ticket's own 38b probe, re-run (7/7 as expected), run from `/tmp` so no stray `.beam` lands in the repo | yes |
| 01 | `01_ticket_table.sh` | the ticket's table with the real `bsc`; `_refine_only.out` is the same on the proxy | `.out`, `_refine_only.out` |
| 02 | `02_ast_shape.sh` + `ast.escript` | real AST: `e_neg` not `e_op '-'`; pattern is `p_rel -1`; guard is `e_neg` | `.out` |
| 03 | `03_guard_vs_pattern.sh` | guard `-5` compiles and runs, earns no coverage; pattern does | `.out`, `_refine_only.out` |
| 04 | `04_fold_extent_table.sh` | 20 predicates: `-5`, `2+3`, `-(5)`, `value != -3`, contradictions | `.out` |
| 05 | `05_fix_probe_table.sh` | 01+03+04 on every variant | `.out` |
| 06 | `06_residual_diagnostics.sh` | `value == -3` error and the unreachable-clause warning, base vs checker_min | `06_base.out`, `06_checker_min.out` |
| 07 | `07_literal_flows_into_refined_type.sh` | `Id(-5)`, `Zero() -> -5` into a `Delta`; per variant | `.out`, `_refine_only.out` |
| 08 | `08_guard_kind_test_mirror.sh` | `int | atom` guard: emitter mirror; **unsound under B-min** | `.out`, `_refine_only.out` |
| 09 | `09_run_variants.sh` | runner: any probe on every variant | — |
| 10 | `10_erlang_neighbour.sh` | OTP 28 parse/Core/BEAM of `-5`, `2+3`, `-5..5` | `.out` |
| 11 | `11_elixir_neighbour.sh` | Elixir 1.14 | `.out` |
| 12 | `12_gleam_neighbour.sh` | Gleam 1.12 + generated Erlang | `.out` |
| 13 | `13_elm_neighbour.sh` | Elm: **not reproduced** | `.out` |
| 14 | `14_positive_arithmetic_control.sh` | `Id(2 + 3)` into a refined param is refused with positive numbers | `.out` |
| 15 | `15_timing_gen.sh` + `measure.escript` | 1000-refinement cost, reductions | `.out` |
| 16 | `16_eunit_per_module.sh` | the compiler's eunit suite per module on base / grammar / checker_full | `16_eunit_*.out` |
| 17 | `17_pasted_residual.sh` | `LANGUAGE.md` §3: paste the printed residual back | `.out`, `_base.out`, `_refine_only.out` |
| 18 | `18_signed_domain_residual.sh` | `Delta` as clause head, missing negatives printed, `/` over it | `.out` |
| 19 | `19_other_expression_effects.sh` | what A changes outside refinements (`x / -0`, `-5` as `Neg`) | `.out` |
| 20 | `20_singleton_range_side_finding.sh` | S6: `value == 3` → `bad range type`; Erlang rejects `3..3` | `.out` |
| 21 | `21_ast_before_after.sh` | AST before/after A and B-full | `.out` |
| — | `lib.sh` | shared helper (`probe NAME SRC [FN ARGS]`) | — |

Prototype builds (not in the repo): `<scratchpad>/proto/{base,grammar,checker_min,checker_wide,checker_full,refine_only}/compiler`.
The patches are small enough to restate: *grammar* adds
`negate(_L, {e_int, IL, N}) -> {e_int, IL, -N};` after the float clause; *checker_min* replaces the
two `comparison/1` int clauses with a `const_int/1`-driven pair; *checker_wide* adds `+ - *` to
`const_int/1`; *checker_full* adds the `type_of` clause and the `kind_expr` mirror; *refine_only*
maps a `fold_neg/1` over the predicate in `refine/3`. Each is saved as `patches/*.diff`.
