# Decision brief — ticket 57: a refinement cannot say `-5`, though a pattern can

**Linear**: [ENG-239](https://linear.app/davewil/issue/ENG-239) · **Ticket file**: `wayfinder/issues/57-negative-literals-in-refinements.md`
**State**: OPEN. This brief resolves nothing; the decision is David's.
**Prepared**: 2026-10-16 by a scheduled run. Compiler measured: `master` + `bsc` built on OTP 28.0 (repo pins 28.5, see *Caveats*).
**Independent verification**: `artifacts/verification/57-verifier.md` (see *Verifier* at the end).

## The question, as a program

```csharp
type Delta = int where value >= -100 and value <= 100     // refused today

public atom Sign(int n)
Sign(n) when n < -1 -> :neg                               // compiles ...
Sign(n) when n >= -1 -> :nonneg                           // ... but the pair is refused: "Sign is not exhaustive"
```

The ticket asks **where the constant fold belongs, the grammar or the checker**. Measured, that is a false
dichotomy, and the second program above is why.

## Sub-decisions the ticket implies

1. Where does `-5` become a constant: in the parser, or in `bs_check:comparison/1`?
2. How far does folding go: `-5` only, or also `2 + 3` / `0 - 5`? (`value >= n` is never foldable.)
3. Does the fix reach **guards**? (It must, see finding 2; they share `alternatives/1`.)
4. What does `opaque_refinement` say afterwards? Its text still recommends "comparisons on `value`".

## Findings (all re-measured today, `artifacts/probes/57/matrix.sh`)

1. **The ticket still reproduces on HEAD**, but its mechanism section is stale. Since F51 unary minus is its own node,
   `expr_low -> '-' expr_low : negate(...)` (`compiler/src/bs_parser.yrl:591`), and `negate/2` already folds a
   negated **float literal** (`bs_parser.yrl:947`) while an int goes to `{e_neg, L, E}` (`:948`). The ticket describes the
   pre-F51 `0 - 5` desugaring. `comparison/1` (`bs_check.erl:5016-5027`) only recognises `{e_int,_,K}`, so `{e_neg,_,{e_int,_,5}}`
   reads as `unknown`. Baseline: `result_baseline.txt`.
2. **The same defect is in guards, which the ticket does not mention.**

   | program | baseline |
   |---|---|
   | `Sign(n) when n < 1 -> …` + `Sign(n) when n >= 1 -> …` | accepted (exhaustive) |
   | `Sign(n) when n < -1 -> …` + `Sign(n) when n >= -1 -> …` | **refused: not exhaustive** |
   | `Sign(n) when n < 1 + 1 -> …` + `Sign(n) when n >= 2 -> …` | **refused: not exhaustive** |

   An unreadable guard "credits no coverage" (`apply_guard/3`, `bs_check.erl:4983-4996`), so a signed guard silently loses
   its exhaustiveness proof. Rows `T57ExhGuard*` in `matrix.sh`.
3. `-5` is refused in **every** spelling (`(-5)`, `-(5)`, `- -5`, `-5 <= value`), and so are `2 + 3` and `0 - 5`.
   `value != 0` and `value <= 3 or value >= 10` are accepted (the ticket's control; reproduced).

## Survey: how neighbours treat a negative literal in a type/predicate position

- **Erlang** keeps it unfolded in the abstract format and folds at the *consumer*: `-type delta() :: -100..100.` is stored as
  `{op,{3,18},'-',{integer,{3,19},100}}` (printed from a compiled beam in this run; `artifacts/probes/57/p3_neighbours.ex`
  is the Elixir twin), and Dialyzer folds it with `erl_eval:partial_eval` at `otp_src_28.0/lib/dialyzer/src/erl_types.erl:4080-4091`.
  The compiler folds literal-argument calls at `lib/compiler/src/sys_core_fold.erl:895-912`. Erlang = **checker-side fold**.
- **Elixir 1.14** accepts `@type delta :: -100..100` (compiled and read back with `Code.Typespec`: `delta() :: -100..100`).
- **Gleam** has no refinements; `-x` is a `NegateInt` node (`compiler-core/src/parse.rs:826-836`), not a literal.
- **Elm** (source read; **not executed**, the package registry is unreachable from this sandbox): `-x` parses to `Src.Negate`
  (`compiler/src/Parse/Expression.hs:336-342`) and stays `Can.Negate` through canonicalisation (`Canonicalize/Expression.hs:93-94`).
- **B# itself** already folds a negated *float* literal in the parser (`bs_parser.yrl:947`), so the int case is the odd one out.

## Options (each prototyped as a patch and run through the same matrix)

### Option A — fold a negated int literal in the shared expression grammar (1 line)

```erlang
negate(_L, {e_int, IL, I})   -> {e_int, IL, -I};        % beside the float clause at bs_parser.yrl:947
```

Compiler delta: one clause. Patch `artifacts/patches/57-A-grammar-fold.diff`.
Measured (`result_A_grammar_fold.txt`): every `-5` spelling accepted in refinements **and** the signed guard pair becomes
exhaustive; `2 + 3`, `0 - 5`, `value >= n`, and the `n < 1 + 1` guard remain refused.
eunit: no failure beyond the baseline set (see *Caveats*).

*Strongest counterargument.* It folds only the literal. The next author to write `value <= 255 * 4` or `n < 1 + 1` meets
the same `opaque_refinement` whose text says "a comparison on `value`" is readable. The wall moves, it does not go.

### Option B — fold literal arithmetic in the checker (≈26 lines)

`comparison/1` folds `e_neg` and `+ - *` over integer literals before testing for a constant comparand. Patch
`artifacts/patches/57-B-checker-fold.diff`. Measured (`result_B_checker_fold.txt`): everything A accepts, **plus** `2 + 3`,
`0 - 5`, `-(5)` and the `n < 1 + 1` guard pair; `value >= n` still refused. eunit: same failure set as A.

*Strongest counterargument.* It is a second evaluator whose answers must agree with what the emitter computes
(`bs_emit.erl:1067` lowers `e_neg` to `{op,L,'-',…}`); a fold bug changes an exhaustiveness proof silently, and the ticket's
"where does it stop" question is answered only by fiat (`+ - *` today, then `div`? `rem`?). Erlang pays this price too
(`erl_eval:partial_eval`), but Erlang has a mature evaluator to borrow and B# would write its own.

### Option C — narrow the *refinement* grammar to an `int_lit` comparand (the ticket's first bullet)

Not prototyped, by design: finding 2 is the evidence against it. Guards share `alternatives/1` and the expression grammar;
a refinement-only literal rule would fix `type T = int where value >= -5` and leave
`Sign(n) when n < -1` refused. It also re-creates the refinement/guard split that `bs_check.erl` says refinement-as-`expr` exists
to prevent. This is an inference from the baseline guard rows, not an executed prototype.

## Recommendation

**Option A now; keep B as the named follow-up if an arithmetic bound ever appears in a real program.**
The ticket's dichotomy assumed the fold must sit at one of the two sites. A is a third place, the *shared* expression
grammar, which answers the ticket's own objection to the grammar option (that narrowing the grammar at one site splits
refinement from guard) because refinement and guard both get the fold. It costs one line, has an in-file precedent, closes every
measured `-N` failure including the guard exhaustiveness hole, and makes no commitment about how far folding goes.
Separately, reword `opaque_refinement` so it names what is readable ("a comparison of `value` with an integer literal").

## Caveats and honesty notes

- Built and run on **OTP 28.0**, the repo pins 28.5 (`.tool-versions`). No result here depends on a 28.5 feature that I could find.
- eunit (`rebar3 eunit`, 1448 tests): **my** runs showed baseline failing 5 and A/B failing 4; the verifier's runs show **5 in all three, an identical set**
  (`every_aoc_program_still_compiles`, `batch_runs_every_entry_in_one_vm…`, `a_path_is_utf8_on_the_wire`,
  `a_non_ascii_literal_is_advised_as_written`, `the_diagnostics_gate_passes`). The fifth is not flaky: it runs `bin/check-diagnostics.sh`, which needs a pre-built `bsc`
  (my A/B copies had one by then, the verifier's did not). So the correct statement is: **A and B add no failure beyond the baseline**; my "4 vs 5" was an artefact. The other four are environmental here.
- Elm was **not executed**. Cited from source only.
- Exemplar corpus effect (do any existing programs change meaning under A?) is covered by the eunit corpus tests; no
  separate corpus run was made.

## Verifier (independent re-run; full report `verification/57-verifier.md`)

**CIRCULAR: no.** Rebuilt A and B from the patches; outcomes identical to the stored files (which are reformatted, not raw script output). Expected outcomes are not in the script; it prints the compiler's own answer.
The verifier added 49 rows of its own, including: empty range (`>= -5 and <= -10` → "admits no values at all", correct), i64 extremes (accepted, BEAM bignums), operator folds (`-5 - 1`, `2 * -3`, `5 - -5`: A refuses, B accepts),
`- - -5`, `== -5`, `!= -5`, `-0`, and still-unsupported shapes refused by both (`value + 1 >= -5`, `-value >= 5`, `>= -5.0`, `10 / 2`, `7 % 4`).
**Exactness check** (guard coverage as an oracle): with `type T = int where value >= -5`, a guard `n >= -5` is exhaustive and `n >= -4` is not, so the computed bound is exact, not off by one; same for B's folded `2+3`, `0-5`, `2 * -3`.
Run-time results of negated expressions are identical under base, A and B (`-2147483648 - 1`, `n - -5`, `-(-5)`).
Caveats it raised: A changes the node for **every** negated int literal in all expression contexts (no outcome change seen); B also changes guard exhaustiveness analysis (wider than refinements); neither was tested on non-int negation.
