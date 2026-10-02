# Brief: ticket 57 / ENG-239, "A refinement cannot say `-5`, though a pattern can"

Not a resolution. Nothing under `wayfinder/` or `compiler/` was edited. Probes: `artifacts/probes/57/`
(`bash artifacts/probes/57/run.sh`, 23 PASS, rc 0, 74 s; captured in `run.out`).

## 1. Question and the gating sub-decision

**Gating question: where does a negative integer literal become one value, in the parser at the
point the node is built, or in the checker when it reads the node?** The ticket frames this as
"grammar vs checker" and fears that the grammar answer narrows `refinement` below `expr`. Measured,
that is not the choice on offer. The parser already has a smart constructor, `negate/2`
(`bs_parser.yrl:944-945`), that folds a negated *float* literal and builds `e_neg` for everything else.
Adding the int case there changes `expr`, which refinement, guard and call arguments all share, so
the refinement stays an `expr` and the "refinement and guard cannot disagree" intent
(`bs_parser.yrl:219-221`) holds by construction.

Follows from it: how far folding goes (`2 + 3`, `-(2 + 3)`, named constants) and whether the
formatter or LSP must round-trip `-(5)`. Neither is asked here.

## 2. Evidence

| claim | probe / citation | result | status |
|---|---|---|---|
| Ticket: `-5` reaches the checker as `{e_op,'-',{e_int,0},{e_int,5}}` | `ast.escript`; `bs_parser.yrl:585-589,944-945` | **Stale.** HEAD builds `{e_neg,2,{e_int,2,5}}` (F51 made unary minus its own node). The mechanism is unchanged: `comparison/1` has no clause for it, `bs_check.erl:4941-4948` | measured here |
| `value >= -5` refused with `opaque_refinement`; `<= 3 or >= 10` and `!= 0` accepted | `table.escript`, base, real `bs_check` | reproduces all five rows of the ticket | measured here (OTP 25 shim) |
| Same refusal for `-(5)`, `- -5`, `0 - 5`, `5 - 10`, `2 + 3`, `3 * 4`, `-(2 + 3)`, `!= -1`, `-5 <= value` | same | all `opaque_refinement` | measured here |
| Pattern `<= -1` is a literal | `ast.escript`: `{p_rel,3,'<=',-1}` and `{p_int,3,-1}`; `bs_parser.yrl:395,461-470` | yes | measured here |
| **NEW: guards are hit too.** `Sign(n) when n <= -1 -> ..; Sign(n) when n >= 0 -> ..` over `int` | `table.escript`, base | `{diag,[inexhaustive]}`; the same program spelled `n < 0` is accepted. An unreadable guard credits no coverage, `bs_check.erl:4908-4913` | measured here |
| **NEW: the literal `-1` has type `int`, not `-1..-1`.** `Take(-1)` over `int where value <= 5` | `sem.escript`, base | `arg_not_accepted`; `return -1` as that type is `return_not_declared`. `type_of({e_neg,..})` returns `bs_types:int()`, `bs_check.erl:2867-2878` | measured here |
| Grammar fold (1 line in `negate/2`) fixes refinement, guard and literal typing | `grammar-fold.patch` + `table.escript` + `sem.escript` | `-100..100` accepted; `Take(-100)` ok, `Take(-101)` refused; guards exhaustive; `Take(-1)` over `<= 5` ok | measured here |
| Checker fold in `comparison/1` alone fixes refinement and guard but **not** the literal | `checker-fold-neg.patch`, variant `neg` | `type Delta = int where value >= -100 and value <= 100` accepted, then `Take(-100)` is `arg_not_accepted` | measured here |
| Checker fold needs a second site (`type_of`) to be usable | `checker-fold-negt.patch`, variant `negt` | `Take(-100)` accepted | measured here |
| Neither fix changes the repo's own tests | `suite.sh`: 12 test modules, 289 tests, eunit on OTP 25 | 41 fail at base (CLI/escript, OTP-28 and float tests); **the failing set is identical** across base/grammar/neg/negt/arith | measured here, weak (see 7) |
| `{integer,L,-5}` (what `bs_emit` would get) compiles to the same beam as `{op,L,'-',{integer,L,5}}` | `erl/neglit.escript` | both 532 bytes, byte-identical; `bs_emit.erl:1049` handles `e_neg` as `{op,L,'-',..}` | measured here |
| Ticket 57: "F2's five scenarios are all non-negative" | read F2, not re-run | not contradicted | cited |
| Ticket 20 §5: refinements are "one BEAM guard" | `20-untheorised-term-shapes.md:249-251,460` | the tier line is guard-decidability, and Erlang's guard folds `-5` | cited |

## 3. Neighbour survey

**Erlang (OTP 25).** `erl_parse` does **not** fold. It emits `{op,1,'-',{integer,1,5}}` in a guard, a
pattern and a type range alike (`erl/parse.escript`). Folding happens afterwards: `+to_core` shows
`N >= -5`, `N >= 2 + 3`, `-(5)` and `0 - 5` as the constants `-5`, `5`, `-5`, `-5`, and a pattern as
`<-1>`. Type ranges accept arithmetic and macros: `(1+1)..(2*3)`, `-(5)..5`, `(0-5)..5`, `?LO..5`
all compile; only a variable or an empty range is `bad range type`. So Erlang folds late and folds
arithmetic. Neither `erl_parse.yrl` nor the lint source is installed here, so I name no function.

**Elixir 1.14.** `-5` is `{:-, [line: 1], [5]}` in an expression, an argument and a typespec; the
parser does not fold (`ex/q.exs`). The typespec translator folds **unary minus on a literal only**:
`-5..5`, `-(5)..5`, `-5..-1` accepted; `(0 - 5)..5`, `(1 + 1)..(2 * 3)` and `-(2 + 3)..5` are
`type -/2 undefined` or `type +/2 undefined`. That is exactly the stop point Option A produces.
(Stack trace names `lib/kernel/typespec.ex:634,936`; source not installed, not read.)

**Gleam 1.12.** `-5` is a literal in a `const`, a pattern, a guard and an expression
(`gleam/run.sh`). Folding stops at the literal: `-{1}` is a syntax error in a pattern, a guard and a
`const`; `2 + 3` is a syntax error in a `const` and a pattern but legal in a guard. The emitted Erlang
keeps `-5` and `2 + 3` as written. Gleam has no refinement types.

**Elm 0.19.2.** Not run. The compiler could not fetch `elm/core`: the package registry is
unreachable from this sandbox (`elm make` printed its "slow internet" message, no output produced).
No Elm claim is made.

## 4. Measurements

- Node size (`erts_debug:flat_size`, words): literal `{e_int,L,-5}` **4**; `{e_neg,L,{e_int,L,5}}`
  **8**; the old `0 - 5` shape `{e_op,L,'-',{e_int,L,0},{e_int,L,5}}` **14**. Erlang's own
  `{op,1,'-',{integer,1,5}}` is 9 against `{integer,1,-5}` at 4. Elixir's unary node is 11 words
  against a literal at 0 (a small integer is immediate).
- Patch size: grammar fold **+1 line**; checker fold `neg` **~14 lines in one function**; `negt` adds
  **+1 line** in a second function (`checker-fold-neg.patch`, `checker-fold-negt.patch`);
  `arith` adds 6 more lines to `fold/1` (`checker-fold-arith.patch`).
- What stays refused under each (`table.escript`): grammar and `neg` stop at `2 + 3`, `0 - 5`,
  `5 - 10`, `-5 * 2`, `-(2 + 3)`; `arith` accepts all of them.

## 5. Options

### Option A: the parser folds `-<integer literal>` where it builds the node

```csharp
type Delta = int where value >= -100 and value <= 100     // accepted
type Gap   = int where value >= -10 and value <= -1
                    or value >= 1  and value <= 10        // the residual of Delta minus 0, now writable

public atom Take(Delta d)
Take(d) -> :ok
public atom Go() -> Take(-100)                            // accepted; Take(-101) is arg_not_accepted

public atom Sign(int n)
Sign(n) when n <= -1 -> :neg                              // earns coverage credit
Sign(n) when n >= 0  -> :pos
type Bad = int where value >= 2 + 3                       // still refused: opaque_refinement
```

Compiles to what `0..255`-style refinements already do (F2, F37 for the exported boundary, cited, not
re-run); the emitted guard literal is `{integer,L,-100}`, which `compile:forms` turns into the same
beam as `{op,L,'-',{integer,L,5}}` (`erl/neglit.escript`).

Compiler delta: one clause in `negate/2`, `bs_parser.yrl:944`:
`negate(_L, {e_int, IL, N}) -> {e_int, IL, -N};`. No checker, emitter or diagnostic change. A test row
for each of F2's scenarios with a negative bound, and one for guard coverage.

Strongest counterargument: the AST no longer records that the author wrote `-(5)` or `- -5`, since both
fold; the diagnostic line comes from the literal rather than the minus, and a formatter or LSP that wants
to reprint source from the AST must reprint `-5` (it does for floats already, `bs_parser.yrl:585-588`).
It also does not make `2 + 3` readable; that needs Option B's `fold`.

### Option B: the checker folds a literal-only integer expression before `comparison/1`

```csharp
type Delta = int where value >= -100 and value <= 100     // accepted
public atom Go() -> Take(-100)                            // REFUSED unless type_of also folds
type Ok = int where value >= 2 + 3                        // accepted only if the fold includes `+`
```

Compiler delta: a `fold/1` (`neg` variant: `e_neg` of a literal; `arith`: also `+ - *`) applied inside
`comparison/1`, `bs_check.erl:4941`; **and** a clause in `type_of`, `bs_check.erl:2867`, so `-1` is
typed `-1..-1`; both patches are in the probe dir.

Measured: with the `comparison/1` fold alone, `Delta` is declarable and then **no call can pass its own
lower bound**: `Take(-100)` is `arg_not_accepted` (variant `neg`). Folding in `type_of` as well cures it
(variant `negt`). Any later reader of an integer (an emitter fast path, the F37 boundary check, a range
analysis) must also call the fold or it sees `e_neg`.

Strongest counterargument for B: it is the only route to `2 + 3`, `5 - 10` or a future named constant,
and it keeps source fidelity in the AST. It costs a second site today and a rule for every new reader.

## 6. Recommendation

**Option A.** One line removes the defect at every site that consumes a negative literal (the refinement,
the guard's coverage credit, and the literal's own type) and its stop point (literal only) matches
Elixir's typespec folder and Gleam's literal grammar. It reuses a mechanism the parser already applies
to floats. Option B is correct only after a second patch and leaves a standing rule that every reader
re-fold.

Would change my mind: a decision (or a ticket) that wants arithmetic or named constants in refinements
(`value >= Min + 1`), since that needs a checker fold regardless and A becomes the first half of it; or a
formatter/LSP requirement to print `-(5)` back unchanged.

Two things to raise whichever option is taken: (a) the ticket's AST description is stale (section 2,
row 1) and should be corrected on resolution; (b) the guard coverage and literal typing defects belong
in the same ticket's `## Decisions entry` and tests, since they are the same cause and Option A fixes
them at once while the ticket as written names only refinements.

## 7. Not verified here / limits

- **bsc was not run.** Everything above ran the repo's real `bs_lexer`, `bs_parser`, `bs_lower` and
  `bs_check` modules, built on **OTP 25** (the repo pins 28.5) with two shims in `build.sh`:
  `TokenLoc` renamed `TokenLine`, and a hand-written `adjust_col/3` (OTP 26 leex generates it; it is
  used only inside `$"..{hole}.."`, which no probe uses). Tokens carry integer lines, not `{L,C}`.
  Diagnostics are read as tags (`inexhaustive`, `arg_not_accepted`), not rendered text.
- The eunit slice is **weak evidence**: 41 of 289 tests fail on OTP 25 at base (they shell out to the
  `bsc` escript or need OTP 28), including 5 of `intervals_tests` and 4 of `negation_tests`. The claim
  is only that the failing set is identical across variants, so the patches add no failure in what runs.
  `./bin/verify.sh` and the gates were not run. CLAUDE.md requires them twice from a clean checkout.
- Emission of a declared refinement (F37's boundary guard) was not re-run; Option A's emission claim
  rests on `neglit.escript` and on F2/F37 as cited.
- Elm: not run (registry unreachable). Erlang and Elixir sources are not installed; no source line from
  them is cited, only probe output.
- Why F51 folded the float literal but not the int is not recorded in the comment at `bs_parser.yrl:585`
  beyond "so `Sign(-1.5)` is a head"; I found no reason the int case was left out.
- No probe of the REPL/LSP/formatter round-trip for `-(5)`; that counterargument to A is reasoned, not measured.
