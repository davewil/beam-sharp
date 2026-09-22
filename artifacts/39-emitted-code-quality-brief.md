# Ticket 39 — decision brief: the 20% gap, what causes it, and what the ceiling is

Research only. Does not resolve the ticket. All evidence below was executed 2026-09-22 on
**OTP 28.5 (erts-16.4)** built from source, **`bsc` at commit `35dccac`** (current `master`),
**Intel Xeon @ 2.80GHz, 4 vCPU, KVM-virtualized x86_64** — not the Apple Silicon / ARM64 the
ticket's original numbers were taken on. That architecture difference is a real, unresolved
confound in everything below and is called out wherever it matters. Raw transcripts for every
command are in `artifacts/_probes/39/`; see the appendix for the exact rerun command per file.

## 0. Headline finding, before the sub-decisions

**On this build, this OTP and this hardware, the 20% gap does not reproduce.** The whole-fold
AoC Day01 benchmark, rebuilt from the tracked sources with no changes, gives beam-sharp
**1.00–1.01x** against Erlang across 4 runs (§1). The isolated `Spin`/`Wrap`/`Hit` loop, timed on
its own per ticket 39 §3 item 1, gives **1.00x** (§2). Disassembly shows beam-sharp's `Spin/4` is
not merely instruction-identical to hand-written Erlang's — it carries the **same `{tr, Reg,
Type}` JIT annotations**, at the same positions, which the ticket said were missing (§2). At the
same time, a direct causal test (§3, ticket 39 §3 item 2) confirms the *mechanism* the ticket
proposed is real: stripping those annotations from **identical** Erlang source with the
undocumented `no_type_opt` compiler flag costs **1.21–1.22x** — almost exactly the ticket's
originally-reported 1.20x. So the theory of the case (missing JIT type hints cost about 20% on
this shape of loop) is now demonstrated rather than merely observed; what is not demonstrated,
and could not be reproduced here, is that beam-sharp's *current* emitted code is missing them.

This does not mean the ticket's original measurement was wrong. It means one of three things is
true, and this brief cannot fully distinguish them without ARM64 hardware: the gap is
architecture-sensitive (ARM64's JIT may weight these annotations differently than x86_64's); the
gap was present in an earlier compiler build and has since narrowed as a side effect of the 11
`bs_emit.erl` commits landed since 2026-08-15 (none of which mention this ticket or touch the
integer/guard emission path this workload exercises — checked by `git log`, §5); or the original
harness had a confound of the same shape and magnitude as the one this research nearly shipped by
accident (§2's "flawed" run) and the ticket's own re-run discipline (README's "re-run before
resolving") did not happen to catch it. All three are live; David should pick which one matters
enough to chase.

## 1. The sub-decisions this ticket actually implies

The ticket is phrased as one question ("decide what causes it and what the ceiling is"). Broken
into calls David can actually make:

1. **Is there still a gap to explain at all?** The ticket's own README says "re-run `aoc/bench/`
   before resolving" — that re-run is §1 below, and on this hardware it says no. Decide whether
   ticket 39 should be **closed as "not reproduced on current `bsc`/OTP 28.5, architecture
   unconfirmed"** rather than resolved with a causal story for a gap that may no longer exist.
2. **Is the causal mechanism worth recording even though the gap isn't currently present?** §3
   shows the `{tr,...}`-loss mechanism is real and costs ~21% on this exact loop shape when
   deliberately induced. That is durable, architecture-independent-in-principle knowledge about
   *why* this class of gap would appear if it ever does (e.g., after a future `bs_emit` change
   changes the clause/guard shape of a hot private loop). Decide whether that belongs in
   `CONTEXT.md` or a comment in `bs_emit.erl` as a standing hazard, independent of whether this
   specific ticket closes.
3. **Is "inject `{tr,...}` from `bs_emit`" even a real option, or a category error?** §4 answers
   this structurally: no. `{tr, Reg, Type}` is not an Abstract Format node — it doesn't exist
   until `beam_ssa_type` runs on the SSA form, several IR-lowering passes after `bs_emit`'s output
   is consumed, deep inside the single `compile:file/2` call `bsc.erl:828` makes. Decide whether
   to formally retire "teach bs_emit to emit type hints" as a design direction (it isn't a
   direction the chosen target — ticket 13's Abstract Format — can support) versus keeping it as
   an open idea that would require *also* revisiting ticket 13's target choice.
4. **What is the actual ceiling, now that "beat Erlang" and "lose to Erlang" are both live
   possibilities?** Ticket 39 §2 argued beam-sharp's algebra is *strictly richer* than what
   Erlang's compiler infers (exact intervals vs. a quantised ladder, per ticket 20), so the
   ceiling should be *above* Erlang, not merely at parity. §4 shows why that richer algebra
   currently has **no channel** into `beam_ssa_type` — specs don't feed it either (confirmed by
   reading `beam_ssa_type.erl`/`beam_call_types.erl`, neither references the compiled module's own
   `-spec` attribute as a data source, consistent with ticket 13/39's own spec-stripping result).
   The realistic ceiling on the current target is **parity with equivalently-shaped hand-written
   Erlang** for any loop whose emitted clause/guard structure matches what a human would write —
   which this benchmark's *private* `Spin`/`Wrap`/`Hit` do. Decide whether "parity, not
   superiority, is the ceiling under the Abstract Format target" is an acceptable answer to record,
   or whether it reopens ticket 13's target choice.
5. **Does this benchmark's shape generalise to a hot loop that must itself be *public*?** Every
   function this benchmark's speed depends on is `private`; only the one-shot outer wrapper
   (`PartTwo`/`Run`) is public. A public hot loop gets F24's boundary guard (an `is_integer` test,
   possibly range tests) on *every call*, which no hand-written Erlang loop pays and which has
   never been measured here. Decide whether that's worth a fifth exemplar before this ticket is
   called settled for "the ceiling" in general, as opposed to for this one loop shape.

## 2. Options

### Option A — Close as "not reproduced"; record the causal mechanism as a standing note, not a fix

**What it says**: the gap this ticket was raised to explain is not present in the current
compiler on the hardware available to re-check it. Rather than build a remedy for a defect that
doesn't currently exist, record §3's causal finding (loss of `{tr,...}` costs ~21% on this shape)
as a documented hazard — e.g. a comment near `bs_emit.erl`'s guard-emission code warning that a
future change which makes a hot private loop's clause shape diverge from idiomatic Erlang (extra
guards, different argument order, a wrapped/aliased pattern) could reintroduce exactly this cost,
now that its mechanism and magnitude are known. Re-open only if a future run (ideally on ARM64, or
after a further `bs_emit` change) reproduces the gap.

**Evidence for it**: §1 (4 whole-fold runs, 1.00–1.02x), §2 (3 isolated-loop runs after fixing an
export-visibility confound, 1.00–1.05x, beam-sharp indistinguishable from Erlang and Gleam),
disassembly showing byte-identical `{tr,...}`-annotated instructions in both the original Day01
module and the isolated one (`spin_disasm_otp28.txt`, `isolated_full_disasm_corrected.txt`).

**Strongest counterargument**: this brief has no ARM64 hardware. The ticket's original number came
from Apple Silicon and was "consistently 20% behind" across repeated runs, which is not the
signature of ordinary noise (the other three languages clustered within 3% in the same runs).
Closing on x86_64-only evidence risks closing a real, architecture-specific gap. The honest
counter to the counter: this brief's own causal experiment (§3) shows the mechanism is x86_64-real
too (21–22%, same OTP, same hardware) — so if the annotations were genuinely missing from
beam-sharp's output, this hardware would show it, and it doesn't. The likeliest reading is that
whatever was missing at ticket-filing time is no longer missing, on either architecture; but that
is an inference, not a measurement of ARM64 today.

### Option B — Re-run on the original (or any ARM64) hardware before deciding anything else

**What it says**: don't decide the causal question or the ceiling from x86_64 evidence alone. Get
one clean re-run of `aoc/bench/` on ARM64 with the current `bsc`, using the exact procedure in
`aoc/bench/README.md`. If the gap reproduces there, this brief's §2–§4 still stand as the
*mechanism* and the *structural* answer — the only thing that changes is item 1's disposition
(gap is real, architecture-sensitive, and worth chasing further, e.g. via bs_check emitting
guard-visible refinements that narrow argument types for hot private functions in ways closer to
what idiomatic Erlang happens to write).

**Evidence for it**: none gathered here — this option is explicitly about the evidence this brief
*couldn't* gather. The case for it is the gap in the record: ticket 39's own number is
irreproducible on the only hardware available to this research, and "irreproducible" is not the
same claim as "wrong."

**Strongest counterargument**: cost. This is a benchmarking session on a single tight-integer
loop, not a standing regression suite; ticket 39 §4 already says no optimisation work has been
done on this compiler and a 20% gap on an untuned emitter is "a starting number," not a verdict.
Spending a second dedicated session chasing a number that may simply be stale risks becoming the
"tracking layer" pattern CLAUDE.md warns against — three sessions of measurement with no language
or compiler work landing. If David re-runs `aoc/bench/` as part of otherwise-scheduled ARM64 work
(e.g. the OTP-range CI corpus ticket 13 §4 already owes), that's free; a session whose only output
is "confirmed on ARM64 too" is a weaker use of a session than Option A's close.

### Option C — Treat §4's structural finding as reopening ticket 13, not as closing ticket 39

**What it says**: if David wants beam-sharp's provably-tighter type algebra (ticket 20's exact
integer intervals) to ever produce JIT code *better* than equivalent hand-written Erlang — the
"ceiling above Erlang" ticket 39 §2 argued for — then §4 shows that is structurally impossible
under the Abstract Format target as currently used, because `{tr,...}` doesn't exist until deep
inside `compile:file/2`, several passes past anything `bs_emit` controls, and nothing about that
target lets a frontend hand the SSA optimiser extra facts (specs don't feed it either). The lever
that *would* work — emitting Core Erlang or hand-lowered SSA directly, with real `{tr,...}`
annotations baked in by beam-sharp itself instead of `beam_ssa_type` inferring them — is exactly
the path ticket 13 rejected, for reasons (spec/Dialyzer survival, reversibility, host-language
freedom) that had nothing to do with this. Reopening it on performance grounds alone is a new
argument ticket 13 was never asked to weigh.

**Evidence for it**: `bs_emit.erl`'s header (lines 1–22) and `forms/1` (line 36) — the function
that is `bs_emit`'s entire public contract returns `erl_parse`-shaped forms, nothing lower;
`bsc.erl:828`, the single `compile:file(AbstrPath, [from_abstr, ...])` call that is the whole
pipeline from there; `compile.erl:876` (`{unless,no_ssa_opt,{pass,beam_ssa_opt}}`) and
`beam_ssa_opt.erl:257,429,433` (`beam_ssa_type:opt_start/opt_continue/opt_finish`), which is where
`{tr,...}` is actually computed, downstream of `beam_kernel_to_ssa` and therefore of registers
that don't exist at the Abstract Format stage at all. `beam_ssa_type.erl` and
`beam_call_types.erl` were grepped for any read of a compiled module's own `-spec`; none exists —
consistent with ticket 13/39's own finding that stripping specs didn't move the number.

**Strongest counterargument**: this is a large, expensive door to reopen (ticket 13 called Core
Erlang a "one-way door" the other direction and spent a whole ticket on it) for a gap that, per
Option A's evidence, may not currently exist. Spend the reopening only if Option B's ARM64 re-run
comes back positive *and* someone can show a realistic beam-sharp program where the extra interval
precision would matter and Erlang's own inference provably can't recover it — which is not this
benchmark; here Erlang's ordinary `rem`/guard-based inference already recovers `0..99` exactly,
so there was nothing extra for beam-sharp's algebra to contribute even in principle.

## 3. Recommendation

**Option A**, with Option B's re-run left as a cheap follow-on rather than a blocker. The evidence
in hand says: the gap ticket 39 was raised to explain is not present in the compiler David has
today, on the hardware available to check it; the mechanism it hypothesized is real and now
causally demonstrated at almost exactly the reported magnitude, which is worth keeping as
institutional memory; and the specific remedy the ticket's own §3 gestured at ("can `bs_emit`
supply the missing type info") has a clean, checkable, negative structural answer that forecloses
a whole branch of future work (§4) rather than leaving it an open maybe. Closing on that basis
costs nothing David hasn't already paid for, and it converts a stale timestamped claim (per the
README's own warning about that failure mode) into a settled one. If ARM64 access becomes
available for other reasons, a five-minute re-run of `aoc/bench/` is worth doing then; it is not
worth a dedicated session now.

**What the ceiling answer should say, regardless of which option is chosen**: parity with
equivalently-shaped hand-written Erlang, not superiority, for as long as the target is the
Abstract Format compiled by `compile:file/2` unmodified. Superiority would require either (a) a
future beam-sharp program where Erlang's own SSA-level inference genuinely can't recover what
beam-sharp's checker knows (this benchmark isn't one — verified, §4), or (b) revisiting ticket 13
(Option C). Neither is close at hand.

## 4. Probes run

All transcripts and source files are under `artifacts/_probes/39/`; `artifacts/_probes/39/README.md`
has the exact rerun command for each. Summary:

| # | What | Command (abbreviated — full form in the probes README) | Transcript |
|---|---|---|---|
| 0a | Build `bsc` under OTP 28.5 | `PATH=/opt/otp28-src/bin:$PATH rebar3 escriptize` (from `/usr/local/bin`, not apt's) | — (build log only, not saved; escript verified at `compiler/_build/default/bin/bsc`) |
| 0b | Build the whole-fold benchmark, all 4 languages, OTP 28.5 | `erlc`/`elixirc`/`gleam build`/`bsc -o` per `aoc/bench/build.sh`'s own recipe, copied to scratch (gleam's hex dependency stripped — unused by `bench_gleam.gleam`, hex.pm unreachable through the proxy) | — |
| 1 | Whole-fold timing, 4 runs | `erl -noshell -pa <out> -s bench main aoc/2025/Day01/input.txt` | `baseline_wholefold_run1.txt`, `baseline_wholefold_runs2-4.txt` |
| 2 | Disassemble `Spin/4` in the original (non-isolated) modules | `escript disasm.escript bench_erl.beam spin` / `... Day01.beam 'Spin'` | `spin_disasm_otp28.txt` |
| 3 | Build isolated Spin-loop modules (first, flawed pass — all Erlang/Elixir/Gleam functions exported, beam-sharp's stayed private) | `erlc`/`elixirc`/`gleam build`/`bsc -o` on `spin_isolated.*`, `Day01Isolated_spin_isolated.bs` | `isolated_full_disasm_FLAWED_export_mismatch.txt` |
| 4 | Isolated-loop timing, flawed pass, 3 runs | `erl -noshell -pa <out> -s isolated_bench main` | `isolated_spin_timing_otp28.txt` (superseded — see #6) |
| 5 | Corrected isolated modules (only `Run`/`run` public everywhere) rebuilt and disassembled | same tools, corrected sources | `isolated_full_disasm_corrected.txt` |
| 6 | Isolated-loop timing, corrected, 3 runs | `erl -noshell -pa <out> -s isolated_bench main` | `isolated_spin_timing_otp28_corrected.txt` |
| 7 | Build `spin_isolated.erl` normally and with `no_type_opt`, disassemble both | `compile:file(Src, [{outdir,D}])` vs `compile:file(Src, [{outdir,D}, no_type_opt])`, then `disasm.escript` on each | `no_type_opt_disasm.txt` |
| 8 | Causal timing: identical source, with/without `{tr,...}`, 3 runs | `erl -noshell -pa ebin_causal -s causal_bench main` | `no_type_opt_causal_timing.txt` |
| 9 | `git log` on `bs_emit.erl` since the ticket's 2026-08-15 measurement date | `git log --format='%h %ad %s' --date=short --since=2026-08-15 -- compiler/src/bs_emit.erl` | inline in this brief (§0); 11 commits, none touching this workload's guard/private-function emission path |
| 10 | Structural read: where `{tr,...}` originates and where `bs_emit`'s contract ends | grep + read of `bs_emit.erl:1-36`, `bsc.erl:828`, `compile.erl:876,2093`, `beam_ssa_opt.erl:257,429,433`, `beam_ssa_type.erl`, `beam_call_types.erl` (no `-spec`-reading code in either) | not a runtime probe; citations are exact file/line, given in §4 above |

Source files preserved for byte-for-byte rerun: `spin_isolated.erl`, `spin_isolated.ex`,
`spin_isolated_gleam.gleam`, `Day01Isolated_spin_isolated.bs`, `disasm.escript`,
`isolated_bench.erl`, `spin_isolated_normal.erl`, `spin_isolated_no_type_opt.erl`,
`causal_bench.erl` — all under `artifacts/_probes/39/`.
