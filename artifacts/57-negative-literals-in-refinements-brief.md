# Brief: ticket 57 (ENG-239) — a refinement cannot say `-5`, though a pattern can

Status: **OPEN - for human review.** Ticket: `wayfinder/issues/57-negative-literals-in-refinements.md`.
Probes: `artifacts/probes/57/` (`bash run.sh`; `bash run.sh --eunit` adds the ~12 min suite comparison).
Nothing under `compiler/` was touched; variants are built from a copy in `probes/57/work/`.

## Ticket and gating question

The ticket asks: *where does the fold belong, the grammar or the checker?* Measurement says the
question is framed one level too low (see "Contradicted" below). The gating question is:

> **Is `-5` in expression position the integer literal `-5`, or a negation applied to `5`?**

Everything else follows from the answer. The program that separates the two answers, run against both
builds (`probes/57/run_literal_value.out`):

```csharp
type Delta = int where value >= -100 and value <= 100
public Delta D()
D() -> -3          // literal answer: compiles. negation answer: refused, `-3` is typed `int`
```

## Contradicted or newly found (read these first)

1. **The ticket's mechanism is stale.** It says unary minus desugars to `0 - e`. Since F51 it does not:
   `-5` parses to `{e_neg, L, {e_int, L, 5}}`; only a literal `0 - 5` yields the subtraction node
   (`probes/57/ast.out`; `bs_parser.yrl:589` `expr_low -> '-' expr_low : negate(...)`, `bs_parser.yrl:944-946`).
   **The parser already folds a negated *float* literal into the literal** (`negate(_L, {e_float,FL,F}) ->
   {e_float,FL,-F}`, yrl:944, written for `-0.0`) and deliberately leaves ints alone. So a third site exists
   that the ticket does not list: the shared `negate/2`, one clause away from folding ints too.
2. **The defect is not refinement-only; guards have it, with a worse symptom.** `alternatives/1` serves both
   (`bs_check.erl:4931-4955`, `refine/3` at 1898). A guard `when n >= -5` reads as `unknown`, credits no
   coverage, and the pair `F(n) when n >= -5 / F(n) when n < -5` is refused **"F is not exhaustive"** with no
   mention of the literal (`probes/57/guard_cur.out`); the same pair with `5` compiles. The ticket's
   exhaustiveness-residual argument is therefore live today, not "the next feature".
3. **Why it survived:** zero uses. No `.bs` under `compiler/examples` has a negative literal after a comparison
   operator; the only embedded ones are the relational *pattern* `(<= -1)` and unrelated bodies
   (`probes/57/run_corpus.out`). No `2+3`, `0-5`, or `-(-5)` appears anywhere in tests or examples.
4. **Unrelated crash found on the way:** `type T = int where value == 3` (and `>= 3 and <= 3`) fails with
   `compile: ...:0: bad range type` at line 0, for a *non-negative* literal (`probes/57/run_eq.out`). A singleton
   refinement cannot be written. Not in scope; **should be its own ticket** (I did not root-cause it; the message
   is from the Erlang compiler step, so the emitted boundary guard for a one-point range is malformed).

## Sub-decisions the ticket implies

| # | Sub-decision | Gates / follows |
|---|---|---|
| G | Is `-5` a literal or a negation of 5? (above) | **gating** |
| 2 | Does the fold extend past a sign: `2+3`, `0-5`, `-(-5)`, `5-10`? | follows G; ticket says "`2+3` probably" |
| 3 | Is a narrowed refinement grammar (ticket's option 1) wanted at all? | answered by G: no, G=literal fixes it without narrowing |
| 4 | Does `value == K` in a refinement work (side finding 4)? | independent, separate ticket |

Only G is asked. 2 follows: if `-5` is a literal, `2+3` has no reason to be one (zero corpus uses) and stays
refused; if G is "negation", 2 is the whole question.

## Evidence

| Claim | Probe | Result | Verdict |
|---|---|---|---|
| Ticket's 5-row table | `probes/57/run_table.sh` -> `table_cur.out` | rows 1,2,3 refused; `<=3 or >=10` and `!= 0` accepted | **confirmed** exactly |
| Refusal covers every operator/side | same, 23 predicates | `> -1`, `!= -1`, `-5 <= value`, `== -3` (see 4), `-100..100` all refused | confirmed |
| `-5` lowers to `0 - 5` | `ast.escript` -> `ast.out` | `{e_neg,_,{e_int,5}}`; `0 - 5` is the only subtraction node | **contradicted** |
| Pattern `(<= -1)` is a literal | `ast.out` last block | `{p_rel,_,'<=',-1}` (yrl:395, 470) | confirmed |
| Guards have the same defect | `run_guard.sh` -> `guard_cur.out` | `n >= -5 / n < -5` -> "not exhaustive"; `5` version compiles | **new** |
| A one-line parser fold fixes it | `run_compare.sh` (variant A) -> `run_compare.out` | 16 of 23 predicates accepted (current: 4); guard pair compiles | confirmed |
| Checker fold fixes it | same (variant B) | 22 of 23 accepted incl. `2+3`, `5-10`, `1+2*3`; `== K` still refused | confirmed |
| Negative bounds are sound at the exported boundary (F37) | `run_runtime.sh` -> `run_runtime.out`, `_B.out` | `Delta` -100..100: -100,0,100 pass; -101,101 `function_clause`; identical under A and B | confirmed |
| A lets you *construct* a negative `Delta`; B does not | `run_literal_value.sh` | A: `D() -> -3` ok. B: refused, "not covered: `int <= -101 \| int >= 101`" | **A/B differ here** |
| No regressions | `eunit_A.out`, `eunit_B.out`, `eunit_baseline.out` | 1307 pass, same 5 failures in all three (identical test names) | no regression; the 5 are environmental in my copy (I did not chase why; `features/` is absent from the copy, so the cause is unverified) |
| Compile-time cost | `run_cost.sh` -> `run_cost.out`, N=15 | cur 352-413 ms (median 378), A 345-419 (377), B 355-398 (375) | no measurable difference (VM boot dominates) |
| Emitted shape | `run_cost.out` | A: `{integer,L,-5}`; B and cur: `{op,L,'-',{integer,L,5}}`; beam 952 B (A) vs 960 B | trivially smaller under A |
| Patch size | `run_cost.out` | A: 1 line in `bs_parser.yrl`; B: 15 lines in `bs_check.erl` (`fold_int/1` + 2 `comparison/1` heads) | measured |

## Neighbour survey

- **Erlang** keeps a unary-op node in the parse: `-5` -> `{op,1,'-',{integer,1,5}}`, `2+3` -> `{op,1,'+',...}`
  (`neighbours_erlang.out`). Folding is done *downstream, at the use site*: `erl_parse.yrl:1819-1820`
  `normalise({op,_,'-',{integer,_,I}}) -> -I`, and for patterns/guards `erl_eval.erl:1804-1815` +
  `partial_eval/1` (erl_eval.erl:2204) evaluates arbitrary constant arithmetic; `erl_lint.erl:2140` accepts the result
  only if it folds to a literal. That is the checker-fold model, with the *full* arithmetic power, not just a sign.
  (Paths under `/nix/store/qlclzl3...-erlang-28.5.0.7/lib/erlang/lib/stdlib-7.3.0.3/src/`.) `erl_lint` also accepts a literal
  `{integer,1,-5}` node, which is what variant A emits.
- **Elixir** `Code.string_to_quoted("-5")` -> `{:-, [line: 1], [5]}`, `-(-5)` nests, `0 - 5` and `2 + 3` are binary
  nodes (`neighbours_elixir.out`); `when x >= -5` and `f(-6)` both compile. Same shape as Erlang: negation node,
  fold later. The installed tree has no readable `.ex` source for the parser (only beams), so no file:line.
- **Gleam** 1.19.0 (binary only, no source installed; behavioural probe `run_gleam.out`): pattern `-5` ok, guard
  `n >= -5` ok, guard `n >= 2 + 3` ok, guard `n >= 0 - 5` ok, **pattern `2 + 3` is a syntax error**, `const lo = 2 + 3`
  is "Unsupported operator in constant expression", `- -5` is a syntax error. So Gleam treats `-5` as a literal in
  patterns and constants, and allows arithmetic only where an expression evaluates at runtime. It does not fold
  arithmetic into constants.
- **Elm** 0.19.2: **not measured.** The probe needs `elm/core` from package.elm-lang.org, unreachable from this
  sandbox (`run_elm.out`: MISSING DEPENDENCY on every case). I make no claim about Elm.
- **This repo**: `refinement -> expr_low` with the F2.5 rationale that a refinement and a guard cannot disagree
  (`bs_parser.yrl:217-221`, `features/F2-interval-refinements.md:187`); F51 chose the `e_neg` node for kind preservation
  (`features/F51-float.md:61`, `bs_check.erl:2870-2885`); the literal's type today is `int`, not a singleton
  (`type_of({e_neg,...})` returns `bs_types:int()`), while `type_of({e_int,_,N})` is `range(N,N)` (`bs_check.erl:2867`).

## Options

### Option A: `-INT` is a literal (fold in the parser's `negate/2`)

```erlang
negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};
negate(_L, {e_int,   IL, N}) -> {e_int,   IL, -N};     %% the one added line
negate(L, E)                 -> {e_neg, L, E}.
```

Accepts: `value >= -5`, `!= -1`, `> -1`, `-5 <= value`, `-(5)`, `(-5)`, `- 5`, `-0`, `-100..100`, and the guard pair.
Refuses: `0 - 5`, `2 + 3`, `5 - 10`, `-5 + 0`, `2 * 3` (still `opaque_refinement`).
Also now accepts `D() -> -3` as a `Delta`, because `-3` is typed `-3..-3` like `3` already is.
Compiler delta: one clause; no new symbol, pass, or emitted function. Both `alternatives/1` consumers (refinement, guard)
and the F37 boundary guard inherit it with no further change (`run_runtime.out`). Evidence: eunit equals baseline.

**Strongest counterargument.** It changes the *language-visible type of every `-N` expression* from `int` to a singleton,
not just in refinements: residual and "not covered" diagnostics now print `-3..-3`-style types where they printed `int`,
and any later rule keyed on `int` vs singleton sees negatives differently. No eunit test moved, but the corpus has few
negative-literal programs (finding 3), so the suite is weak evidence here. It also leaves `0 - 5` giving the same
self-contradicting `opaque_refinement` message ("write a comparison on `value`" to someone who did).

### Option B: the checker folds literal arithmetic (the ticket's option 2)

```erlang
comparison({e_op,_,Op,{e_var,_,V},R}) when ... -> case fold_int(R) of {ok,K} -> int_cmp(Op,V,K); error -> unknown end;
fold_int({e_int,_,K}) -> {ok,K};
fold_int({e_neg,_,E}) -> negate result;   fold_int({e_op,_,Op,A,B}) when Op =:= '+';'-';'*' -> fold both.
```

Accepts everything A does **plus** `0 - 5`, `2 + 3`, `5 - 10`, `1 + 2 * 3`, `-(-5)`, `-5 + 0`. Still refuses `value == K`
(finding 4, independent). Delta: 15 lines in `bs_check.erl`; must be extended for any new constant operator (`/`, `%`,
ticket 38's semantics, floats) or the two sites drift. Evidence: eunit equals baseline; boundary behaviour identical to A.

**Strongest counterargument.** `D() -> -3` remains refused as a `Delta` (run_literal_value.out): a refinement you can
write but whose negative values cannot be spelled as a literal return. The domain is nameable, not usable. Fixing that
needs A anyway, or a second fold in `type_of({e_neg,...})`. B also buys `2+3`, which has zero uses.

### Option C: narrow the grammar (the ticket's option 1: `refinement -> comparand` with `int_lit`)

```erlang
cmp_operand -> int_lit : {e_int, ...}.   %% int_lit already has '-' integer (yrl:470)
```

Refinements accept `-5`. **Not built or measured**; stated from the grammar alone. The guard `when n >= -5` stays
broken (guards go through `expr_low`), reintroducing precisely the refinement/guard split F2.5 forbids, and now with
a *known* disagreement. Rejected on finding 2, not on taste.

## Recommendation

**Option A.** Reasons: one clause, with a precedent two lines above it (float fold); it fixes refinement, guard and
boundary together because they share the node; it is the only option under which a bounded signed domain can be both
declared and *populated* by literal; B's extra reach (`2+3`) has no user in the corpus, and Erlang itself shows a
checker fold, if ever wanted, can be added later without undoing A. Ask David the gating question alone (literal vs
negation); the answer to "should `2+3` fold" can follow only if someone reports a need. Raise a separate ticket for
`value == K` (finding 4), and for the `opaque_refinement` text, which still recommends the thing it rejects for
`0 - 5` (diagnostic work, not a decision).

## What I could not measure

- **Elm**: no registry access, nothing run. Gleam/Elixir sources are not installed (binary/beams only), so those
  citations are behavioural probes, not file:line.
- The **5 baseline eunit failures** are identical across baseline/A/B in my copy but I did not diagnose them; the copy
  lacks `features/` and the gates, which may be why. They show only "no new failure", not "all green".
- Option C was **not built**; its refinement/guard split is inferred from the grammar, not run.
- Whether any non-test program depends on `-N` being typed `int` (the Option A counterargument) beyond the eunit suite:
  unverified; `compiler/examples` negatives are essentially absent.
- Compile timings are whole-process wall clock (VM boot dominates, ~375 ms); they cannot resolve a micro-cost in a fold.
- Root cause of the `value == 3` crash (finding 4) is not investigated.

## Re-run

```
bash /home/user/beam-sharp/artifacts/probes/57/run.sh            # ~1 min; every probe, outputs in place
bash /home/user/beam-sharp/artifacts/probes/57/run.sh --eunit    # + A/B/baseline eunit, ~12 min
```

Status: **OPEN - for human review.**
