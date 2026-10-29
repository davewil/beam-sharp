# Decision brief — ticket 57, `-5` in a refinement

Ticket: `wayfinder/issues/57-negative-literals-in-refinements.md` · Linear ENG-239 · 2026-10-29
**DECISION OPEN — for human review.** Nothing here resolves the ticket.

## The premise has moved (read first)

The ticket says `value >= -5` reaches the checker as `{e_op,'>=',{e_var,value},{e_op,'-',{e_int,0},{e_int,5}}}`.
**That is no longer the AST.** Since F51 (2026-09-16) unary minus is its own node, `bs_parser.yrl:587-591`,
`negate/2` at `:947-948`. Reproduced by running the real yecc-generated parser (probe `parse_out.txt`):

    value >= -5  ->  {e_op,1,'>=',{e_var,1,value},{e_neg,1,{e_int,1,5}}}

`bs_check:comparison/1` (`bs_check.erl:5154-5155`) matches only `{e_int,_,K}`, so `{e_neg,..}` is still
unreadable and the refusal still stands (RECORDED in ticket/38b, not re-run — bsc cannot be built here; the
`comparison` modelled below is transcribed from those lines). But the fix has a **cheaper third site the ticket
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
| 10 | `gl/gleam_neg.erl` | Gleam 1.12 | `-5` is a literal in both patterns and guards (`N@1 >= -5`), `2 - 7` is emitted as arithmetic `N@1 >= (2 - 7)`, `- -5` is a **syntax error** ("operator has no value on its right side"), `-n` on a variable is allowed. Hex unreachable; built with empty deps | MEASURED-HERE |
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

**A. Narrow the refinement grammar (ticket option 1, g1).** Compiler delta: replace `refinement -> expr_low`
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
Side effect to decide: `to_match`/`to_param` (`yrl:885, 933`) take `{e_int,..}`, so `(-5, a) = pair` and `fn (-5) => ..` become legal — as `(-1.5, a) = p` already is. That matches patterns (`int_lit`), but is a surface change nobody asked for.
*Strongest counterargument:* it only reads `-5`; `2 - 7` stays refused with a message that still says "comparisons on `value`". If David wants any arithmetic, C is not enough. A two-literal `0 - 5` is unrelated to the parser fold.

## Recommendation

C for the ticket's stated need (signed domains and writable residuals: rows 1-3, guards too), with the `opaque_refinement` text amended to say the bound is an integer literal. It is the smallest delta, adds zero conflicts, keeps one grammar for guards and refinements, and the float precedent is already in the file. Add B/c1 only if `-5` must also survive `e_neg` reaching the checker by other routes (none found). Do not choose A: it leaves the guard half open. Arithmetic folding (c2/c3) has no demonstrated user; ask for one first.

## Limitations

- bsc cannot be built here; "refused today" for rows 1-3 is RECORDED (ticket, 38b `:73-77`), not re-run. The checker readers and interval algebra are my own model; a real `bs_types` may differ (e.g. `norm`, empty-refinement errors were not modelled).
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
