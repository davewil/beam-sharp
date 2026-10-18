# Decision brief — ticket 39 (ENG-211): why is instruction-identical code 20 % slower, and what is the ceiling?

**Status of the ticket: left open.** This brief recommends; it decides nothing.
Probes: `artifacts/probes/39/` (`bench.sh`, `asm.sh`, `timing.sh`, `order.sh`, `ceiling.sh`, `output-*.txt`). Toolchain and caveats: `artifacts/probes/README.md`.

## The gating question (ask this one alone)

> Does the 20 % reproduce on **your** machine (Apple Silicon, OTP 28) under an interleaved harness?

It is a measurement, not a taste. On the machine and toolchain I could build — x86-64, OTP **28 (erts-16.4, the ticket's own version)** and OTP 29 — the premise of the ticket did not reproduce, so the cause-and-ceiling question has nothing to explain until it does.

## What the ticket claimed, and what running it showed

| ticket claim | measured here | where |
|---|---|---|
| beam-sharp's operands "carry less type information": Erlang has `{tr,{x,0},{t_integer,{0,99}}}`, beam-sharp a bare `{x,0}` | **False on OTP 28 and 29.** `wrap`, `hit` and the hot `spin` compile to the *same* normalised assembly **including every `{tr,…}` and `var_info` type fact**: `wrap` 252 = 252 chars, `hit` 140 = 140, `spin` 605 = 605 on OTP 28; 3/1/4 `{tr,}` operands in each of erlc's and bsc's | `asm.sh` |
| the loop is ~20 % slower (6.14 vs 5.30 ms) | **0.3–1.5 %.** 400 interleaved paired rounds, one scheduler, two runs each on OTP 28 and OTP 29: median ratio beam-sharp/Erlang **1.004, 1.010** (OTP 28) and **1.015, 1.003** (OTP 29); ratio of best times 1.010, 1.042, 0.980, 1.014. An earlier batch of the same script gave 1.009–1.012 medians | `timing.sh` (`output-timing.txt`) |
| the other three cluster within 3 %, which validates the harness | **not here.** Running the ticket's own harness (`aoc/bench`, min of 25 per implementation, one block each) three times on OTP 29 gave Erlang **1.19×, 1.00×, 1.00×** and beam-sharp **1.14×, 1.16×, 1.28×** of the fastest — the harness's run-to-run spread (up to 28 %) exceeds the claimed gap, and beam-sharp beat Erlang in one of three | `bench.sh` (`output-bench.txt`) |
| "run-to-run variance exceeds any difference" (ticket's fib result) | consistent with the above | `bench.sh` |

Two honest qualifications:
- **There is a tiny, consistent residue.** beam-sharp was slower in 255, 256, 274 and 249 of 400 paired rounds (62–69 %; 200 expected by chance) in the saved batch, and in 257–267 in the earlier one. Median 0.3–1.5 % slower. Statistically visible, practically small, **cause not found**. Identical assembly rules out the type-annotation story; I did not test alignment or module-layout effects.
- **Different hardware.** The ticket measured Apple Silicon; this is x86-64 on a shared VM. An arm64 JIT could behave differently. I cannot test that.

## Sub-decisions

| # | Sub-decision | Status |
|---|---|---|
| a | What causes the gap | **no gap of the claimed size to explain** on x86-64 (above) |
| b | What the ceiling is | experiment below shows no demonstrated headroom |
| c | Is the harness fit to settle it | **no**: block-per-implementation, fixed order, min-of-25; its own spread is larger than the effect. The interleaved harness in `timing.sh` is |
| d | The boundary tag guard (ticket 18) "has never been measured at all" | now measured: ≈1.5 ns per test, see ticket 59's brief (`59/cost.sh`: 53 → 38 ms over 5 M iterations × 2 tests) |

## The ceiling experiment (§3.3), and why it says little

`ceiling.sh`: the same arithmetic in plain Erlang with and without range guards of the kind bsc emits for a refined parameter, 3 M iterations, min of 25. Ratio guarded/unbounded across five executions: 0.99 and 1.01 (OTP 28, 29), 0.89 and 1.13 (a second pair), 1.05 and 0.96 (the saved batch) — scatter of ±5–13 %, no signal. The reason is visible in the assembly: `erlc` already infers the same ranges from the call sites of local functions (19 `{tr,}` operands in both variants), so a guard supplies nothing new. The ticket's thesis that the algebra holds more than Erlang's analyser does is not contradicted — it may hold for *exported* functions, where erlc cannot infer arguments — but **this experiment does not show it**, and I did not build the exported case.

## Survey

| language | what it hands the JIT | evidence |
|---|---|---|
| Erlang | `erlc` infers argument types of local functions from their call sites (`var_info` facts in the `.S`) | `asm.sh` (executed on OTP 28 and 29) |
| beam-sharp | the same facts, because bsc emits Abstract Format that `compile:file/2` (`from_abstr`, `debug_info`, `bsc.erl:843`) treats as ordinary Erlang | `asm.sh` |
| Elixir 1.20.4, Gleam 1.19.1 | bench beams compiled from their own sources; timed in the same VM (`bench.sh`), not disassembled | `output-bench.txt` |

Reading: the ticket's "bsc and erlc diverge at the emission boundary" is a claim about a boundary that does not appear to exist on this toolchain.

## Options

**A. Close as not reproducible, record the numbers.** Delta: replace the ticket's measurement table with the interleaved result and a pointer to `timing.sh`; `aoc/bench/README.md` keeps its first-wrong-table note.
Strongest counterargument: the residue is real (62–69 % of paired rounds) and unexplained; closing says "cause: none" about a ~1 % effect I could not trace. And the original measurement was on hardware I did not have.

**B. Ask for one run on the original machine first.** Delta: none in the compiler; run `artifacts/probes/39/asm.sh` and `timing.sh` on the Apple Silicon box (they need OTP 28 + `bsc`; `env.sh` documents the setup).
Strongest counterargument: it delays a closure the x86 evidence nearly supports, and if the arm64 JIT is where the gap lives, the remaining work is in OTP, not in beam-sharp — the ticket would stay open on a problem the project cannot fix.

**C. Pursue the ceiling anyway: emit interval facts for *exported* functions.** Delta: unspecified; needs a mechanism the Abstract Format can carry, which §3.3 listed as unmeasured and I did not measure either.
Strongest counterargument: nothing measured motivates it — erlc already recovers the local-function ranges, and the one experiment that could show headroom (`ceiling.sh`) showed noise.

## Recommendation

**B, then A.** One run of two scripts on the original hardware decides whether the gap was ever about the compiler. If `asm.sh` reports the same identical streams there and `timing.sh` shows ≈1 %, close with A and record the 1 % as unexplained. If arm64 shows a real gap with identical assembly, the cause is in the JIT and the ticket should say so and stop. Do not start C on this evidence.

## Not done / limits

- x86-64 shared VM, 1–5 % run-to-run noise even interleaved; absolute times (≈11 ms) are not comparable to the ticket's 5–6 ms.
- Elixir/Gleam beams are OTP 29 builds, so the OTP 28 batches compare Erlang vs beam-sharp only.
- The residue's cause is unknown; module layout/alignment untested.
- Records and dispatch workloads: only the tag-guard microbenchmark in ticket 59's brief, not an application workload.
- Gleam's `gleam.toml` copy drops the unused `gleam_stdlib` dependency (hex.pm unreachable); documented in `bench.sh`.
