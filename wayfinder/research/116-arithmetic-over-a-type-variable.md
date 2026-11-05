# 116 — arithmetic over a type variable: probes

## 2026-11-05

**Toolchain: not the pinned one.** `.tool-versions` pins OTP 28.5. This sandbox has Ubuntu's OTP
25.3.2.8 (`apt`), and `rebar3 compile` crashes there in `leex` (`{error_location, column}` and
`TokenLoc` need a newer leex). The probes ran on a scratch build of `compiler/src` at `65e67c8`:
`leex`/`yecc`/`erlc` by hand, with `TokenLoc` replaced by `{TokenLine, 1}` and `adjust_col/3` stubbed
in a **copy** of `bs_lexer.xrl` outside the repo. Columns in diagnostics are therefore `1` where the
real compiler gives a real column; nothing else in the output depends on the patch. Run once the
pinned toolchain is available if the exact text matters.

| Probe | Result |
|---|---|
| `Total<T>` as in the ticket, `Total [250, 1200]` | `1450` |
| same, `Total ["250","1200"]` (CLI args are not type-checked) | `crashed: error:badarith` |
| `FromForm() -> Total(["250", "1200"])` beside generic `Total<T>` | compiles; running it: `crashed: error:badarith` |
| same with `Total(list<int>)` | `error: FromForm hands Total an argument it does not accept` |
| generic `Total<T>` with `operand_verdict/2`'s `andalso not Variable()` clause replaced by `andalso true` | `error: `+` in Total has `T` on its left` / `` `+` takes an int or a float on each side; this operand has neither part.`` |
| every `.bs` directory in `compiler/examples/` outside `exemplars/` (28), stock vs. patched | identical error counts |

The `bs_check.erl:4189` comment and F67 line 68 say the exemption is undecided; ticket 27 §3 (line
341 onward) names arithmetic as what a bound would grant.
