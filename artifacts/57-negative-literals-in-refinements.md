# Decision brief: ticket 57 (ENG-239), a refinement cannot say `-5`, though a pattern can

Prepared for the human to decide; nothing is resolved, no ticket, Linear item or compiler file was touched.
Tree: `master` at `712b9e9`. Probes: `artifacts/probes/57/` (`run.sh` re-executes everything from a clean copy;
raw output in `out/`; every edit after first output is in `CHANGELOG.md`). Probe refs below are `NN` = `NN_*.sh`.
"base" = a fresh copy of the repo compiler, "repo" = the escript already built in the repo; they agree on every row.

Re-run: `bash artifacts/probes/57/run.sh` (about 10 minutes without eunit, `SKIP_EUNIT=1`; about 45 with it; do not run anything else during the eunit step, a loaded machine times out one subprocess test and eunit cancels the run).
Lines the probes print as `REFUTED` are claims that did not hold: the ticket's `0 - 5` mechanism (E3), my own prediction that a guard narrows on `-5` (E4), and the ticket's residual claim (E8).
`out/10_eunit.txt` was filled from the separate sequential runs in `evidence/eunit/`, not by that `run.sh` pass.

## Sub-decisions

1. **Where the fold lives.** Not the two places the ticket names. The ticket offers "the grammar, mirroring `int_lit`" or
   "the checker". There is a third, and the tree already has its precedent: the **parser action for unary minus**
   (`bs_parser.yrl:589` -> `negate/2`, `:944-945`) already folds a negated *float* literal into the literal. An int clause
   there is one line. The refinement keeps being an `expr` (`bs_parser.yrl:221`), so the ticket's worry about
   narrowing the refinement grammar does not arise.
2. **How far it folds.** `-N` only; or `-N` plus constant `+ - *`; never a name (`value >= n`, `-n`, `-value`).
3. **Do guards and refinements keep agreeing.** They share `alternatives/1` -> `comparison/1` (`bs_check.erl:4931-4955`),
   decided in ticket 20 §5 and re-argued in ticket 63 §4. A fix that touches only the refinement position breaks that.
4. **Unary minus elsewhere.** `-x`, `-(a+b)` stay a node. But `-5` as an *expression* is currently typed `int`
   (`bs_check.erl:2874-2884`), which has consequences outside any refinement (see Executed facts E6, E7).
5. **The residual-doctrine consequence.** The ticket says the residual `-10..-1 | 1..10` is "a residual the compiler
   prints and the surface cannot accept". Measured: false as stated (E8). What stays true: a signed bounded *domain* cannot be declared.

## Executed facts

Ticket claims I REFUTED or could not reproduce are marked **REFUTED**.

**E1. The refusal table reproduces row for row.** Probe 01, repo bsc.

```
MATCH  value >= -5                        refused
MATCH  value >= -5 and value <= 5         refused
MATCH  value >= 1 or value <= -1          refused
MATCH  value <= 3 or value >= 10          accepted
MATCH  value != 0                         accepted
MATCH  != 0 excludes a literal 0 at a call   refused      (G(0) into Nz)
```
The shipped `38b_divisor_expressiveness.sh` also still reports "all 7 probes matched expectation" (`out/38b_shipped_probe.txt`).
No signed-bound spelling gets through: `value > -6`, `0 - 5 <= value`, `-5 <= value`, `value + 5 >= 0`,
`value >= -(5)`, `value >= --5` are all refused (01).

**E2. The refused form is what the diagnostic recommends: confirmed, and with a worse edge.** Probe 01. The message
says "comparisons on `value`, joined with `and`/`or`" and prints `int where value >= 0 and value <= 255` (that example
compiles); `value >= -5` is a comparison on `value` and is refused with that same message. The message never mentions
negative, minus or literal. The text has since gained a second paragraph (the O(n) tier) that the ticket does not quote;
the first paragraph is unchanged.

**E3. REFUTED: the stated mechanism.** The ticket says unary minus "desugars to
`{e_op,'-',{e_int,0},E}`". At `712b9e9` it parses to a node of its own (probe 02, repo parser beams):
```
value >= -5   ->  {e_op,{2,26},'>=',{e_var,{2,20},value},{e_neg,{2,29},{e_int,{2,30},5}}}
value >= 0 - 5 -> {e_op,..,'>=',..,{e_op,{2,31},'-',{e_int,{2,29},0},{e_int,{2,33},5}}}
```
`bs_parser.yrl:585-589` says the `0 - e` form was replaced by `e_neg` "since F51"; the ticket (2026-08-23) predates F51
(done 2026-09-16). The earliest commit in this checkout that mentions `e_neg` is `2127bb8` (2026-09-29, "F67 review ... unary `-`"),
so I could not date the change from git. The symptom is unchanged and the refusal table holds; only the explanation is stale.
(Minor: the ticket places the "a refinement is an `expr` so it and a guard cannot disagree" comment in `bs_check.erl`; it is at `bs_parser.yrl:219-221`, with the checker side at `bs_check.erl:1895-1896`.) It matters because the ticket's "the checker cannot fold a subtraction node" is no longer the thing to fold: it is an `e_neg` over an `e_int`.

**E4. A guard with `-5` compiles and runs today, but credits nothing, so a correct program is refused.** Probe 03, repo bsc.
- `Band(n) when n >= -5 -> :a` + a catch-all: accepted; `Band -3` -> `:a`, `Band -9` -> `:b`, `Band -5` -> `:a`.
- It lowers to a **unary op**, not a negative literal. Raw `.abstr`: `{op,{3,16},'>=',{var,{3,14},'N'},{op,{3,19},'-',{integer,{3,20},5}}}`.
  The relational pattern `<= -1` lowers to `{op,{3,6},'=<',{var,..},{integer,{3,6},-1}}` (`bs_emit.erl:669`, `rel_expr` builds `{e_int,L,K}` with `K` negative).
- **REFUTED (my prediction, not the ticket's): the guard does not narrow.** Three clauses that cover `int` exactly by arithmetic:
  ```csharp
  public atom Band(int n)
  Band(n) when n >= -5 and n <= 5 -> :mid
  Band(n) when n < -5             -> :low
  Band(n) when n > 5              -> :high
  ```
  is **refused**: `Band is not exhaustive / no clause matches: Band(<= 5) -> ...`. Same shape with `0` instead of `-5` is accepted.
  Cause: `comparison/1` returns `unknown` for the `e_neg` operand, and `apply_guard/3` (`bs_check.erl:4916-4925`) credits an
  unread guard nothing ("An unread guard may always fail"). Safe direction, but the residual it prints (`<= 5`) is wrong, and
  the program is correct. So the defect the ticket files under refinements is **also live in guards**, and the ticket does not say so.
  The same program written with relational patterns (`Band(>= -5 and <= 5)`, `Band(<= -6)`, `Band(>= 6)`) is accepted (03).

**E5. Emission.** Probe 06, same source path in every variant. Only the parser fold changes the abstract form
(`{op,..,'-',{integer,..,5}}` -> `{integer,..,-5}`); the **disassembled BEAM code is identical in all variants**
(`{test,is_ge,..,[..,{integer,-5}]}` in each, so the identity is not vacuous). The checker folds do not change `.abstr` at all.

**E6. `-5` as an expression is typed `int`, not `-5..-5`; a refinement fix does not reach it.** Probe 05, base:
```csharp
type Nz = int where value != 0
int G(Nz b)
G(b) -> b
public int F()
F() -> G(-5)        // refused: "argument 1 is not covered by G's declared type: 0"
```
`G(5)` is accepted. `type_of({e_neg,..})` returns `bs_types:int()` for any numeric operand (`bs_check.erl:2874-2884`). A checker fold
confined to `comparison/1` leaves this refused; the parser fold (and `c2`'s `type_of` tweak) accepts it. `G(0 - 5)` is refused under every variant.

**E7. A literal `-0` divisor escapes ticket 38's refusal today.** Probe 05, base: `x / 0` is refused (`always zero`, `divisor_diags`,
`bs_check.erl:4146-4153`, type-based); `x / -0` and `x % -0` are **accepted** because `-0` is typed `int`. The parser fold and `c2` refuse them. A behaviour change, arguably a fix.

**E8. REFUTED: the residual doctrine is not capped the way the ticket says.** Probe 07. Every clause the compiler prints as missing
is accepted when pasted back, negative bounds included:
```
base:  F(>= -10 and <= 10) -> :in   only      prints  F(<= -11) / F(>= 11)        pasted: compiles
g1:    Sign(0) -> :zero   over -10..10         prints  Sign(>= -10 and <= -1) / Sign(>= 1 and <= 10)   pasted: compiles
```
`-10..-1 | 1..10` is the algebra's *term*; the diagnostic prints the **clause** (F29) in relational-pattern spelling, which has `int_lit -> '-' integer`.
The interval notation (`-100..0`) that does appear in "not covered by Take's declared type" is not surface syntax for any sign: the base compiler
prints `0..99 | 201..255` for a non-negative domain too. What the gap really caps is **declaring** a signed bounded domain (`type Delta = int where ...`), not writing its residual.
Ticket 38's "the compiler would have handed back a clause the language cannot spell" is therefore also not reproduced.

**E9. A fix makes the declared domain exact.** Probe 04, each fix variant: `type Delta = int where value >= -100 and value <= 100` with
`Sign(>= -100 and <= -1)`, `Sign(0)`, `Sign(>= 1 and <= 100)` compiles with no catch-all; dropping `-100` from the first clause is refused with
residual `Sign(-100)`; `Sign(<= -1) / Sign(>= 1) / Sign(_)` (closed residual `{0}`) is refused by ticket 12 §2's rule.

**E10. Incidental, unrelated to 57: a refinement of exactly one integer cannot be declared at all.** Probe 11. `value == 3`
and `value >= 3 and value <= 3` fail with `compile: ...:0: bad range type`: the emitted `-spec` carries `3..3`, and
`erl_lint.erl:3440-3444` requires `X < Y`. Also true for `-3` under a fix. It looks like a ticket of its own; I did not decide that.

## Neighbour survey

Real tools executed; sources opened where installed. Probe 08, raw output `out/neighbours/`.

| Language | `-5` in a pattern | in a guard / constant | as an expression | Where folding happens |
|---|---|---|---|---|
| **Erlang** (stdlib-7.3, compiler-9.0.6) | parser keeps `{op,3,'-',{integer,3,5}}` (printed by `erl_parse`); lint accepts it | same `{op,..}` in `X >= -5`; `2 + 3` also unfolded | `{op,5,'-',{var,..},{op,5,'-',{integer,5,5}}}` | **After the parser, in two places.** Patterns: `v3_core.erl:2638-2641` calls `erl_eval:partial_eval`. Guards/expressions: `sys_core_fold.erl:889-906` folds a pure call whose args are literals. `core` with `no_copt`: pattern already `<-5>`, guard/expr still `call 'erlang':'-'`; with copt: `>=(_0, -5)` |
| **Elixir 1.19.5** | `string_to_quoted` gives `{:-, [line: 1], [5]}` | same for `x >= -5` and `2 + 3` | `{:-,..,[5]}` | After expansion: erlang_v1 forms show `{:integer, _, -5}` in the pattern, guard and `x - -5` alike (`out/neighbours/elixir_forms.txt`). Elixir's own `.ex` sources are not installed, so I cannot cite a line |
| **Gleam 1.18.1** | `-5` ok; `- 5`, `-(5)`, `--5`, `2 - 3` are syntax errors | guard `n >= -5` ok, `n >= - 5` and `n == -m` are errors, `n >= 2 + 3` ok; const `-5` ok, `-{5}`, `- -5`, `2 + 3` errors | `-x`, `- -5` ok | Literal sign is part of the pattern/const/guard grammar; unary negation exists only in expressions. Generated Erlang keeps `-5 ->`, `N when N >= -5`, `(X - -5) + - X`. No Gleam compiler source is installed; this is tool output only |
| **Elm 0.19.0** | not checked | not checked | not checked | `elm make` needs `package.elm-lang.org`, which the proxy refuses (`out/neighbours/elm.txt`). I claim nothing about Elm |

Reading: Erlang and Elixir are **uniform parse + fold later** (the checker-fold shape), and both fold in guards and patterns alike so that they never disagree.
Gleam is **literal in the grammar** (the `int_lit` shape), and pays for it by refusing `- 5`, `-(5)`, `2 + 3` in patterns and constants.
B# today is neither: it is Gleam-shaped in patterns (`int_lit`) and Erlang-shaped in guards and refinements, with the fold step missing.

## Measurements

Patch sizes (non-header lines, `patches/*.patch`; diffs against the repo copy). Grammar conflicts: **6 shift/reduce** in the unpatched copy and in every
variant (probe 00); `bs_parser.yrl:726` still says the grammar "holds 0", which is stale, and none of the fixes moves the count.

| Variant | Where | Added / removed | AST for `value >= -5` |
|---|---|---|---|
| **g1** parser `negate/2` int clause | `bs_parser.yrl` | **+1 / -0** | `{e_int,L,-5}` |
| **g1b** fold under the `refinement` rule only | `bs_parser.yrl` | +6 / -1 | `{e_int,L,-5}` under a refinement; `{e_neg,..}` in a guard |
| **c1** checker fold in `comparison/1` | `bs_check.erl` | +29 / -5 | unchanged `{e_neg,..}`; folded inside the checker |
| **c2** c1 plus `type_of({e_neg, int literal})` | `bs_check.erl` | +31 / -5 | unchanged |

Where the fold stops (probe 04, 19 refinement rows). Accepted: `-N`, `- N`, `-(N)`, `-N` on either side of the operator, `!=`, `or`, `and` (all four fix variants).
`--5` and `- -5`: g1 yes (it folds twice, giving `>= 5`), c1/c2 yes, g1b no (my 6-line version only unwraps one `e_neg`; a literal-only grammar would refuse it too).
`2 + 3`, `0 - 5`, `-5 * 2`: **only c1/c2**. Never, in every variant: `10 / 2`, `value >= n`, `value >= -n`, `-value >= 5`, `value + 5 >= 0`.

Value preservation (probe 05 DIFF): `- -5`, `-(2+3)`, `1 - -5`, `-5 * 3`, `- 2 * 3`, `10 - -5 - -5`, `-x - -5`, `-0` and a `-5` pattern with a `>= -4` guard print identical results in base, g1, g1b, c1, c2.

**Compile time** (probe 09: a module of 300 refinement types, each used by a function; 15 interleaved rounds, median/min ms, one VM per run):

| Variant | empty module (VM start-up) | P1: 300 non-negative refinements | P2: 300 signed refinements |
|---|---|---|---|
| base | 653/548 | 1069/962 | refused (the ticket) |
| g1 | 656/575 | 1077/903 | 1092/914 |
| g1b | 644/522 | 1038/942 | 1087/942 |
| c1 | 646/578 | 1052/955 | 1058/934 |
| c2 | 639/546 | 1078/974 | 1065/953 |

No variant is distinguishable from base: medians sit within about 3% of base on P1 and the spread inside one variant (about 100 ms) is larger than the spread between variants.
The first run of this probe timed variants in sequential blocks and showed a 13% gap that was drift (the VM-only row differed by 100 ms); it is kept in `evidence/09_first_run_sequential_blocks.txt` and explained in `CHANGELOG.md` item 11.

**Test suite** (`rebar3 eunit`, each variant in its own copy, one at a time, `evidence/eunit/*.txt`): base, g1, g1b, c1 and c2 all report **All 1312 tests passed**.
That is also a coverage finding: no existing test turns red under any variant, so no test pins the current refusal, and none exercises a negative bound in a refinement (`intervals_tests.erl:46-60` pins opaque refinements by other shapes; `intervals_tests.erl:290-297` covers the negative *pattern*).
Two runs were invalid and are kept as evidence, not results: five variants in parallel (a subprocess test timed out, eunit cancelled at 228 tests), and one g1 run overlapped with another probe (same timeout). Both reruns were on an idle machine (`CHANGELOG.md` items 9, 10).
**Not measured:** the repo's `bin/check-*.sh` gates, and `verify.sh`'s twice-from-clean rule.

## Options

Each program compiles under the option named and is refused under at least one other; probe 12 compiles all of them whole under every variant (`out/12_options.txt`).

### Option A: fold the literal where the parser already folds the float (variant g1)

```csharp
module Ledger

type Delta = int where value >= -100 and value <= 100     // refused today
type Nz    = int where value != 0

int Step(Nz n)
Step(n) -> n

public atom Band(int n)                                   // refused today (E4): residual printed as `Band(<= 5)`
Band(n) when n >= -5 and n <= 5 -> :mid
Band(n) when n < -5             -> :low
Band(n) when n > 5              -> :high

public int Back()
Back() -> Step(-5)                                        // refused today and under c1 (E6)
```
Compiles under A (g1) and c2; refused under base, g1b and c1 (probe 12). One more line changes meaning under A and c2, and is deliberately not in the program above:
`Div(x) -> x / -0` compiles today and is **refused** under A (E7).
**Compiler delta.** One clause in an existing function: `negate(_L, {e_int, IL, N}) -> {e_int, IL, -N};` beside the float clause at `bs_parser.yrl:944`. No symbol-table entry, no new pass,
no emitted function. Changes one emitted form (`{integer,L,-5}` for `{op,'-',{integer,L,5}}`, a shape `rel_expr` already emits for patterns); BEAM code identical (E5).
**Measured.** 1 line; grammar conflicts 6 -> 6; refinement rows `-N` all accepted; E4, E6, E7, E9 all change; value-preservation identical; eunit 1312/1312.
**Strongest counterargument.** It stops at the literal: `value >= 2 + 3` and `value >= 0 - 5` stay refused with the same "comparisons on `value`" message that already misleads (E2), so the
defect shape the ticket complains about (the message recommends what it refuses) survives for the next spelling a user tries. It also changes behaviour outside the ticket's question
(`x / -0` becomes a compile error, E7), which is right by ticket 38's own rule but is a decision nobody asked for here.

### Option B: fold constants in the checker (variants c1, c2)

```csharp
module Ledger

type Delta = int where value >= -100 and value <= 100
type Hi    = int where value >= 2 + 3                     // refused under A, accepted here
type Lo    = int where value >= 0 - 5 * 2

public atom Band(int n)
Band(n) when n > 2 + 3 -> :high                           // a guard folds too: refused under A
Band(n) when n <= 5    -> :low
```
Compiles under c1 and c2; refused under base, g1 and g1b (probe 12).
**Compiler delta.** One function in `bs_check.erl` (`const_int/1`, 9 lines, over `e_int`, `e_neg`, `+ - *`), one helper (`fold_const/1`), and `comparison/1` split in two so the existing clauses run on folded operands. For `-5` as an *expression* (E6) the checker also needs `type_of({e_neg,_,{e_int,..}})` (c2, +2 lines).
**Measured.** c1 +29/-5, c2 +31/-5; `.abstr` unchanged (E5); refinement rows: everything A accepts, plus `2 + 3`, `0 - 5`, `-5 * 2`; `G(-5)` into `Nz` accepted only under c2, and `G(- -5)` is still refused under c2 (only a direct literal is folded in `type_of`); eunit c1 1312/1312, c2 1312/1312.
**Strongest counterargument.** It is the larger and the less finished change for a smaller gain: 30 lines of arithmetic folding in the checker to accept `2 + 3`, which nobody has asked to write in a refinement, and without a second fold in `type_of` the expression `-5` stays an `int` (E6), so `Step(-5)` is refused beside a refinement that accepts `-5`. It also gives the checker a fold that the parser, emitter and `bs_api` do not share: four consumers of `e_neg` (`bs_check.erl:2586, 2874`, `bs_emit.erl:743, 1058`) must keep agreeing about a node that `-5` still produces.

### Option C: the ticket's first option, taken literally (variant g1b, refinement only)

```csharp
module Ledger

type Delta = int where value >= -100 and value <= 100     // accepted: the refinement reads -100
public atom Sign(Delta d)
Sign(>= -100 and <= -1) -> :neg
Sign(0)                 -> :zero
Sign(>= 1 and <= 100)   -> :pos
```
Compiles under g1b (and under every fix, probe 12); refused on the base. What this option does **not** compile is the same domain with a guard on the same bound:
```csharp
type Delta = int where value >= -100 and value <= 100
public atom Band(Delta d)
Band(d) when d >= -5 and d <= 5 -> :mid                   // refused under C: the guard still cannot read -5
Band(d) when d < -5             -> :low
Band(d) when d > 5              -> :high
```
Accepted under g1, c1, c2; refused under base and g1b.
**Compiler delta.** A fold under the `refinement` rule (`bs_parser.yrl:221`): +6/-1. (A full separate sub-grammar mirroring `int_lit` would be larger; I did not build it, and it would refuse `-(5)` and `--5` as Gleam does.)
**Measured.** Probe 04 AGREEMENT block and probe 12: g1, c1, c2 accept the second program; **g1b refuses it** with `no clause matches: Band(>= -100 and <= 5)`. A declared signed domain narrows, the guard on the same bound does not.
**Strongest counterargument (for the option, not against it).** It changes the least surface: only the one position the ticket names is touched, and it is exactly what patterns already do. The cost is the hazard ticket 63's resolution already named for `not`, where parser and checker positions do not share a rule: *"An implementation keyed on the token yecc reported would have covered guards and missed refinements silently."* (`wayfinder/issues/63-negation-has-no-spelling.md`, the paragraph after line 335.) This option is the one that reintroduces that split.

## Recommendation

**A.** It is one line, it sits in the function that already holds the float-literal fold (so it is the same rule applied to the second numeric literal, not a new idea), and because both positions read the same `e_int`, guard and refinement agree by construction instead of by an extra check (the property ticket 20 §5 chose and 63 §4 relies on).
It also repairs three things the ticket does not mention and a checker-only fold does not: exhaustive guards over a negative bound (E4), `-5` typed as itself (E6), and `x / -0` slipping past ticket 38's refusal (E7). The emitted BEAM code does not change (E5).
Keep B's `2 + 3` as a separate, later question: nothing in the tree or the tickets asks for it, and A leaves it unblocked. Whether the diagnostic should additionally say *which* comparand it could not read (E2) is a different question and I did not size it.
Reason against C: it is the only option with a measured disagreement between a refinement and a guard.

## What I could not verify

- **Elm**: `elm make` cannot reach its package registry; no claim about Elm.
- **Elixir and Gleam sources** are not installed. Elixir/Gleam rows are tool output only; I cite no line for them.
- **Which commit replaced the `0 - e` desugaring by `e_neg`**: this checkout's history is condensed; the parser's own comment says F51.
- **The repo's gates** (`bin/check-*.sh`, `verify.sh`, the twice-from-a-clean-checkout rule) were not run against any variant; I ran only the eunit suite. A patch that is adopted needs the failing test and gate first (CLAUDE.md), which I did not write.
- **A literal-only sub-grammar** (the ticket's option 1 in its strictest form) was not built; g1b stands in for it and is not equivalent on `-(5)`.
- **Singleton-range defect (E10)** is reported, not diagnosed past `erl_lint.erl:3440-3444`.
- **Existing tests do not pin the refusal**: `intervals_tests.erl:46-60` pins opaque refinements by other shapes only, and no refinement test uses a negative bound (the F2 note that every scenario is non-negative is confirmed by grep), so no existing test turns red under any variant.
