# 57 — negative literals in refinements and guards: probes

## 2026-11-07

**Toolchain: Erlang/OTP 25 (apt), not the pinned 28.5.** rebar3 3.27 does not run on 25, and leex
there has no `TokenLoc`, so `compiler/src/bs_lexer.xrl` was rewritten in a scratch copy with
`TokenLoc` → `{TokenLine,1}` and a stub `adjust_col`. Columns in diagnostics are therefore wrong
(every token reports column 1); acceptance and refusal do not depend on them. The repo's test suite and
gates were **not** run. The scratch build and probes live in the session scratchpad, not the repo.
Parser: `yecc` of the unmodified `bs_parser.yrl` (6 shift/reduce, as shipped).

Probes (each a one-file module directory, compiled with `bsc DIR`):

| probe | source | result at `HEAD` | with `negate(_L, {e_int, IL, I}) -> {e_int, IL, -I};` |
|---|---|---|---|
| refinement | `type Delta = int where value >= -100 and value <= 100` | `opaque_refinement` | compiles |
| guard | `Sign(n) when n <= -1 -> :neg` / `Sign(0)` / `Sign(n) when n >= 1` | `Sign is not exhaustive; no clause matches: Sign(<= -1)` | compiles |
| pattern | `Sign(<= -1) -> :neg` / `Sign(0)` / `Sign(>= 1)` | compiles | compiles |
| arithmetic comparand | `type Band = int where value >= 2 + 3` | `opaque_refinement` | `opaque_refinement` |
| positive control | `type Pct = int where value >= 0 and value <= 100` | compiles | compiles |

Code read: `compiler/src/bs_parser.yrl:591` (`expr_low -> '-' expr_low : negate(...)`), `:947-948`
(`negate/2`: floats folded, everything else `{e_neg,L,E}`), `:471-472` (`int_lit`, patterns);
`compiler/src/bs_check.erl:5136-5163` (`alternatives/1`, `comparison/1`: only `{e_int,_,K}`),
`:1985` (`refine/3` raises `opaque_refinement`). A guard whose `alternatives/1` is `unknown` credits no
coverage (`bs_check.erl` above `alternatives/1`: "An unread guard may always fail"), which is why the
guard form is a silent non-exhaustive rather than a refusal of the guard.

Not measured: how Erlang, Elixir or Gleam handle it (the question is B#'s own AST); the effect of the clause on the test
suite.
