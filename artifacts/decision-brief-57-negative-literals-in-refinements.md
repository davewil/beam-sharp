# Decision brief — ticket 57 (ENG-239): a refinement cannot say `-5`, though a pattern can

Status of the ticket: **left open.** This brief recommends; it resolves nothing.
Evidence: `artifacts/probes/results/57-*.txt`, patches `v57a`, `v57b`. Environment and limits: `artifacts/README.md`.

## The one question David decides

Should `-5` mean the same thing in a refinement, a guard and a pattern, and where is that made true?
This program is refused today and accepted under either fix:

```csharp
type Delta = int where value >= -100 and value <= 100     // refused today: opaque_refinement

public atom Sign(int n)
Sign(n) when n >= -5 -> :near                             // refused today as a guard, too
Sign(n) when n < -5  -> :far
```

## Sub-decisions the ticket implies

1. Where the fold lives: grammar, checker, or the place the parser already folds floats.
2. How far folding goes: only `-<int>`, or literal arithmetic (`2 + 3`, `0 - 5`).
3. Whether the fix has to reach guards. The ticket frames this as a refinement defect; it is not only that.

## What was measured

- **The ticket's repro reproduces** (`57-refinement-probe.txt`, baseline): `value >= -5`, `value > -1`, `value != -1`, and every
  disjunction with a negative bound are refused; `value <= 3 or value >= 10` and `value != 0` are accepted.
- **The ticket's AST is out of date.** It says unary minus desugars to `0 - 5`. In the current parser it does not:
  `negate/2` (`compiler/src/bs_parser.yrl:947-948`) already folds a negated **float** literal and wraps everything else
  as `{e_neg, L, E}`. So the integer case is one missing clause beside an existing one. The ticket's two-way fork
  (grammar vs checker) has a third answer that is neither.
- **Guards are broken by the same cause, which the ticket does not say.** `alternatives/1` (`bs_check.erl:4998-5014`) is shared
  by refinements and guards. Baseline on the two-clause `Sign` above reports `Sign is not exhaustive: no clause matches Sign(n) -> ...`
  (the whole type, `57-refinement-probe.txt`); the guard is simply unread. With either fix it compiles, and with a real hole
  (`n >= -5` and `n < -6`) the residual is the pasteable `Sign(-6)` (`57-runtime-and-residual.txt`). That is the "residual
  doctrine" the ticket worries about, working.
- **Run time is right once readable.** With `type Delta = int where value >= -100 and value <= 100`, calling with 100 and -100 returns
  them and -101 crashes `function_clause`: the boundary guard emitted from the refinement enforces the negative bound.
- **Regression check:** the repo's eunit suite's failing set is identical to baseline for both patches. Caveat: baseline fails 583 of 1448 here,
  because OTP 25 lacks `maps:iterator/2`. `bin/verify.sh` and the shell gates were not run.

## Neighbours (executed, `57-erlang-elixir-ast.txt`)

- **Erlang** (`erl_parse` on OTP 25): `N >= -5` parses to `{op,1,'-',{integer,1,5}}`; after `compile:forms(..., [to_core])` the
  guard operand is the literal `-5`. So Erlang keeps minus as an operator in the parser and folds it later.
- **Elixir 1.14** (`Code.string_to_quoted!`): `{:-, [line: 1], [5]}`, the same shape.
- Gleam and Elm are **not installed** here; I make no claim about them. Installed OTP/Elixir ship `ebin` only, so there is no source file:line to cite for them; the citations above are executed output.

## Options

### A. Fold a negated integer literal in the parser, beside the float fold (`patches/v57a`, 1 line)
```erlang
negate(_L, {e_int, IL, I})   -> {e_int, IL, -I};
```
- Evidence: all `-5` forms accepted incl. `(-5)`; guard form compiles; residual `Sign(-6)`; runtime bound enforced; eunit failing set unchanged.
  Still refused: `value >= 0 - 5`, `2 + 3`, `2 * 3`.
- Cost: one clause. Grammar unchanged (yecc conflicts stay at 6 shift/reduce), so a refinement stays an `expr` and cannot drift from a guard.
- **Strongest counterargument (verifier-confirmed):** it changes the AST and the *type* of every negative literal, not just in refinements. `type_of(e_neg)` is `int` (`bs_check.erl:2889`) while `type_of(e_int)` is the singleton (`:2882`), so with A `-5` is typed as the literal -5. Verifier probe: `Neg Mk(int n) -> -5` with `Neg = int where value <= -1` is accepted and returns -5 under A, and refused under B ("not covered ... int >= 0"). That is arguably better, but it is a behaviour change outside refinements. Emitted Erlang across the corpus was not diffed.

### B. Fold literal arithmetic in the checker (`patches/v57b`, 18 added lines in `comparison/1`)
- Evidence: accepts every row in the probe, including `0 - 5`, `2 + 3`, `2 * 3`; same regression result.
- **Strongest counterargument:** it invents a constant evaluator the language does not otherwise have, and the stopping point (`/`, `rem`, `bsl`) has no
  natural edge. `value >= 2 * 3` has no demonstrated need. A second evaluator beside the emitter's is a place for the checker and the guard emitted at run time to disagree.

### C. Narrow the refinement grammar to `int_lit` (the ticket's first option; **not prototyped**)
- Reasoned from the baseline guard probe: it would fix refinements and leave the guard form above broken, since guards are ordinary `expr`.
  It also removes the refinement-is-an-expr property that `bs_parser.yrl:219-221` says exists so the two cannot disagree.
- Counterargument: it is what patterns already do, and is the smallest change. Not measured further.

## Recommendation

**A.** It is the smallest change that makes all three sites agree, mirrors the float precedent in the same function, and fixes guards. Revisit B only
when a real program wants `2 + 3` in a refinement (the repo's own second-occurrence rule). Before resolving, run the full `bin/verify.sh` on OTP 28 and diff emitted Erlang for the corpus, neither of which I could do.
