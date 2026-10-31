# Decision briefs, 2026-10-31 (scheduled run)

Five oldest open map tickets. **None resolved**; every decision is left for review.

| Ticket | Linear | Brief | Verification |
|---|---|---|---|
| 60 who may name this module | ENG-242 | 60-which-modules-may-name-this-one/brief.md | verification.md (PASS, minor citation fixes) |
| 62 outbound ABI (function casing) | ENG-252 | 62-function-name-casing/brief.md | verification.md (headline confirmed; 6 defects listed) |
| 64 option/result collapse at term | ENG-254 | 64-term-absence/brief.md | verification.md (reproduces; weak controls listed) |
| 65 reserved names policy | ENG-255 | 65-reserved-names-policy/brief.md | verification.md (sound) |
| 66 union name in pattern | ENG-309 | 66-union-in-pattern/brief.md | verification.md (sound; several misstatements listed) |

## Toolchain limits of this run (read before trusting any "measured")
- Available: Erlang/OTP 25, Elixir 1.14.0 (apt). **Not run: Gleam, Elm** (binary download was denied by the sandbox; not worked around).
- **bsc could not be built** (needs OTP 27+ leex; OTP 25 lacks `TokenLoc`). Every B# compile/refuse verdict is read from source/tickets, and the BEAM-side emission is a hand-written Erlang stand-in, not bsc output.
- Elixir is installed as beams only, so no Elixir file:line citations exist.
- Each brief's claims table labels rows measured / UNPROBED / INHERITED. Each verification.md was written by a separate subagent that re-ran the probes and mutated them.
