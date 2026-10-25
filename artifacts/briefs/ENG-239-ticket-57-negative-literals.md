# Ticket 57 (ENG-239): a refinement cannot say `-5`, though a pattern can

**State: open. Nothing here resolves it.** Written 2026-10-25 from probes in `artifacts/probes/57/`; the verifier's report is `artifacts/verification/ENG-239.md`.

## The question, asked alone

Where does the fold of `-5` belong: in the grammar, or in the checker? Everything else in the ticket follows from that.

## What the probes changed about the ticket

1. **The defect is wider than the ticket says. Guards have it too, and it is silent.** `refine/3` and `apply_guard/3` both call `alternatives/1` (`bs_check.erl:5159`), so a guard comparing against `-5` is "unread" and earns no coverage credit. Measured on the unpatched compiler (`p57_guard.sh`):

   ```csharp
   public atom S(int n)
   S(n) when n >= -5 -> :a
   S(n) when n < -5  -> :b      // error: S is not exhaustive. no clause matches: S(n) -> ...
   ```

   The same pair with `0` compiles, and so does the pattern form `S(>= -5)` / `S(< -5)`. The residual printed is the whole type, `S(n)`, which says nothing about the literal. A reader will delete a correct clause trying to satisfy it.

2. **The mechanism is slightly different from the ticket's.** Unary minus over an integer is `{e_neg, L, E}` since F51, not `0 - 5` (`bs_parser.yrl:591`, `:948`). A negated *float* literal is already folded to a literal in the grammar (`bs_parser.yrl:947`). Integers are the one literal F51 left unfolded.

3. **Everything in the ticket's table reproduces**, and so do the controls (`p57_fold.sh`): `int where value <= 3 or value >= 10`, `!= 0` and `>= 0` are accepted. The refusal covers `value >= 2 + 3`, `>= 0 - 5`, `>= (-5)`, `>= 2 * 3` and `-5 <= value` as well.

## Options

### A. Fold a negated integer literal in `negate/2`

```erlang
negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};
negate(_L, {e_int, IL, N})   -> {e_int, IL, -N};      % the one added clause
negate(L, E)                 -> {e_neg, L, E}.
```

This is neither of the ticket's two options. `refinement -> expr` stays a full expression, so refinement and guard still read one grammar. What changes is that `-5` is the literal everywhere, as `-1.5` already is.

Compiler delta: one clause, `compiler/src/bs_parser.yrl:947`. Patch `v57-A`.

Measured:

| program | unpatched | A |
|---|---|---|
| `int where value >= -5`, `>= -5 and <= 5`, `>= 1 or <= -1`, `!= -1`, `>= (-5)`, `-5 <= value` | refused | accepted |
| `S(n) when n >= -5` covering pair | "not exhaustive" | accepted |
| `value >= 2 + 3`, `0 - 5`, `2 * 3` | refused | **still refused** |
| `Delta Back(int n)` with `Back(n) -> -3`, `Delta = int where value >= -100 and value <= 100` | not declarable | **accepted and runs, prints -3** |
| `Neg MinusFive(int n)` with `MinusFive(n) -> -5`, `Neg = int where value <= -1` | not declarable | accepted |
| `Id(-6)` over `int where value >= -5 and value <= 5` | not declarable | crashes with `function_clause` (guard enforced) |
| dropping the negative clause over that type | not declarable | residual `Sign(>= -5 and <= -1)`, writable as printed |

`compiler/test`: 1494 passed, 4 failed, identical to the unpatched tree's 4 (see `artifacts/probes/README.md`). That oracle is weak for this change: no test in the suite has a negative literal in a refinement or guard, and `every_aoc_program_still_compiles_test` is one of the four baseline failures here (its run directory has no `aoc/`). So `p57_aoc.sh` compiles every AoC directory directly: all 3 compile under A (rc 0), the two containing `-1` emit different forms (`{integer,-1}` in place of a negation op), and Day01 still answers 6770.

**Strongest counterargument.** `2 + 3`, `0 - 5` and `2 * 3` stay refused, and the refusal text still recommends "comparisons on `value`". Anyone who writes a computed bound hits the original problem again. Nobody has written one yet, and a second occurrence would justify B2.

### B1. Fold `e_neg` over a literal inside the checker

A `const_int/1` helper used by the two literal-comparison clauses of `comparison/1` (`bs_check.erl:5165-5166`). About 10 lines. Patch `v57-B1`.

Measured: accepts the same declarations and guards as A. **It does not change the expression `-3`**, which stays typed `int`:

```csharp
type Delta = int where value >= -100 and value <= 100
public Delta Back(int n)
Back(n) -> -3          // error: Back returns a value its signature does not declare
                       //   not covered by the declared return type: int <= -101 | int >= 101
```

So the type can be written but a literal cannot inhabit it (also `MinusFive` above). `compiler/test` is unchanged, 1494 / 4.

**Strongest counterargument.** It is the Erlang model: `erl_parse` leaves `{op,1,'-',{integer,1,5}}` and `erl_lint:is_pattern_expr` folds it afterwards (`erl_lint.erl:2134-2147` calling `erl_eval:partial_eval`, `erl_eval.erl:2204`); Elixir quotes `-5` as `{:-, [line: 1], [5]}`. Two neighbours keep the grammar dumb and fold late, which keeps one meaning per node. The probe shows the price: the late fold does not reach typing unless the type checker folds too.

### B2. B1 plus `+`, `-`, `*` over literals

Same helper with three more clauses. About 15 lines. Patch `v57-B2`. Accepts every form in the table including `2 + 3`. `compiler/test` 1494 / 4.

**Strongest counterargument.** The ticket's own "where does it stop" question. `/`, `rem` and `**` are the next ones asked for, each with its own divide-by-zero and overflow story (ticket 38). And `0 - 5` as a *value* is still `int`, same as B1.

## Recommendation

**A.** It is one line, it follows F51's precedent exactly, and it is the only option under which `Delta` can both be written and be returned from a literal. Pair it with a gate for the guard case: today nothing tests a negative literal in a guard, which is how a gated, green F2 shipped with every scenario non-negative.

Not decided by the probes: whether to add B2 later. That needs a program that wants `2 + 3` in a bound; none of the 4 `where value` refinements in `compiler/examples` and `aoc/` computes one, and none has a negative bound either (grep: 4 refinements, 0 with a `-N`). So demand for any of this is argued from the ticket's `Delta` example, not from a program that failed.

## Neighbours (executed unless marked)

| language | what `-5` is | evidence |
|---|---|---|
| Erlang | unary-op node, folded by the linter and the BEAM compiler | `p57_neighbours.sh`; asm of `when N >= -5` shows `{integer,-5}` |
| Elixir | unary-op AST, accepted in guards and patterns | `Code.string_to_quoted!("x >= -5")` |
| Gleam | accepted in a `-1` pattern and in an `if x >= -5` guard | `gleam build` exit 0 |
| Elm | not executed: `package.elm-lang.org` is blocked, so no module compiles | |
