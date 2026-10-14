# Decision brief — ticket 39 (ENG-211): why is instruction-identical code 20% slower?

Status of the ticket: **left open.** Evidence: `artifacts/probes/results/39-*.txt`. Limits: `artifacts/README.md`. **This is the brief whose central claim I could not reproduce.**

## The one question David decides

Is the 20% gap real on the platform that matters, such that emitter work is owed, or is it specific to the machine that measured it?
That is decided by one rerun on OTP 28 / Apple Silicon (the ticket's platform), not by argument. Everything below was measured on **OTP 25, x86-64, JIT** (`00-environment.txt`).

## Sub-decisions

1. Is the gap reproducible, and where?
2. Is the cause the missing `{tr, ...}` operand types (the ticket's hypothesis, §1 and §3.2)?
3. If so, can `bs_emit` supply them (§3.3), and what is the ceiling?

## What was measured

- **No gap here** (`39-three-way-bench.txt`, the repo's own `aoc/bench/bench.erl` with the Gleam row removed, three runs of 25): Erlang 12.84–13.09 ms, Elixir 12.88–13.18 ms, beam-sharp 12.97–13.25 ms (minimums); relative 1.00x–1.03x in every run, beam-sharp fastest in one. Verifier reruns gave 1.00–1.02x with beam-sharp fastest each time. The 20% (6.14 vs ~5.1 ms) does not appear.
- **The hot loop is identical, including its type annotations, on this OTP** (`39-disassembly.txt`): `Spin/4` is 26 instructions on both sides with 4 `{tr,...}` operands each; `Wrap`, `Hit` and `Clicks` are identical modulo label numbers, line numbers and names. `Sign` and `Size` differ (13 vs 10 and 10 vs 9 instructions) because the hand-written Erlang `sign` has three clauses and the B# one two; neither is in the hot loop. The ticket's observation that beam-sharp's operands are bare `{x,0}` is **not** true on OTP 25.
- **Stripping the annotations changes nothing here** (`39-annotation-strip-timing.txt`, §3.2 of the ticket, 40 interleaved rounds): Erlang compiled with `+no_type_opt` has **0** `{tr,...}` operands in `spin/4` (default: 4) and runs min 12.92 ms vs 12.97 ms default (medians 13.54 vs 13.36, inside the ±4% noise); `+no_ssa_opt` likewise (12.97 / 13.39). beam-sharp: 13.10 / 13.35. For this loop on this VM the mechanism does not move the clock. Verifier caveat: `+no_type_opt` is not a pure annotation strip (`+to_asm` shows one extra label and a moved `gc_bif`), and a tr-only strip on this exact loop also changed nothing (within 2%). The VM is not insensitive to `tr` in general: on a typed-arithmetic loop the verifier wrote, stripping only the annotations cost 58% (17 vs 27 ms), so the null here is a real null for this loop, not a blind VM.
- Not run: the Gleam row (not installed); records and dispatch (the ticket's open axis); anything on OTP 28 or arm64.

## Neighbours

Gleam, Elixir and Erlang rows are the ticket's, from `aoc/bench/README.md`; I re-ran only Erlang and Elixir. Gleam and Elm are not installed.

## Options

### A. Rerun on OTP 28 / arm64 before anything else, and decide from that
`artifacts/probes/scripts/t39.escript` and `run-all.sh`'s ticket-39 block reproduce all of the above in one command; on the original machine they would show whether the `{tr}` count differs and whether `+no_type_opt` reproduces the 20%.
**Strongest counterargument:** none on the merits, but it needs the original machine, and the number there may simply confirm the ticket.

### B. Record it as a baseline that does not reproduce off its platform and stop (ticket §4's own reading)
Nothing is tuned; the ticket becomes a timestamped note. **Strongest counterargument:** the 20% was measured and may be real on the platform users run; closing it on an OTP 25 result would be closing it on the wrong VM.

### C. Teach `bs_emit` to carry the algebra's ranges (ticket §3.3)
**Not measurable now:** there is no gap on this VM to close, and I did not establish whether the Abstract Format has any channel for `{tr,...}` besides specs (refuted in the ticket). I make no estimate.

## Recommendation

**A, then B or C by its result.** The OTP 28 rerun should strip `tr` alone (not only `+no_type_opt`), or it will not demonstrate the cause. If OTP 28 shows the gap and `+no_type_opt` on the Erlang side reproduces it, the cause is demonstrated and C becomes the next ticket; if not, B. Do not tune the emitter before that rerun.
