# 57 — A refinement cannot say `-5`, though a pattern can: decision brief

Ticket: `wayfinder/issues/57-negative-literals-in-refinements.md` · Linear [ENG-239](https://linear.app/davewil/issue/ENG-239)
Date: 2026-09-29 · Repo HEAD probed: `51bfb6f` · Status: decision open — for human review

Everything below was run against **copies** of `compiler/src` (nothing under `compiler/` was edited).
Variants (patches in `artifacts/probes/57/patches/`):

| id | what it is | lines |
|---|---|---|
| base | unpatched HEAD copy | 0 |
| **A** | `bs_parser.yrl` `negate/2`: a negated integer literal is the literal, `negate(_, {e_int,L,N}) -> {e_int,L,-N}` (one clause beside the existing float one) | +1 |
| **Aprod** | new production `expr_low -> '-' integer` (the literal mirror of `int_lit`) | +1 |
| **B0** | `bs_check.erl`: new `const_int/1` (literal, `e_neg` of a constant); `comparison/1` reads it, nothing else does | +10 |
| **Bn** | B0 + `type_of({e_neg,..})` uses `const_int/1`, so a `-5` *value* is typed `-5..-5` | +27 −9 |
| **Ba** | Bn + `const_int/1` also folds `+ - *` of constants (`2 + 3`, `5 - 10`) | +34 −9 |

## 1. Sub-decisions the ticket implies (gating first)

1. **Is the dichotomy real?** The ticket sets "grammar" against "checker" and worries that a grammar fold
   "narrows the grammar at one site". Probe `AGREE`/`G1` show variant A does not: the fold sits in the
   *shared* expression rule, so guard and refinement still read one grammar (`refinement -> expr_low`,
   `bs_parser.yrl:221`) and both reach `alternatives/1` (`bs_check.erl:4923`) as `{e_int,_,-5}`. A fold
   at the refinement production only (a third design, **not built**) would be the split the ticket fears.
2. **Does the fix reach a `-5` *value*, or only a comparand?** Today `Id(-5)` into `int where value != 0`
   is refused (V1, base) because `-5` is typed `int`, not `-5..-5`. This is a second face of the same
   gap and it separates the variants (B0 fixes the declaration only).
3. **Where does the fold stop?** `-5` only, or `2 + 3` too. Ba folds arithmetic in a comparand but the
   checker types `2 + 3` as `int` (V2), so Ba accepts `Id(-(2+3))` and refuses `Id(2+3)` (V3).
4. Consequence to accept whichever wins: `n / -0` becomes a refused provably-zero divisor (D1).

Decide 1+2 (one choice: A vs B0/Bn); 3 follows (recommendation: stop at the literal).

## 2. Probes

Expectations are written in `cases.sh`/`run.sh`/`measure.sh`/`abstr.sh`/`neighbours/*` headers *before* the
run. Full run: `artifacts/probes/57/run.out` (216 checks on the six compilers: 0 FAIL), `abstr.out`,
`measure.out`, `neighbours.out`. Codes: a = accepted, r = refused. Six columns = base A Aprod B0 Bn Ba.

| id | claim tested | expected before run | observed | file |
|---|---|---|---|---|
| REF R1-R5 | the ticket's five-row table on the **reference** compiler (`bsc.sh`) | r r r a a | r r r a a — PASS | `cases.sh`, `run.out [REF]` |
| R1-R5 | same five rows on all six builds | base `r r r a a`; all others accept R1-R3 | PASS (30/30) | `run.out [R1]..[R5]` |
| R6,R8,R9 | `>= 2 + 3`, `5 - 10`, `2 * 3` | r r r r r a | PASS | `[R6]`,`[R8]`,`[R9]` |
| R7 | `>= -(-5)` | r a r a a a (parens transparent to A, not to Aprod) | PASS | `[R7]` |
| R10 | `-5 <= value` | r a a a a a | PASS | `[R10]` |
| R11,R12 | `>= n`, `>= Min()` stay refused | r in all six | PASS | `[R11]`,`[R12]` |
| V1 | `Id(-5)` into `!= 0` | r a a r a a | PASS | `[V1]` |
| V2,V3 | `Id(2+3)`, `Id(-(2+3))` into `!= 0` | V2 r everywhere; V3 a only in Ba | PASS | `[V2]`,`[V3]` |
| V4,V6 | true violations (`Id(0)`, `Id(-101)`) stay refused | r everywhere | PASS | `[V4]`,`[V6]` |
| V5 | `Id(-100)` into `Delta = -100..100` | r a a r a a | PASS | `[V5]` |
| G1,G4 | guard partition on `-5`, no catch-all (also `switch` arms) | r a a a a a | PASS | `[G1]`,`[G4]` |
| G2 | guard partition on `2 + 3` / `5` | r r r r r a | PASS | `[G2]` |
| G3 | unread guard + catch-all | a everywhere | PASS | `[G3]` |
| P1-P3 | patterns: `<= -1`, `-1`, `<= 2 - 3` | a, a, r everywhere | PASS (`int_lit` is literal-only) | `[P1]..[P3]` |
| P4 | `<<-1:8, rest>>` | first written `a` (parses); **observed `r` in all six** ("-1 does not fit in 8 bits") | first prediction WRONG, corrected expectation `r` written after seeing the diagnostic, recorded in `cases.sh` | `[P4]` |
| S1,S2 | `In(-5..5)`, `record R { X: int where value >= 5 }` | r r r r r r (no such syntax, independent of the gap) | PASS | `[S1]`,`[S2]` |
| S3 | record field of a refined alias `-5` | r a a a a a | PASS | `[S3]` |
| D1 | `n / -0` | a r r a r r | PASS: A, Aprod, Bn, Ba newly refuse (ticket 38 §2 rule) | `[D1]` |
| AGREE | `D = -5..5` refinement vs guard at -6,-5,0,5,6 (exported boundary) | R and G agree on the accept set; R crashes `function_clause` outside (F37), G returns `:out`; base cannot declare D | PASS in all five patched builds | `[AGREE]` |
| GUARD-RUNS | emitted guard `n >= -5 and n <= 5` decides -6:out -5:in 0:in 5:in 6:out | same in all six | PASS | `[GUARD-RUNS]` |
| RESIDUAL | `Kind(0)` over `Delta = -10..10` prints two heads, pasteable | `Kind(>= -10 and <= -1)`, `Kind(>= 1 and <= 10)`, re-accepted | PASS; base cannot declare Delta. The printed *type* text `int <= -11 \| int >= 11` is refused as a type in all six (heads are pasteable, types are not) | `[RESIDUAL]` |
| ARITH | `-7/2`, `-7%2`, `- 2*3 + -4 - -1`, `10 - -3` | -3, -1, -9, 13 in all six (folding must not change values) | PASS | `[ARITH]` |
| AST | what `value >= -5` parses to | base: `e_neg(e_int 5)`; A, Aprod: `e_int -5` | PASS. **The ticket's `0 - 5` desugaring is stale**: F51 (2026-09-16) replaced it with `e_neg` (`bs_parser.yrl:589,944`) | `[AST]` |
| ABSTR | emitted abstract format of `10 - -3` | base/B*: `{op,_,'-',{integer,_,3}}`; A/Aprod: `{integer,_,-3}`; beam size within 64 B | PASS; Arith.beam 1344 B base, 1336 A, 1324 Aprod (path/`erlc` noise, +/- 20 B) | `abstr.sh`, `abstr.out` |
| REGRESS | repo eunit suite per variant | failing-test **set** equals base's | PASS: sets identical for all five (§4) | `regress.sh`, `regress-out/` |

## 3. Neighbouring languages

Sources of Erlang, Elixir, Gleam and Elm are **not installed** (no `.yrl`/`.erl` under `/usr/lib/erlang`,
`/usr/lib/elixir`; Gleam is a binary), so no `file:line` is cited; every row is behaviour probed
(`neighbours/run.sh`, output in `neighbours.out`, all PASS/RECORD as pre-stated).

| language | finding (probe) |
|---|---|
| Erlang/OTP 25 | `erl_parse` of `-5.` is `{op,_,'-',{integer,_,5}}`: the parser does not fold (EL1, EL2); pattern `f(-5)` compiles (EL3); arithmetic of literals is accepted in a pattern `f(2+3)` (EL4) and in a guard `X >= 2+3` (EL5); `f(2+X)` is refused (EL6); the abstract format also accepts `{integer,L,-5}` (EL7), i.e. what A emits. Erlang folds in the compiler, later. |
| Elixir 1.14.0 | `Code.string_to_quoted("-5")` is `{:-, _, [5]}` (E1), and `x >= -5` carries that node (E2); tokenizer gives `:dual_op` then `:int` (E7b); the *expander* folds unary minus over an integer literal (`Macro.expand({:-,[],[5]})` is `-5`, E3b) but not `2 + 3` (E8); guards `>= -5`, patterns `-5`, guards `>= 2 + 3` all work (E4-E6). First-run predictions E3, E7 were wrong and are recorded as such in `elixir.exs`. |
| Gleam 1.12.0 | offline `gleam build` works with no dependencies. `n if n >= -5` compiles and runs (GL1), pattern `-5` (GL2). A guard `n >= 2 + 3` **compiles** (GL3; first prediction "refused" was wrong, recorded). `n >= -{2 + 3}` is a syntax error (GL4), `2 * 3` compiles (GL5). |
| Elm 0.19.2 | **could not run**: `elm init` needs `package.elm-lang.org`, proxy returns 403. Nothing about Elm is claimed. |

Reading: no neighbour treats `-5` as a token; the three that ran accept it in a comparison and a pattern, the
two BEAM neighbours *accept* it (verifier: `erl_parse` does not fold `-5`, it yields `{op,1,'-',{integer,1,5}}`; where either compiler folds, if it does, was not probed and no neighbour source is installed), and all three surveyed guard grammars
take arithmetic of literals. The neighbours do not settle grammar-vs-checker; they say only that
"`-5` is a literal at the point a constant is needed" is the norm.

## 4. Measurements

- **yecc conflicts** (M1): base, A, Aprod, B0, Bn, Ba all report `6 shift/reduce, 0 reduce/reduce`.
  In `verbose` mode base/A/B0/Bn/Ba list 232 precedence-resolved parse-action conflicts; **Aprod lists
  281** (+49), the cost of a second production starting with `'-'` (expected, confirmed).
- **Lines changed** (M2, `git diff --no-index --shortstat`): A +1, Aprod +1, B0 +10, Bn +27/−9, Ba +34/−9.
  Expectation "Bn ~25, Ba ~35" was on target for insertions.
- **Compile time** (M3), 200-refinement module (`type Ti = int where value >= i and value <= i+10`,
  plus a function per type), `bsc:file_to_dir`, 7 runs interleaved across builds, ms, min / median:

  | build | non-negative bounds | negative bounds (`>= -i`) |
  |---|---|---|
  | base | 250 / 291 | 46 / 67 (refused, error path) |
  | A | 248 / 275 | 249 / 276 |
  | Aprod | 271 / 292 | 232 / 273 |
  | B0 | 265 / 293 | 263 / 286 |
  | Bn | 283 / 321 | 259 / 291 |
  | Ba | 210 / 289 | 267 / 312 |

  Expectation "no variant differs beyond noise" holds with a caveat: the host was shared and loaded
  (load average 4-8 while measuring); base's own spread is 250-310, so a Bn/Ba +10% median is not
  distinguishable from noise here. A fold is not visible next to the ~1.4 ms/refinement compile.
- **Abstract format / .beam**: see ABSTR; `erlc` folds either shape to the same constant.
- **Regression** (eunit, `compiler/test/*_tests.erl`, OTP 25, one variant at a time; `regress.sh` saves
  the failing-test set): 

  | build | passed | failed | failing set vs base |
  |---|---|---|---|
  | base | 1248 | 55 | (reference) |
  | A, Aprod, B0, Bn, Ba | 1248 each | 55 each | identical (`comm -3` empty), `probes/57/regress-out/` |

  So none of the five changes breaks or newly fixes any test; the 55 are environmental (json/maps on
  OTP 25; e.g. `diagnostic_json_tests`, `map_validate_tests`). The suite has no negative-bound refinement
  test, which is why it cannot tell the variants apart from base (the ticket states all five of F2's scenarios are non-negative; not re-verified).

## 5. Options

### Option 1 — fold in the grammar (A; Aprod is the same idea, worse)

```csharp
type Delta = int where value >= -100 and value <= 100     // accepted
public atom Kind(Delta d)
Kind(0)           -> :zero
Kind(>= -10 and <= -1) -> :neg                             // residual heads paste back, as before
public int Go() -> Id(-5)                                  // -5 is typed -5..-5: into `!= 0` accepted
```

Compiler delta: one clause in `bs_parser.yrl` `negate/2`, beside the existing `{e_float}` clause
(`bs_parser.yrl:944`): `negate(_L, {e_int, IL, N}) -> {e_int, IL, -N}`. No checker change, no new
symbol-table entry, no emitted function. The emitter already handles `{e_int,_,N}` for negative `N`
(`bs_emit.erl:909`; ABSTR shows `{integer,_,-3}`).

Evidence: R1-R3, R7, R10, S3 accepted; V1/V5 accepted (the `-5` value is typed `-5..-5`, base refuses
it); G1/G4 exhaustive; AGREE/GUARD-RUNS agree; ARITH values unchanged; yecc unchanged (6 s/r, 0 r/r);
no reasoning about where folding stops is needed because `2 + 3` is simply not touched (R6/R8/R9 stay
refused). Precedent: `negate` already folds a negated float literal so `-0.0` is a literal.

Strongest counterargument: it changes the AST of every `-5` in every expression, not only in a
refinement (ABSTR: `{op,'-',3}` becomes `{integer,-3}`), and it newly refuses `n / -0` (D1: A, Aprod).
`-(-5)` folds too (R7, A only), which is arguably unexpected; Aprod avoids it but adds 49 conflict
reports (M1) for a 1-line gain. Anything that pattern-matches on an `e_neg` node (F48's
ast-as-a-value lists `e_neg`, `compiler/features/F48-ast-as-a-value.md:40`) would see a literal
instead; whether F48's users see it is not measured (§7).

### Option 2 — fold in the checker (B0 / Bn / Ba)

```csharp
type T = int where value >= -5 and value <= 5             // accepted under B0, Bn, Ba
public int Go() -> Id(-5)                                 // B0: still refused ("argument not covered");
                                                          // Bn and Ba: accepted
type U = int where value >= 2 + 3                         // Ba only; B0/Bn still opaque_refinement
```

Compiler delta (`bs_check.erl`): new `const_int/1` (literal; `e_neg` of a constant; in Ba also
`+ - *`); `comparison/1` (`bs_check.erl:4941-4942`) gains two clauses that call it for the
right and left operand; for Bn/Ba `type_of({e_neg,..})` (`bs_check.erl:2867`) short-circuits through
`const_int/1` and the old body moves to `type_of_neg/4`. Parser unchanged (`e_neg` stays).

Evidence: R1-R3, R10, S3, G1, G4, AGREE, GUARD-RUNS, RESIDUAL pass as in Option 1. B0 leaves V1/V5
refused (a `-5` value still types as `int`): the declaration is writable and the value cannot be
passed, so `Id(-100)` into `Delta` fails. Bn fixes that (+17 net lines). Ba widens to arithmetic (R6,
R8, R9, G2 accepted) and then disagrees with the value typing it sits beside: V2 refuses `Id(2+3)`,
V3 accepts `Id(-(2+3))`.

Strongest counterargument: two readers of one literal (`const_int/1` in the checker, `int_lit` in the
pattern rule) is exactly the divergence the ticket started from, now with a third member; Ba makes the
refinement and value sides disagree (V2/V3); and the `alternatives/1` comment says a guard and a
refinement share one reading — B keeps that only because `comparison/1` is shared, which is also true
of A with less code. Also `AST` is unchanged (`e_neg` remains), which is B's one real advantage: no
change visible to AST consumers.

### Third design, not built: fold only at the `refinement` production

A refinement-only rule would let refinements read `-5` while a guard `n >= -5` still reaches the checker as
`e_neg`. That is the split the ticket names as the reason the grammar is shared; no probe was written
because G1 already shows a guard and a refinement need the same reading.

## 6. Recommendation

Option 1, variant **A** (the one-line `negate` clause), stopping at the literal: no arithmetic
folding. It is the smallest change (+1 line, 0 new conflicts), it is what patterns already do
(`int_lit`) and what `negate` already does for floats, it fixes the value side as well
(V1/V5, which B0 does not), and it keeps guard and refinement on one grammar
(AGREE/G1), which answers the ticket's own objection. Accept D1 explicitly: `n / -0` is
a refused provably-zero divisor from now on (it is what ticket 38 §2 says such a divisor is), and
**correction (verifier): Bn does NOT escape it** (D1: Bn refuses `n / -0` too; only B0 accepts it, and B0 fixes neither V1 nor V5). Fall back to Bn (not B0, not Ba)
if AST stability for F48 consumers matters more than one line.

Whichever wins, F2 needs a scenario with a negative bound (all five of its scenarios are
non-negative — the reason the gap survived), and `opaque_refinement`'s advice should keep pointing
at forms it accepts (unchanged by this ticket).

## 7. Not measured / limits

- Probes ran on **OTP 25**; the tickets cite OTP 28. OTP 25 lacks `maps:iterator/2` and `json:decode/1`;
  the base suite has 55 failing tests here (18 test modules, environmental; ticket 59's author cites ~451
  on the same OTP — the counts differ and were not reconciled; compare **sets**, §4).
- Elm not run (registry 403). Elixir/Erlang/Gleam sources not installed, so no `file:line`; Gleam's
  and Elixir's parsing was inferred from probed behaviour only.
- Not measured: `to_match`/`to_param` (`bs_parser.yrl:882,930`) turning an `e_int` into `p_int`, so
  under A an expression-parsed `-5` in a match context becomes a literal pattern where base yields an
  `e_neg`; F48 ast-as-a-value consumers seeing a different node for `-5`; the docs' formatter/LSP.
- Build differences: the experimental compilers are built with the OTP-25-patched lexer generator
  (`scratchpad/newleex`), same for base; the `cli_tests` escript is rebuilt from each variant's ebin.
- M3 timing on a loaded shared host; min/median of 7 runs, one module shape only.
- Sub-decision 3 (where the fold stops) is only probed for `+ - *` on integer literals, not division,
  floats, or named constants.

## 8. Reproduce

```sh
cd artifacts/probes/57
./run.sh                     # rebuilds base+5 variants from patches, then all probes, abstr, neighbours, measure
./run.sh --no-setup --quick  # reuse builds, only the 216 compiler probes
./run.sh --no-setup --regress   # additionally the eunit suites, ONE variant at a time (~5 min each)
./neighbours/run.sh          # Erlang/Elixir/Gleam/Elm probes only
```

Scratch builds live under `$W` (default `.../scratchpad/work/57`); override with `W=`.

## Verifier corrections and additions (independent re-run, 2026-09-30)

All measured claims REPRODUCED from an independent rebuild of base, A, Aprod, B0, Bn, Ba (216 checks, 0 FAIL); yecc 6 shift/reduce, 0 reduce/reduce in every build (verbose reports 232 vs 281 for Aprod); lines changed A +1, B0 +10, Bn +27/-9, Ba +34/-9; stale `0 - 5` premise confirmed (`bs_parser.yrl:589`, `:944-945`, `bs_check.erl:2867`; reference AST `{e_neg,{2,29},{e_int,{2,30},5}}`, under A `{e_int,{2,30},-5}`); eunit failing set identical to base for all five variants (1248 pass / 55 fail; a deliberately broken A mutant gave 62 fails, so the runs do exercise patched code); mutation tests (revert A, add a `value >= n` fold to Ba, shift the emitter's `>=`) all turned the matching probes red; 200-refinement compile time indistinguishable across builds (verifier load 0.9-1.2). Wrong first-run predictions (P4, Elixir E3/E7, Gleam GL3) are honestly labelled in file headers, but their order relative to the runs is not independently checkable (artifacts were untracked).
Additions the brief did not state, consequences of A:
- **Match context:** a bare-`=` body line `-1 = n` is refused at base ("the left of a bare `=` must be a literal pattern") but accepted as a literal pattern under A (then fails with "this bind in F can fail ... int <= -2 | int >= 0"). The tuple form `{-1, _} = ...` is a syntax error before and after. A silently widens what a bare `=` accepts.
- **Diagnostic columns:** under A the folded literal carries the digit's column (`{2,30}`), not the minus's (`{2,29}`), so carets on `-5` shift by one.
- **Regression blind spots:** the AoC corpus test (the best parse-change check) is dead at base (fewer than 3 AoC dirs); the 11 `diagnostic_json` tests fail at base too, so they cannot see a moved diagnostic position; the suite has negative-literal tests but no negative-bound refinement test. `every_example_still_compiles` does run and passes.
- The measure.sh header predicted a new reduce/reduce for Aprod; observed 0, not flagged above.
- Still not measured: F48 AST-as-a-value consumers, formatter, LSP (risk looks low since A adds no node kind).
