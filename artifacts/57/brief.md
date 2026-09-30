# Decision brief: ticket 57, a refinement cannot say `-5` (ENG-239)

Status: decision left open for David. Nothing in the repo outside `artifacts/57/` was touched.
All probe paths are under `artifacts/57/probes/`. Compiler measured: the current tree (`0dddf8b`),
built without rebar3 (see Reproduce), on OTP 25 (the repo pins 28.5).

## Question

`type Delta = int where value >= -100 and value <= 100` is refused, while the pattern
`Direction(<= -1)` is accepted. The ticket asks where the fold belongs, grammar or checker. The
probes say the question is one level too low. The defect is not confined to refinements, and the
choice between "grammar" and "checker" is really a choice about what `-5` *is*.

## Two findings that change the ticket's premise

1. **REFUTED (mechanism).** The ticket says `-5` reaches the checker as `0 - 5`,
   `{e_op,'-',{e_int,0},{e_int,5}}`. Since F51 it reaches it as `{e_neg,L,{e_int,L,5}}`
   (`bs_parser.yrl:589`, `:944-945`; probe 57b). The conclusion (opaque refinement) still holds.
2. **The same defect is in guards, and there it is silent.** `refine/3` and `apply_guard/3` both
   call `alternatives/1` (`bs_check.erl:1892`, `:4910`). A guard `when n >= -5` is unreadable, so
   it credits no coverage. Consequence, measured (57e): delete a clause from LANGUAGE.md section
   3's own `Classify`, and the compiler prints `Classify((:ok, n)) when n <= -1 -> ...`. Paste
   exactly that and the compiler prints the **same error again**. The README's "paste the residual"
   bet has a fixed point for every negative bound in a nested position. The ticket's "nothing is
   blocked today" holds for ticket 38 but not for this.

## Sub-decisions

**Q1 (gating, asked first): is `-5` a literal everywhere, or an operator that each consumer must
see through?** Every other question follows from it.

- If literal: fold once where the node is built (`negate/2`, where floats already fold). Both
  "where does the fold stop" (Q2) and "which sites need it" disappear, because `2 + 3` was never a
  literal.
- If operator: the checker folds, at every site that reads a literal. Q2 then needs an answer:
  does the fold stop at `-5`, or reach `2 + 3` and `5 - 10`?

Q2 is asked only after Q1 = operator. Q3, the `opaque_refinement` wording, follows whatever is chosen.

## Evidence

| claim | probe | result | status |
|---|---|---|---|
| Every refinement with a negative literal is refused; `<= 3 or >= 10` and `!= 0` accepted | 57a | rows R1-R5 match the ticket exactly | VERIFIED |
| `-5` parses to `0 - 5` | 57b | parses to `e_neg`; `0 - 5` is a different tree | REFUTED (mechanism only) |
| The diagnostic recommends the form it rejects | 57a | text says "comparisons on `value`", refuses `value >= -5` | VERIFIED |
| Guards with a negative literal are also unreadable | 57c G1, G2 | `Sign(n) when n >= -5` / `n <= -6` reported non-exhaustive, residual is whole `Sign(n)` | VERIFIED (new) |
| The printed residual, pasted back, closes the hole | 57e P2 | same error reprinted | REFUTED for negative bounds (new) |
| `Half(-5)` is accepted where `Half(5)` is, for `type Nz = int where value != 0` | 57c L0/L1 | L1 refused: "argument is not covered ... `0`". `-5` is typed `int`, not `-5..-5` | REFUTED (new) |
| The residual `-10..-1` is "printed and cannot be accepted by the surface" | 57f E (after a fix), 57c R0 | the compiler prints `F(<= -1)` (57c R0) and, once `Delta` is writable (variant A2, 57f E), `Direction(>= -100 and <= -1)`; both are legal **patterns**. Only the *refinement* surface lacks the spelling | PARTLY REFUTED |
| The same problem affects floats | 57a F1/F2 | `float where value >= 1.0` is refused too, with no negative in sight (F51: float refinements are opaque) | VERIFIED, separate defect |
| `erlc` output is unchanged if `-5` becomes one literal | 57d | `beam_disasm` of `Lit` identical in both: `{move,{integer,-5},{x,0}}`; results identical | VERIFIED |
| A negative `e_int` is already a shape the compiler builds | `bs_emit.erl:455`, `:661` (`cmp/4`, `rel_expr/2` put `{e_int,L,K}` with K negative for `<= -1`) | source read | VERIFIED |
| Nothing in the suite regresses | `run_suite.sh` | 1303 tests; 54 failures on baseline, A2, B1, B2, B3 (identical failing set). **A1 gives 55** (verifier): `intervals_tests:an_unreadable_refinement_predicate_is_an_error_test` (`intervals_test.erl:46-53`) fails because A1 turns `type Email = int where WellFormed(value)` into a syntax error and loses the `opaque_refinement` diagnostic. Causes of the 54 also include 5 `json:decode/1`, `-0.0` vs `0.0` matching (OTP 27 semantics) and an io_lib `~k` format, so on OTP 25 the suite cannot see regressions near the negation code | VERIFIED for A2/B1/B2/B3; A1 = 55 (weak: no test has a negative refinement) |

## Survey

Erlang and Elixir source is **not installed** (ebin only; no `.yrl`/`.erl`/`.ex`), so there is no
file:line to cite and none is cited from memory. Behaviour only (57g, 57h):

- **Erlang OTP 25**: `-5` stays `{op,L,'-',{integer,L,5}}` in a pattern, a guard comparand and a
  type (`-type delta() :: -100..100` gives `{type,3,range,[{op,3,'-',{integer,3,100}},...]}`).
  `erl_lint` accepts all of it. Erlang keeps the node and folds later.
- **Elixir 1.14**: `Code.string_to_quoted!("-5")` is `{:-, _, [5]}`; `-5..5` is
  `{:.., _, [{:-, _, [5]}, 5]}`. The same node in every position; a guard `x >= -5` compiles.
- **Gleam 1.12**: `-5 ->` pattern, `n if n >= -5` guard, `-5` and `-5 + 2` expressions all compile.
  A guard `n if n >= 2 + 3` also compiled, so its guard grammar takes constant arithmetic.
  Source not available, so why is unknown.
- **Elm 0.19.1**: NOT PROBED. The package cache is absent (`elm/core`, `elm/json` missing); Elm has
  no refinement types anyway.

What this shows: the neighbours all keep `-5` as an operator node and fold it late. None of them
has a checker that must *prove* something from the comparand, so they do not show the cost of
folding at N sites. B#'s own precedent is nearer: F51 already folds a negated float literal in the
same function (`bs_parser.yrl:942-944`, "`-0.0` is the platform's negative zero").

## Measurements

| variant | 57a: negative-literal rows that become accepted | guards (G1/G2) | `Half(-5)` | paste loop (57e P2) | `Clamp` into `Delta` (57f) | suite vs base |
|---|---|---|---|---|---|---|
| baseline | none | refused | refused, message blames `0` | red | n/a (`Delta` unwritable) | 54 env failures |
| A2 parser fold | R1-R3, V3-V7 | accepted | **accepted** | **green** | **compiles** | same 54 |
| B1 checker, `comparison/1` only | R1-R3, V3, V5-V7 | accepted | refused | green | **refused** (below) | same 54 |
| B3 checker, `comparison/1` + `type_of/3` | as B1 | accepted | **accepted** | green | compiles | same 54 |
| B2 checker, general int fold | adds V1, V2, V4, V8 | accepted | refused | green | refused | same 54 |
| A1 grammar, refinement-only | R1-R3, V5-V7; V1-V4, V8 become **syntax errors** | **refused** | refused | **red** | **refused** (two errors) | **55** (one extra: `opaque_refinement` test) |

Patch sizes: A2 one added line; B1 +7/-2; B3 B1 plus one clause; B2 about 25 lines; A1 about 14
grammar rules. `bs_parser.yrl` reports the same "6 shift/reduce" before and after A1.

The B1 failure (57f), from a correct program:

```
Clamp(n) when n > 100 -> 100
Clamp(n) when n < -100 -> -100
error: Clamp returns a value its signature does not declare
  not covered by the declared return type:  int <= -101 | int >= 101
```

The checker-only fix reads the refinement and still types the literal `-100` as `int`.

## Options

Each is shown on one program. Write this once, it is the whole argument:

```csharp
module Direction
type Delta = int where value >= -100 and value <= 100
type Step = :down | :none | :up

public Step Direction(Delta d)
Direction(<= -1) -> :down
Direction(0)     -> :none
Direction(>= 1)  -> :up

public Delta Clamp(int n)
Clamp(n) when n > 100  -> 100
Clamp(n) when n < -100 -> -100      // a guard AND a literal in return position
Clamp(n) -> n
```

### Option A: `-5` is a literal; the parser builds it as one (A2)

`bs_parser.yrl:944`, beside the float line that already exists:

```erlang
negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};
negate(_L, {e_int,   IL, N}) -> {e_int,   IL, -N};     % the added line
negate(L, E)                 -> {e_neg, L, E}.
```

- **Compiles to:** the abstract form `{integer,L,-5}` instead of `{op,L,'-',{integer,L,5}}`; the
  BEAM is identical (57d). `Direction` and `Clamp` both compile and run; `Direction(-100)` is
  `:down`, `Direction(101)` is `crashed: error:function_clause` (57f).
- **Compiler delta:** one clause. No new symbol-table entry, pass or diagnostic. Test first, per
  CLAUDE.md: a scenario on F2 (every F2 scenario is non-negative, which is why the gap survived a
  green feature) plus `Half(-5)`, the `Clamp` guard, and the pasted residual.
- **Measured:** the only variant that passes every row of the table above and leaves no site
  unfixed. Side effect, correct by ticket 38 §2: `10 / -0` becomes bsc's "divisor is always zero"
  error (57c L2), where today it is only an erlc warning.
- **Strongest counterargument:** it is the parser doing constant evaluation for a second shape, and
  it is silent about `2 + 3`. `value >= 5 - 10` and `value >= 0 - 5` stay refused, which someone
  who has just learned `-5` works will try. Also `-(5)` and `- -5` now fold, because parentheses
  leave no node. The source form is no longer recoverable from the AST, which matters only if the
  formatter or LSP later round-trip from it (they would need the CST anyway). The refusal message
  could say "a constant, not an expression" to cover this.

### Option B: `-5` is an operator; the checker folds it (B3)

One helper `lit/1` called from `comparison/1` (`bs_check.erl:4941-4942`) and a `type_of/3` clause
for `{e_neg,_,{e_int,_,N}}` (`:2867`). Extending the helper to `+ - *` is B2.

- **Compiles to:** the same BEAM and abstract forms as today. `Direction`/`Clamp` compile (57f).
- **Compiler delta:** two sites now, plus an obligation on every future reader of a literal.
  `bs_emit.kind_expr` (`:698-700`) reads the same comparison shape and sits outside the fix.
- **Measured:** equals A on every probe except V4 (`- -5`), which A2 accepts and B3 refuses (see the table). B1 alone (the ticket's option) does **not**:
  `Clamp` is refused (above) and `Half(-5)` still fails. B2 adds `2 + 3` and `5 - 10` and keeps
  the same two-site shape.
- **Strongest counterargument against B:** it is correct only if each consumer of a literal
  remembers to fold. Two sites were found here by probing, not by reading; the third will be
  found the same way. In favour of B: it leaves the parser faithful to the source, as Erlang and
  Elixir do (57g), and it is where the ticket's stated design intent points ("one grammar, one
  meaning").

### Option C: restrict the refinement grammar (A1, the ticket's first branch)

`refinement -> lident ref_op int_lit | ...` joined by `and`/`or`, mirroring `int_lit`.

- **Compiles to:** `Delta` and `Direction` compile. `Clamp` does **not** (57f A1): the guard is
  still unread and the literal `-100` is still typed `int`.
- **Compiler delta:** about 14 grammar rules; the checker is untouched.
- **Measured:** fixes only the refinement row, and `Clamp` stays refused. Guards stay refused (G1), the paste loop stays red
  (57e), `Half(-5)` still fails (57c). `value >= 2 + 3` becomes `syntax error before: '+'` where it
  was a readable "not a predicate" refusal (57a A1).
- **Strongest counterargument against C:** it splits the refinement from the guard, which
  `bs_parser.yrl:221` and F2.5 say must not happen, and it leaves the larger defect in place. In
  favour: it is the literal reading of "what patterns already do", and it needs no checker change.

## Recommendation

**Option A**, and ask David Q1 as one question: *should `-5` be the integer -5 everywhere?*

1. It is the only option that fixes all four surfaces measured: refinement, guard, literal typing,
   and the residual paste loop, with one added line.
2. It follows the F51 precedent in the same function, so the "fold at construction" choice has
   already been made once for floats and is consistent with it.
3. B is acceptable if David wants a faithful parser, but only as **B3 with both sites**, never the
   ticket's checker-only change.
4. C should be declined. It fixes the smallest surface and splits the refinement from the guard.

Q2 lapses under A. `2 + 3` stays refused and the message is the only open edit.

## Open risks

- **A2 has a side effect not priced above (verifier).** It also changes `to_match` (`bs_parser.yrl:882`) and `to_param` (`:930`): `-1 = x` and a lambda parameter `(-5)` now parse as int patterns, where `-1 = x` was refused with "must be a literal pattern". Decide whether that is wanted.
- **Probe notes.** `probe()` in `common.sh:9-11` counts any output as "refused" (every refused row does show an `error:` line). 57e had no non-negative control; the verifier supplied one and the loop is specific to negative bounds in nested positions. The committed `.out` files contain a `$W` placeholder that no script writes.

- **Suite coverage is weak.** The 1303-test suite has no negative-bound scenario, so "no
  regressions" says only that nothing that exists moved. The gates (`check-language.sh`,
  `check-examples.sh`, `check-residual-pasteable.sh`) were **not run**; they need the pinned
  toolchain and `rebar3`.
- **OTP 25, not 28.5.** `leex` here is `maint-26`'s (the installed one lacks `TokenLoc`); 54 tests
  fail identically on baseline and every variant for want of `json` and `maps:iterator/2`. A
  clean pair on OTP 28.5 is owed before any of this lands.
- **Wording.** `opaque_refinement`'s message (`bs_diag.erl:1954`) says "comparisons on `value`",
  which stays true but incomplete under A; I did not draft new text.
- **Separate defects surfaced, not decided here:** float refinements are refused for any bound
  (57a F1/F2, named in F51); a relational pattern nested in a tuple is refused (57e P3,
  `relational_pattern_nested`), so the residual printed as a guard (`when n <= -1`) cannot be
  written as a pattern there either. Both need their own ticket, not this one.
- **Probe honesty.** 57c case R1 was written `expected accepted` by my mistake (57a V1 had already
  shown `0 - 1` refused); its `!!` line is kept and annotated in the script. The Elm half of 57h
  could not run. The 57a expectations were written from the ticket's table, so they test the
  ticket, not the variants; the variant tables (`57a_table_*.out`) carry the new results.

## Reproduce

From a clean shell (needs `erl`, `erlc`, `python3`, `curl`, `elixir`, `/tmp/tools/gleam`):

```
cd /home/user/beam-sharp/artifacts/57/probes
export LANG=C.UTF-8 LC_ALL=C.UTF-8
./build_bsc.sh                    # baseline compiler -> /tmp/bsc57 (fetches maint-26 leex.erl once)
./run_all.sh                      # builds the five variants from variant_*.patch, then runs every probe
```

Individually (`B` selects the compiler build; default baseline):

```
./57a_refinement_table.sh         # also: B=/tmp/bsc57-A2 ./57a_refinement_table.sh  (A1 A2 B1 B2 B3)
./57b_ast_shape.sh                # what -5 parses to
./57c_guards_and_literals.sh      # guards, Half(-5), 10 / -0, residual
./57d_emit_and_runtime.sh         # B=/tmp/bsc57 then B=/tmp/bsc57-A2: abstract form, beam_disasm, runtime
./57e_paste_the_residual.sh       # LANGUAGE.md section 3, pasted residual
./57f_signed_domain.sh            # Delta, Direction, Clamp
./57g_neighbours_erlang_elixir.sh
./57h_neighbours_gleam_elm.sh
./run_suite.sh base; ./run_suite.sh A2     # ~4 min each; compare the FAIL lists
```

Captured outputs sit beside each script (`*.out`, and `57a_table_*.out`, `57c_*.out`,
`57e_*.out`, `57f_*.out`, `suite_*.out` per variant).
