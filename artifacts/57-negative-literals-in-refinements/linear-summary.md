**Ticket 57 / ENG-239: decision brief (a recommendation; the ticket is left open).**

Full brief: `artifacts/57-negative-literals-in-refinements/brief.md` (probes, patches and outputs beside it).

**Options, as programs that compile or are refused:**
1. **Grammar fold.** `negate/2` folds `-N` as it already folds `-1.5` (F51). One line. `value >= -100`, guards `when n <= -1`, and `Delta Floor() -> -100` all compile; `n / -0` becomes refused.
2. **Checker fold, unary minus only.** 8 lines in `comparison/1`. Refinements and guards compile, but `Floor() -> -100` is still refused.
3. **Checker fold with `+ - *` and a `type_of` clause.** 15 lines. Everything compiles, plus `value >= 0 - 5`, which nobody writes. Patterns still reject `Sign(<= 2 + 3)`, so the disagreement moves.

**Recommendation:** option 1. All three patched builds still refuse `value >= n`, `value >= x + 1` and `value >= value`. Compile time is unchanged, and the `.beam` code chunk is byte-identical.

**Most surprising finding:** the ticket's mechanism is stale and the bug is wider. Since F51 `-5` is `{e_neg,..}`, not `0 - 5`. A guard `when n <= -1` is silently unread, so the compiler says `Sign is not exhaustive: Sign(<= -1)` for a clause you just wrote. The literal `-5` is typed `int`, so even `int where value < 0` can't be returned `-5`. Only the grammar fold fixes that.

**Separate defect found:** `value == K` fails for every K on the unpatched compiler (`bad range type` from `erlc`, because `bs_emit.erl:1607` emits a one-integer range). It needs its own ticket.

Not covered: Elm (package server unreachable). Gleam and Elixir are probe-only (no parser source). `verify.sh` was not run.
