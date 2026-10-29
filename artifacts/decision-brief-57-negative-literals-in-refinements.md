# Decision brief — ticket 57, `-5` in a refinement

Ticket: `wayfinder/issues/57-negative-literals-in-refinements.md` · Linear ENG-239 · 2026-10-29
**DECISION OPEN — for human review.** Nothing here resolves the ticket.

## The premise has moved (read first)

The ticket says `value >= -5` reaches the checker as `{e_op,'>=',{e_var,value},{e_op,'-',{e_int,0},{e_int,5}}}`.
**That is no longer the AST.** Since F51 (2026-09-16) unary minus is its own node, `bs_parser.yrl:587-591`,
`negate/2` at `:947-948`. Reproduced by running the real yecc-generated parser (probe `parse_out.txt`):

    value >= -5  ->  {e_op,1,'>=',{e_var,1,value},{e_neg,1,{e_int,1,5}}}

`bs_check:comparison/1` (`bs_check.erl:5154-5155`) matches only `{e_int,_,K}`, so `{e_neg,..}` is still
unreadable and the refusal still stands (now MEASURED-HERE against the real checker, probe 12: the unmodified `bs_check.erl`/`bs_types.erl` compile on OTP 25 with `erlc +export_all`;
only `bsc` as a whole cannot be built, because its lexer needs OTP 27 leex). But the fix has a **cheaper third site the ticket
does not list**: `negate/2` already folds a negated *float* literal (`-0.0` -> literal, `:947`). Folding an *int*
literal there is one clause. There is no parser-conflict cost and no change to what `refinement` accepts.

## What is actually being asked

1. **Gating: where does `-5` become a constant?** Three places, not two: (a) a narrower `refinement` grammar
   (ticket's option 1); (b) the checker, `comparison/1` reading/folding (ticket's option 2); (c) the parser
   action `negate/2` (new; grammar file, but not a narrowing).
2. *Follows from the gate, ask second:* if the checker, how far does the fold go — `-5` only, `+ - *`, or also `/ %`?
3. *Follows:* does the `opaque_refinement` text change (it recommends "comparisons on `value`", exactly what it refuses)?

## Evidence

| # | Probe (dir: scratchpad `probes/57/`, copy `artifacts/probes-57/`) | Claim | Result | Label |
|---|---|---|---|---|
| 1 | `parse_var.escript` -> `parse_out.txt` | AST of `-5` today | `e_neg` over `e_int`, NOT `e_op - 0 n`. `- -5` = `e_neg(e_neg 5)`; `2 - 7` = `e_op '-'`; `-x` = `e_neg(e_var)`; `-( 5 )` = `e_neg 5`; `-5 * 2` = `e_neg(5*2)` (unary binds looser than `*`) | MEASURED-HERE (real parser, hand tokens; `bs_lexer` generates on OTP 25 but does not compile: `TokenLoc` unbound, OTP 27 leex — not hacked) |
| 2 | `conflicts.escript` -> `conflicts_out.txt` | grammar conflicts | baseline 6 s/r, 0 r/r (F53 note says 5; now 6). Narrow literal-comparand rule (g1): 6/0. `'-' integer` production (g1c): 6/0. `negate/2` int fold (g2): 6/0. **No variant adds a conflict.** | MEASURED-HERE |
| 3 | `variants_ast_out.txt` | what each grammar yields | g2: `value >= -5` -> `{e_int,1,-5}`, `- -5` -> `{e_int,1,5}`, `-x` stays `e_neg`. g1c: `- -5` -> `e_neg(e_int -5)`, and `-5 * 2` re-associates to `(-5)*2`. g1: `- -5`, `2 - 7`, `-x`, `-( 5 )`, `0 - 5`, `-5 * 2` become **syntax errors** | MEASURED-HERE |
| 4 | `guard.escript` -> `guard_out.txt` | does narrowing `refinement` fix guards? | **No.** `Sign(n) when n <= -1` still parses to `e_neg` under g1; under g2/g1c it is `{e_int,1,-1}`. `guard_expr -> expr_low` (`yrl:581`) is a different rule | MEASURED-HERE (parse); what an unread guard then costs: RECORDED `bs_check.erl:5121-5127` (`unknown` -> credits no coverage) |
| 5 | `opaque.escript` -> `opaque_out.txt` | g1 changes existing behaviour | `type Email = int where WellFormed(value)` (test `intervals_tests.erl:46-53` expects `{opaque_refinement,_}`) is a **syntax error** under g1; unchanged under g2/g1c | MEASURED-HERE (parse); test impact inferred |
| 6 | `model.escript` -> `model_out.txt` | which rows each fix accepts | see matrix below. `cur` reader is transcribed from `bs_check.erl:5136-5174`; interval algebra is a 30-line stand-in | **MODEL, not bsc** |
| 7 | `neglit.escript` -> `neglit_out.txt` | emitter safe with negative `e_int` | `{integer,1,-5}`, `{op,'-',{integer,5}}` and `{op,'-',2,7}` all compile with no warnings to the same `is_ge ... {integer,-5}`. `bs_emit.erl:917` already receives negative `e_int` from `rel_expr` (`:669`, from `int_lit`) | MEASURED-HERE |
| 8 | `erl/` (`ast_out.txt`, `e.S`, `p.S`) | Erlang | parser keeps `{op,1,'-',{integer,1,5}}` (`erl_parse.yrl:240` expr, `:270` pat_expr, `:519-520` prefix_op). Patterns accept constant arithmetic (`erl_lint.erl:1904-1907`, evaluated by `erl_eval:partial_eval`, `v3_core.erl:2057-2059`): `f(2-7)`, `f(- -3)` become `select_val -5`, `3`. Guards fold in the optimiser: `X >= 2 - 7` and `X >= - -5` -> `is_ge ... -5` / `5` (`sys_core_fold.erl:842-855` fold_call) | MEASURED-HERE |
| 9 | `ex/`, `ex_out.txt`, `ex_abstract_out.txt` | Elixir 1.14 | `Code.string_to_quoted("x >= -5")` = `{:>=,_,[x,{:-,_,[5]}]}`: a general `:-` node, `-5` pattern -> `{:integer,6,-5}` (folded), guard `x >= -5` stays `{:op,_,:-,{:integer,5}}` (left to erlc), `x in -5..5` -> `{:integer,8,-5}`. No Elixir sources installed: behavioural evidence only | MEASURED-HERE |
| 10 | `gl/gleam_neg.erl` | Gleam 1.12 | `-5` is a literal in both patterns and guards (`N@1 >= -5`), `2 - 7` is emitted as arithmetic `N@1 >= (2 - 7)`, `- -5` is a **syntax error** ("operator has no value on its right side"; saved: `gl/neg2/src/neg.gleam`, `gl/gleam_dneg_out.txt`), `-n` on a variable is allowed. Hex unreachable; built with empty deps | MEASURED-HERE |
| 12 | `real/real.escript` -> `real/real_out.txt` | the REAL `bs_check:refine(int, Pred, 1)` on the real parser's ASTs | base: rows 1-3, `-5 <= value`, `- -5`, `2 - 7`, `-x` raise `opaque_refinement`; rows 4-5 accepted. g2 (and g1c): `>= -5` = `int >= -5`, Delta = `-5..5`, row 3 = `int <= -1 \| int >= 1`; `- -5` = `int >= 5` (g1c refused); `2 - 7`, `-x` still refused. Agrees cell for cell with the model. Does not cover the `c1/c2/c3` checker readers (not repo code) | MEASURED-HERE (unmodified sources, no patch) |
| 11 | Elm | — | Elm: not probed (not installed) | — |

### Matrix (probe 6, MODEL). Columns = parser variant / checker reader. Only the distinguishing columns shown

| refinement | today (base/cur) | checker `c1` (`e_neg` of literal) | checker `c2` (full literal fold) | checker `c3` (neg + `+ - *`) | g1 narrow grammar | g2 / g1c (`negate` folds) |
|---|---|---|---|---|---|---|
| `>= -5` (row 1) | refused | `>=-5` | `>=-5` | `>=-5` | `>=-5` | `>=-5` |
| `>= -5 and <= 5` (row 2, `Delta`) | refused | `-5..5` | `-5..5` | `-5..5` | `-5..5` | `-5..5` |
| `>= 1 or <= -1` (row 3) | refused | `<=-1 \| >=1` | same | same | same | same |
| `<= 3 or >= 10` (row 4) | accepted | same | same | same | same | same |
| `!= 0` (row 5) | accepted | same | same | same | same | same |
| `-5 <= value` | refused | `>=-5` | `>=-5` | `>=-5` | `>=-5` | `>=-5` |
| `>= - -5` | refused | refused | `>=5` | `>=5` | syntax error | `>=5` |
| `>= 2 - 7` (`Off`) | refused | refused | `>=-5` | `>=-5` | syntax error | refused |
| `>= -5 * 2` | refused | refused | `>=-10` | `>=-10` | syntax error | refused (`e_neg` over `*`; g1c: `(-5)*2` also refused) |
| `>= 10 / 3` | refused | refused | `>=3` | refused | syntax error | refused |
| `>= -x` | refused | refused | refused | refused | syntax error | refused |

All five ticket rows: rows 1-3 flip to accepted under **every** fix; rows 4-5 are unchanged (control: they were never the problem).
Signed residual (probe 6): `subtract(-10..10, 0)` = `-10..-1 | 1..10`; spelled as
`value >= -10 and value <= -1 or value >= 1 and value <= 10` it is opaque today and round-trips exactly under `c1` (equal to the residual).
Rewrite size (flat_size of `value >= -5 and value <= 5`): 38 words today, 34 after any fold at the parser (4 words fewer: one `e_neg` tuple gone).

## Options, as B# programs

```csharp
type Delta = int where value >= -100 and value <= 100   // A, B, C: accepted. today: refused
type Odd1  = int where value <= -1 or value >= 1        // A, B, C: accepted (the residual of Delta minus 0)
type Off   = int where value >= 2 - 7                   // A: syntax error. B(c1), C: refused. B(c2/c3): accepted, = >= -5
type Mid   = int where value >= -5 * 2                  // A: syntax error. B(c1), C: refused. B(c2/c3): accepted
type Bad   = int where value >= -x                      // always refused; A reports it as a syntax error, not opaque_refinement
Sign(n) when n <= -1 -> :neg                            // A: guard still unread (no coverage credit). B, C: read
```

**A. Narrow the refinement grammar (ticket option 1, g1).** *Full cost.* The g1 I built admits only `lident op int_lit`; that is a floor, not the whole bill. `comparison/1` also reads atom and string comparands (`value == :ok`, F68, `bs_check.erl:5156-5164`), so a faithful narrow grammar must enumerate every comparand kind the checker reads, and gain a production each time the checker does — the drift the `expr_low` rule exists to avoid. Add the three new syntax errors, the changed `opaque_refinement` test, and the guards left unfixed. Compiler delta: replace `refinement -> expr_low`
(`bs_parser.yrl:221`) with ~10 lines (`ref_or/ref_and/ref_cmp/ref_op`, using `int_lit`); no checker change.
Evidence: 0 conflicts added (probe 2). Costs measured: `2 - 7`, `-x`, `WellFormed(value)` become *syntax* errors (probes 3, 5),
so `opaque_refinement` can no longer fire for them and test `intervals_tests.erl:46-53` changes kind; guards stay unfixed (probe 4).
*Strongest counterargument (yrl:218-220's own words):* it reintroduces the split between refinement and guard that `refinement -> expr_low` exists to prevent; Sign-style guards on negatives keep silently crediting nothing.

**B. Checker reads/folds the comparand (ticket option 2).** Compiler delta, in `bs_check.erl:5154-5155`: replace the
`{e_int,_,K}` match by a `konst/1` helper. `c1` is one clause (`{e_neg,_,{e_int,_,K}}` -> `-K`), ~3 lines; `c2` is a ~10-line recursive fold of
`e_neg` and `+ - * / %` over literals (must refuse `/ 0` and use truncating `div`/`rem` per ticket 38, else it disagrees with `bs_emit`); `c3` stops at `+ - *`.
Evidence: matrix; guards fixed too, because guards share `alternatives/1`. Grammar, tests of `opaque_refinement` for `WellFormed(value)`, `-x` unchanged.
*Strongest counterargument:* it creates a second constant evaluator that must agree with erlc's (`/ %`, bignums) — the only choice with a place to drift; and `c2` accepts `value >= -5 * 2`, a form nobody writes, to buy `2 - 7`, which nobody wrote either (ticket: "`2 + 3` probably").

**C. Fold at the parser action (`negate/2` + int clause; g2) — not in the ticket.** Compiler delta: one line beside `bs_parser.yrl:947`:
`negate(_L, {e_int, IL, N}) -> {e_int, IL, -N};`. Mirrors the float fold already there. Evidence: 0 conflicts, rows 1-3 accepted, guards fixed, `- -5` -> `5`, `-x` still `e_neg` -> refused as before, emission identical (probes 2, 3, 7).
**Typing side effect (verifier finding 3; source-read, not measured):** `type_of({e_int,_,N})` is the singleton `range(N,N)` (`bs_check.erl:2956`); `type_of({e_neg,..})` is `int` (`:2963-2972`). After the fold every written `-5` is the singleton `-5..-5` instead of `int`. Upside: `Take(-5)` for a `Delta` parameter is accepted (today `int` is not a subtype of `-100..100`). Cost: inference, residuals and diagnostic text for any expression containing a literal negative change, and F2's closed-residual rule (a catch-all after a fully covered singleton is an error) can newly fire. The 1000+ test suite was not run to see what moves.
Also decide: `to_match`/`to_param` (`yrl:885, 933`) take `{e_int,..}`, so `(-5, a) = pair` and `fn (-5) => ..` become legal — as `(-1.5, a) = p` already is. That matches patterns (`int_lit`), but is a surface change nobody asked for.
*Strongest counterargument:* it only reads `-5`; `2 - 7` stays refused with a message that still says "comparisons on `value`". If David wants any arithmetic, C is not enough. A two-literal `0 - 5` is unrelated to the parser fold.

## Verification

Independent re-run: `artifacts/verification-57.md` — all probes byte-identical, no circularity found in probes 1-5, 7-9; it supplied the real-checker run (now probe 12), flagged the missing Gleam `- -5` evidence (added), the understated cost of A and the singleton typing under C (both added). Its citation nit: 38b is `wayfinder/prototypes/38b_divisor_expressiveness.sh:71-77`, a script, not a ticket.

## Recommendation

C for the ticket's stated need (signed domains and writable residuals: rows 1-3, guards too), with the `opaque_refinement` text amended to say the bound is an integer literal. It is the smallest delta, adds zero conflicts, keeps one grammar for guards and refinements, and the float precedent is already in the file. Add B/c1 only if `-5` must also survive `e_neg` reaching the checker by other routes (none found). Do not choose A: it leaves the guard half open and must track the checker's comparand kinds. The recommendation survives the verification, with C's singleton-typing change now a named risk to check against the test suite before landing. Arithmetic folding (c2/c3) has no demonstrated user; ask for one first.

## Limitations

- `bsc` as a whole cannot be built here (lexer needs OTP 27 leex). `bs_check`/`bs_types` alone do run (probe 12), so rows 1-3 refusal is measured. The `c1/c2/c3` readers and probe 6's interval algebra are my own model, not repo code.
- `bs_lexer` was not usable (OTP 27 leex); ASTs come from hand-made tokens. A lexer bug (e.g. `-5` lexed as one token) would not show; `bs_lexer.xrl:180` emits `-` separately.
- yecc reported 6 conflicts for the baseline, F53's recorded 5 is stale; the OTP 25 yecc count may differ from OTP 28.
- Test impact of A and C on the 1000+ test suite was not run. Elm not probed. Elixir/Gleam evidence is behavioural.

## Probe index (from `artifacts/probes-57/` or scratchpad `probes/57/`)

- Everything at once: `./run_all.sh` (rebuilds `var/*.yrl` from the repo grammar; never edits the repo).
- 1,3: `escript parse_var.escript base|g1|g1c|g2` (needs `var/*_p.beam`; run_all builds them)
- 2: `escript conflicts.escript` · 4: `escript guard.escript` · 5: `escript opaque.escript`
- 6: `escript model.escript` · 7: `escript neglit.escript`
- 8: `cd erl && escript s.escript && erlc -S e.erl p.erl` · 9: `cd ex && elixir q.exs; elixirc m.ex && elixir ab.exs`
- 10: `cd gl/neg && gleam build` (strip deps from gleam.toml first), output `gl/gleam_neg.erl`
