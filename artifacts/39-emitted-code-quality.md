# Decision brief: ticket 39, why is instruction-identical code 20% slower, and what is the ceiling

Linear: ENG-211. Repo ticket: `wayfinder/issues/39-emitted-code-quality.md`.
Status after this brief: **still open**.

Probes: `artifacts/probes/p39_build.sh`, `p39_run.sh`, `p39_structure.sh`, `p39_experiments.sh` (E1, E3, E4, E5, E6), `p39_inline_shape.sh`, `p39_stacktrace.sh`. Patch: `patches/39a-inline-option.patch`.
Machine: x86-64 Linux sandbox, 4 cores, OTP 28 (erts-16.4, the same release the ticket names), Elixir 1.20.4, Gleam 1.19.1. The ticket's numbers came from Apple Silicon. I cannot test arm64, and that matters below. Every timing is the minimum of 25 runs of the 673,364-click fold, taken with the load average under 0.5 (the first table I ran was on a busy machine and I discarded it).

## The one question

Does `bsc` emit `-compile(inline)` (or a chosen `-compile({inline, [...]})`) into the module? The ticket's two questions, what causes the gap and what the ceiling is, both turn out to be answered by this one switch.

## What I measured

**The 20% gap does not reproduce here** (`p39_experiments.sh E1`, five runs of the benchmark's own table, min ms):

| | Erlang | Elixir | Gleam | beam-sharp |
|---|---|---|---|---|
| range over 5 runs | 16.75 to 16.90 | 16.57 to 16.70 | 10.77 to 10.81 | 16.63 to 16.81 |

beam-sharp is level with Erlang and Elixir. **Gleam is 35% faster than all three.** The outlier is Gleam, not beam-sharp. Code placement does not explain the spread: eight copies of the Erlang source under different module names span 1.010 (max/min), eight of the B# source 1.009, and the B# best over the Erlang best is 0.991 (E3). Code placement is not worth more than 1%.

**The ticket's observation about missing type annotations does not hold on this toolchain.** The `Type` chunk of `bench_erl.beam` and of `Day01.beam` is byte-identical (130 bytes each, `p39_structure.sh`). The `erlc -S` listing of B#'s `Spin` carries the same `{tr,{x,0},{t_integer,{0,99}}}` operands as Erlang's. After renaming, `Spin`, `Wrap` and `Hit` are instruction-identical (18, 3 and 3 instructions). `Sign`, `Size` and `Clicks` are not: my B# source orders its clauses differently from the Erlang source, and these run once per rotation, not per click. The §3.2 experiment (strip annotations to match) is therefore moot: there is nothing to strip. I also made the ranges disappear on purpose, by exporting `spin/4` and `wrap/1` in the Erlang source (the `.S` annotation count falls from 18 to 8), and the time did not move: 16.77, 16.80 and 16.83 ms for private, exported, and exported with range guards (E4). **In this loop, type information is worth nothing measurable.**

**What Gleam does differently is inline.** Its module carries `-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline])` and its `spin` has no calls left in it, 25 instructions (`p39_inline_shape.sh`). The ticket's §1 statement that all four emit identical hot-loop code is wrong about Gleam. Turn inlining on elsewhere and the gap closes (E5):

| | min ms |
|---|---|
| Erlang, default | 16.87 to 16.98 |
| Erlang, `erlc +inline` | 10.82 to 10.85 |
| beam-sharp as `bsc` builds it | 16.65 to 16.81 |
| beam-sharp, `-compile([inline])` added to the emitted forms | 10.77 to 10.90 |
| Gleam | 10.80 to 10.89 |

Which function matters (E6, Erlang source, `-compile({inline, [...]})`): none 16.8; `hit/1` only 10.9; `wrap/1` only 11.6; both **9.7 to 9.8**. Selective inlining of the two helpers is faster than Gleam's blanket option, by 10%. That is the ceiling the ticket asked about, and it is above Erlang's default, but it comes from the BEAM compiler's inliner, not from the type algebra.

**Cost of turning it on.** Over the 22 example modules (`corpus.escript`, equal-length output directories): 55972 to 56216 bytes (+244, +0.44%), same guard count. **Stack traces are untested.** My `p39_stacktrace.sh` probe is vacuous: the verifier disassembled both builds and `Weigh` is not inlined in either, so the identical traces show nothing about whether an inlined function's name survives. I did not measure compile time and did not run the test suite with the option on.

## The three programs

**A. `bsc` emits `-compile(inline)` in every module's forms.** Program unchanged. The compiler gains one attribute form in `bs_emit:forms/1`. I would make it a form rather than the option I put in `bsc.erl` for the corpus patch (`39a`). Ticket 13 (lines 178 to 180, 187) says the frontend must not depend on in-process compiler state, so that `.abstr` plus an external `erlc +from_abstr` always works. It does not mention compiler options, so "attribute, not option" is my inference from it. E5 used the attribute form, so it is known to work.
Result: the ticket's loop gets 35% faster (16.7 to 10.8 ms). With the attribute, `Hit` is inlined into `Spin` and `Wrap` is still a call (the verifier checked), which matches E6's "hit only" row at 10.9 ms.
Strongest counterargument: it is a global switch applied blind. The BEAM inliner can grow code in a function that is called from many places, and the +0.44% on the corpus says little about a module with a hundred call sites. It may change the stack trace for any inlined function that fails (not tested, see above), and ticket 18 builds its diagnostics on "the offending argument in the caller's own function".

**B. Inline only what the checker can show is small and private.** Emit `-compile({inline, [wrap/1, hit/1]})` for private non-recursive functions under a size rule. E6 says this reaches 9.7 ms, better than A.
Compiler work: a pass over the private functions, a size measure, and the rule's threshold. Not built.
Strongest counterargument: the size rule is a tuning constant, and the ticket's own section 4 says the emitter has never been tuned; this is the first tuning decision and it needs a second workload to choose a threshold. I have one loop.

**C. Change nothing and record the finding.** The benchmark README's table would be re-run as "Erlang with default options", and the note that Gleam inlines goes beside it.
Strongest counterargument: it leaves a 35% ceiling on the table for the price of one attribute, and the handoff's audition measures fleets against this compiler, so any other implementation that inlines will beat the oracle.

## Recommendation

A, as an attribute in the forms, because it is one line, it matches what Gleam already ships, and E5 shows it recovers the whole gap. Then run the whole suite and the exemplars with it on before it lands, which I did not. B is the better end state and should wait for a second benchmark. I would not describe the gap as "beam-sharp is slower than Erlang": on this machine it is not.

## Limits

- **Architecture.** The ticket's 20% was measured on arm64 and I measured x86-64. On arm64 the ticket reports Gleam within 3% of Erlang, which contradicts the 35% I see for the same Gleam source. So either the arm64 JIT treats inlined code very differently, or something else differs. I cannot tell which, and the conclusion "the gap is inlining" is established for x86-64 only.
- **The ticket's open axis, records and dispatch (the boundary tag test), is still unmeasured.** I did not touch it.
- One loop, one input. The `fib(100,000)` workload in the ticket's §3.4 was not re-run.
- Compile time under the inline option, and the test suite with it on, were not measured.
