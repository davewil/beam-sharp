# Decision brief: ticket 57, a refinement cannot say `-5`

Ticket: `wayfinder/issues/57-negative-literals-in-refinements.md`, Linear [ENG-239](https://linear.app/davewil/issue/ENG-239). Status in the file: open. Brief prepared 2026-10-07. Nothing here resolves the ticket; no repo file outside `artifacts/` was touched. Every compiler "variant" below is a patch applied to a **copy** of `compiler/src` (`artifacts/probes/57/patches/`).

## What the ticket asks

`type T = int where value >= -5` is refused as `opaque_refinement`, while the pattern `Sign(<= -1)` reads the same literal. The ticket asks one question: does the fold belong in the grammar (narrow the refinement to a literal comparand, as `int_lit` does for patterns) or in the checker (fold literal arithmetic before asking if the comparand is constant)? It notes a refinement is deliberately an `expr` so a refinement and a guard cannot disagree.

## Re-run against the current compiler: what is stale

Probe `57a` re-runs the ticket's table. **The table still holds** (all five rows, plus the pattern control; `57a_repro_table.out`, 18 ok, fails=0). **The stated mechanism is stale**, and the defect is wider than the ticket says:

1. Since F51 (2026-09-16) the parser no longer emits `0 - 5`. `bs_parser.yrl:589` is `expr_low -> '-' expr_low : negate(...)` and produces `{e_neg, L, E}`. `negate/2` (`bs_parser.yrl:944`) **already folds a negated float literal** (`negate(_L, {e_float, FL, F}) -> {e_float, FL, -F}`) and not an int literal. The ticket's `{e_op,'-',{e_int,0},...}` no longer exists; the symptom is unchanged.
2. **The same defect is in guards.** `alternatives/1`/`comparison/1` (`bs_check.erl:4931-4955`) is shared, so `S(n) when n >= -5 -> ...; S(n) when n < -5 -> ...` is refused as "S is not exhaustive / no clause matches: S(n) -> ..." (the guard credits nothing). Positive control `>= 5 / < 5` is accepted; relational patterns `S(>= -5)`/`S(< -5)` are accepted (57a).
3. **The expression `-3` is typed `int`, not the singleton `-3..-3`** (`bs_check.erl:2874`, `type_of({e_neg,...})` returns `int()`). So `Id(-3)` against `T = int where value <= 3` is refused with `int >= 4`, a diagnostic that names the wrong half; `Id(2)` is accepted (57b).
4. A negative literal on the left of a bare `=` (`(_, -1) = p`) is refused as "must be a literal pattern", while `(_, 1) = p` reaches a different diagnostic ("this bind can fail"), so the left side was accepted (57b).
5. `2 + 3`, `0 - 5`, `2 * 3`, `value >= n`, `value >= -(5)`, `- -5`, `-5 <= value`: all refused today (57a, 57e v0 column). So "where does the fold stop" currently stops before `-5`.

Side finding, not this ticket (57g): a refinement that denotes **one** integer (`value == 1`, `value >= 1 and value <= 1`) passes the checker and then the compile crashes with `compile: ...:0: bad range type`, because the emitted `-spec` says `1..1` and erl_lint rejects equal bounds (shown with a hand-written `-spec f(1..1)`; `1..2` is fine). This confounds any `== K` test; it is why `Neg_eq_single*` is refused in every variant below. It deserves its own ticket.

## Sub-decisions

1. **(Gating) Is `-5` a literal everywhere, or a negation that individual consumers must read?** Everything else follows from this. Asked first, alone.
2. (Follows) Where does constant folding stop: the negated literal only, or constant arithmetic (`2 + 3`)?
3. (Follows, only if 1 answers "negation node") Whether the expression type of `-3` becomes the singleton, so `Id(-3)` works.
4. (Separate, not gated) The singleton-refinement crash (57g) and the `opaque_refinement` wording, which recommends `comparisons on value` and rejects exactly that for `-5`.

## Sub-decision 1: where does `-5` get its meaning?

Measured behaviour for all options is in `57e_variants.out` (matrix of 20 cases x 6 builds). Labels: v0 unpatched control.

### Option A: fold the literal in the parser action, like the float literal already is (v1)

```erlang
negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};
negate(_L, {e_int, IL, N})   -> {e_int, IL, -N};      %% the one added line
negate(L, E)                 -> {e_neg, L, E}.
```

B# that becomes legal:

```csharp
type Delta = int where value >= -100 and value <= 100   // accepted
public atom S(int n)
S(n) when n >= -5 -> :a
S(n) when n < -5  -> :b                                  // exhaustive now
Go() -> Id(-3)                                           // accepted
```

Compiler delta: one clause in `negate/2` (1 line; patch `v1.patch`). No new symbol-table entry, pass or emitted function. The grammar is not narrowed: refinement stays `refinement -> expr_low`.

Evidence (`57e_variants.out`): fixes `Neg_ge_5`, `Neg_and_range`, `Neg_or_split`, `Neg_ne`, `Lit_on_left`, `Parenthesised`, `ParenNeg`, `DoubleNeg`, `Guard_neg_cover`, `NegLit_argument`, `Neg_domain_ok`, and moves the bare-`=` diagnostic from "must be a literal pattern" to "this bind can fail" (the literal is now read). Does **not** accept `2 + 3`, `0 - 5`, `2 * 3`, `value >= n`. Emitted abstract code differs in exactly three nodes, `{op,'-',{integer,5}}` becomes `{integer,-5}`; the BEAM `Code` chunk md5 is identical to v0 (390D44...); `.beam` is 12 bytes smaller (1344 vs 1332). v0 already emits `{integer,_,-7}` for a negative pattern literal and `{integer,_,-1}` for `<= -1`, so a negative integer node is existing practice. Existing tests: `57f_eunit_variants.out`, v1 has the same 5 failures as the unpatched control and none new (the 5 are harness artefacts, below).

Strongest counterargument: the parser now does arithmetic. `-5` is folded but `0 - 5` and `2 + 3` are not, so the line between "readable" and "opaque" is a lexical accident a reader must memorise; and `-2 * 3` parses as `-(2*3)` (the unary rule has `-`'s precedence 400, below `*`), so it stays an unfolded `e_neg` even though `-2 + 3` folds. Also it makes `-5`, `-(5)` and `- -5` indistinguishable after parsing (a feature for refinements, a loss if a later diagnostic wants to say "you wrote a negation").

### Option B: leave the grammar alone, read the negation in the checker (v2, v2b, v2c)

```erlang
const_int({e_int, _, K}) -> {ok, K};
const_int({e_neg, _, E}) -> case const_int(E) of {ok, K} -> {ok, -K}; error -> error end;
const_int(_)             -> error.
%% comparison/1 reads its comparand through const_int/1
```

Compiler delta: `const_int/1` plus two rewritten `comparison/1` clauses in `bs_check.erl` (12 lines, `v2.patch`). v2b adds one `type_of` clause so `-3` is the singleton range (13 lines). v2c adds `+ - *` folding of constants (18 lines, `v2c.patch`).

Evidence: v2 fixes refinement and guard sites (same cases as A) but **not** `NegLit_argument` (`Id(-3)` still refused) and **not** the bare-`=` literal. v2b fixes `Id(-3)`. v2c additionally accepts `2 + 3`, `0 - 5`, `2 * 3`; `value >= n` and `Neg_residual` stay refused. Abstract code and Code chunk identical to v0 (the fold is check-time only). Tests: same 5 control failures, nothing new.

Strongest counterargument: three places must each learn what a negative literal is (comparison, `type_of`, pattern conversion for bare `=`), and the next consumer of `e_int` (a future size or range position) has to remember to call `const_int`. The parser fix cannot be forgotten at a new consumer. In exchange B is the only route to arithmetic comparands, which is what Erlang does (below).

### Option C: narrow the refinement grammar to `value <op> int_lit` (v3, the ticket's first answer)

```erlang
refinement -> lident ref_op int_lit.   refinement -> int_lit ref_op lident.
refinement -> lident '==' atom_lit.    refinement -> refinement 'and'|'or' refinement.  refinement -> '(' refinement ')'.
```

Compiler delta: 7 productions plus a `ref_op` nonterminal in `bs_parser.yrl` (20 changed lines, `v3.patch`); yecc reports the same 6 shift/reduce conflicts as the unpatched grammar.

Evidence: fixes only the refinement cases (`Neg_ge_5`, `Neg_and_range`, `Neg_or_split`, `Neg_ne`, `Lit_on_left`, `Parenthesised`, `Neg_domain_ok`). Leaves `Guard_neg_cover`, `NegLit_argument` and the bare-`=` case broken, and it **newly refuses `-(5)` and `- -5`** (they parse today as an expression). It breaks an existing test: `intervals_tests:an_unreadable_refinement_predicate_is_an_error_test` (`type Email = int where WellFormed(value)`) fails because the case is now a syntax error, not `{opaque_refinement,_}`; that is the O(n)-tier diagnostic text the language reference promises. `57f_eunit_variants.out` v3: 6 failures against the control's 5.

Strongest counterargument (it is the ticket's own): the file says the refinement is an `expr` so that it and a guard cannot disagree; C gives refinements their own grammar and leaves the guard, which shares `alternatives/1`, still unable to say `-5`.

### Recommendation for sub-decision 1

Option A. It is the smallest change that fixes all four symptoms, it follows a precedent already in the same function (floats), it keeps the "refinement is an expr" invariant the ticket wants to protect, and it moves no existing test. Option C is the only one that breaks a test and the only one that leaves guards broken. B is the right shape if sub-decision 2 answers "arithmetic".

Neighbouring languages (probes `57c`, `57d`; sources cited):

- **Erlang** parses `-5` as a unary-minus node and folds in consumers, not the grammar. `erl_parse:parse_exprs("-5.")` gives `{op,0,'-',{integer,0,5}}` while `"0-5."` gives a binary `op` (57c control: the parser tells the two apart). `erl_parse.yrl:269` `expr -> prefix_op expr : ?mkop1(...)`; `erl_parse.yrl:1819` `normalise({op,_,'-',{integer,_,I}}) -> -I;`; `erl_lint.erl:2134-2147` `is_pattern_expr` calls `erl_eval:partial_eval` (`erl_eval.erl:2204`), which folds arbitrary constant arithmetic (`2+3` is a legal pattern and `f(5)` returns `b` in the probe). Control: `N - 5` in a pattern is `illegal pattern`. That is Option B with full folding (v2c).
- **Elixir**: `Code.string_to_quoted("-5")` gives `{:-, [line: 1], [5]}`, unfolded, and `x >= -5` carries that node (57c). Patterns and guards with `-5` compile; `n - 5` in a pattern is refused ("cannot invoke remote function :erlang.-/2 inside a match"). Elixir's parser source is not installed here (only `lib/*` Elixir libraries), so no file:line is given.
- **Gleam**: pattern `-5` and guard `n >= -5` compile; the guard also takes `n >= 2 + 3` and `n >= m`; a pattern `2 + 3` is refused (57d). Gleam's compiler source is not installed, so whether it folds internally is not known; only behaviour is reported. `n >= - -5` was a syntax error in Gleam.
- **Elm**: not probed (see Not verified).

## Sub-decision 2 (only after 1): does the fold stop at the literal?

Under A the answer is built in: `-5`, `-(5)`, `- -5` fold; `2 + 3`, `0 - 5` are refused with the existing `opaque_refinement`. To widen it you take B's v2c, which accepts `value >= 2 + 3` and costs about 6 more lines in `const_int/1`. Nothing in `compiler/examples` or `LANGUAGE.md` needs it (grep for a comparison against a negative or arithmetic literal in `examples/` finds only a comment in `Frame/frame.bs`). Recommendation: stop at the literal. Per CLAUDE.md a new check needs a second occurrence; the same logic says wait for a second program that wants `value >= 2 + 3`.

## Sub-decision 3 and 4

3 is answered by A (`Id(-3)` accepted, `NegLit_argument`). 4 is outside this ticket; file the 57g crash separately. If A is chosen, the diagnostic that "sends the reader back to write the thing it just rejected" disappears for `-5` and needs no wording change.

## Measurements and method

- Case matrix: 20 cases x 6 builds, each build a separate `bsc` invocation on a fresh single-module directory (`57e_variants.out`).
- Abstract code: `.abstr` diff with positions stripped, `-5` in a guard, a literal body and `n + -5`; only A differs, in 3 nodes.
- `Code` chunk md5 via `beam_lib:chunks`: identical in all 6 builds. `.beam` bytes: 1344 for v0, v2*, v3; 1332 for A.
- Compile time, N=7 each, whole `bsc` invocation including VM boot, median ms: v0 370, v1 402, v2 386, v2b 381, v2c 398, v3 417 (min 358-383). The spread is within boot noise (run-to-run maxima vary by ~40 ms); no speed claim is made.
- Existing tests: `57f_eunit_variants.out`, whole `compiler/test` suite per build, sequentially. rebar3 is not installed so `run_eunit.sh` reproduces its layout by hand. The unpatched control fails 5 tests for harness reasons (no `TEST` define for `declared_text`, AOC programs and gates live outside `compiler/`); every variant is compared to that control. Result: A, v2, v2b, v2c add no failures; v3 adds exactly one.
- Patch size (changed lines): A 1, B 12 / 13 / 18, C 20.

## Probe index

| Probe | Claim | Result | Control |
|---|---|---|---|
| `57a_repro_table.sh` / `.out` | Ticket's table still holds; guard `>= -5` credits nothing; `2+3`, `0-5`, `-(5)` refused | confirmed, 18 ok fails=0 | accepted rows (`DisjointPos`, `NotEqZero`, `NegPattern`, `GuardPosCovers`, `PatternNegCovers`), `ZeroRejected` |
| `57b_neg_expr_type.sh` / `.out` | `-3` as an expression is typed `int` (refuses `Id(-3)`); negative literal refused left of bare `=` | confirmed | `PosLitArg` accepted; `PosBare` reaches a different diagnostic |
| `57c_erlang_elixir.sh` / `.out` | Erlang and Elixir parse `-5` as a unary node, fold in consumers | confirmed | `0-5` parses as a different node; `N - 5` in a pattern is an error in both |
| `57d_gleam.sh` / `.out` | Gleam accepts `-5` in pattern and guard, arithmetic in a guard only | confirmed | pattern `2 + 3` refused, bad-type guard refused |
| `57e_variants.sh` / `.out` | Matrix, abstract code, Code chunk, size, time per variant | as in the sections above | v0 column reproduces 57a; `Pos_ctl`, `Atom_eq_ctl` accepted in all builds |
| `57f_eunit_variants.sh` / `.out` | Which existing tests move per variant | only v3 adds a failure | v0 baseline failures |
| `57g_singleton_side_finding.sh` / `.out` | `value == 1` crashes compile with "bad range type" | confirmed | `1..2` compiles; erlc on `1..1` rejects |
| `build_variant.sh`, `run_eunit.sh`, `lib.sh`, `patches/*.patch` | helpers and the five patches | n/a | n/a |

Run from the repo root with the scratchpad `env.sh` sourced (`BSC` is set there). `57e` and `57f` take a work directory argument; `57f` takes about 35 minutes.

## Not verified

- **Elm: not probed.** `elm make` needs `elm/core` from package.elm-lang.org; the proxy blocks it (`elm init` failed with a network error; `~/.elm/0.19.3/packages` is empty). Nothing is asserted about Elm.
- Elixir parser and Gleam compiler sources are not installed; Elixir/Gleam claims are behavioural only, no file:line.
- The repo's own gates (`bin/check-*.sh`, `./bin/verify.sh`) were not run on any variant; only the eunit suite was, and only with the 5 control failures above. The unpatched `TEST`-macro failures mean tests that need test-only exports were not exercised.
- The variants are minimal prototypes, not reviewed implementations: A was not checked against every consumer of `{e_int,_,N}` (for example size positions in binary segments), and B's `const_int` ignores integer-overflow-free semantics because Erlang integers are unbounded.
- `-2 * 3` precedence claim is from reading `bs_parser.yrl` precedence declarations (`-` at 400, `*` at 500), not from a probe.
- Timing is boot-dominated and the machine was shared with no other load during the final run; treat it as "no difference visible", nothing finer.
