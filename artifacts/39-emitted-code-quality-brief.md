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

## Independent verification

Performed adversarially, in a separate session, working in `/tmp/verify39-scratch/` with no
reliance on this brief's saved transcripts as evidence — everything reported below was re-derived
independently: a from-scratch `bsc` build, a from-scratch benchmark run, and, for the two causal
claims, fresh source files this reviewer wrote itself rather than the brief's saved ones. The
git worktree used for the rebuild was removed afterward; nothing in the repo was changed except
this section.

### What was re-run

- **Rebuilt `bsc`** from a `git worktree` at `35dccac` (confirmed: an ancestor of current `HEAD`,
  7 commits behind, with exactly one intervening commit touching `compiler/` — `0e51c9a`, a
  docs-only F-file status update that does not touch `bs_emit.erl` or any code path — so building
  at `35dccac` is equivalent to building at current `HEAD` for this purpose). `HTTPS_PROXY=
  HTTP_PROXY= rebar3 escriptize` under `/opt/otp28-src/bin` on `PATH`, using `/usr/local/bin/rebar3`
  as instructed, succeeded cleanly; `_build/default/bin/bsc` ran and reported its usage banner.
- **Rebuilt the whole-fold benchmark from scratch**: copied `aoc/bench/` and `aoc/2025/` verbatim,
  stripped `gleam.toml`'s `gleam_stdlib` dependency (confirmed unused by `bench_gleam.gleam` — the
  same justification the brief gives), built all four languages independently (Elixir via apt's
  `elixirc`, loaded under the OTP 28 runtime, exactly as the brief's README describes and for the
  same disclosed reason), and ran `bench:main/1` against the tracked `input.txt`.
  - **Result, 7 independent runs total across two sessions: 1.00–1.03x.** This matches the
    brief's reported 1.00–1.02x (§1) closely enough to call reproduced; the headline claim — the
    20% gap does not currently reproduce on this build/hardware — **holds up independently**.
- **Disassembled `Spin/4`** from the rebuilt, non-isolated `Day01.beam` and compared to the
  rebuilt `bench_erl.beam`'s `spin/4`. After correcting an error of my own (below), the two are
  **byte-identical**, including the same `{tr,{x,0},{t_integer,{0,99}}}` /
  `{tr,{x,1},{t_integer,{-1,1}}}` annotations at the same positions — reproducing the brief's
  `spin_disasm_otp28.txt` exactly.
- **Reproduced the `no_type_opt` causal mechanism from two fresh Erlang files this reviewer wrote**
  (`myloop.erl`/`myloop4.erl`, not the brief's `spin_isolated*.erl`), compiled both normally and
  with `no_type_opt`, disassembled and timed both. See §"no_type_opt" below.
- **Reproduced the export-visibility mechanism from two fresh, minimal Erlang files this reviewer
  wrote** (`vis_priv.erl`/`vis_pub.erl`, ten lines each, not derived from the brief's harness). See
  §"harness-bug" below.
- **Checked the `git log` claim**: `git log --since=2026-08-15 -- compiler/src/bs_emit.erl` gives
  exactly 11 commits, matching the brief's count; skimming the 11 subjects (atom chunking,
  `ToExistingAtom`, a nested-prefix/arity fix, a foreign-return boundary guard, float literals,
  `ToJson`, a tagged record, int→float) confirms none is about integer/guard emission for private
  functions, the path this workload exercises.
- **Read the cited compiler source directly** — see "citation problem" below, which is the most
  significant finding of this verification.

### One reproduction error of my own, and what it revealed

My first attempt at the whole-fold rebuild used `aoc/2025/Day01/day01.bs` (the "real," 3-clause
AoC solution, with `when left > 0` / `when left < 0` guards) rather than
`aoc/bench/Day01/bench_bs.bs` (a distinct, pre-existing, already-tracked 2-clause variant —
committed **2026-09-15, a week before this brief and unrelated to it** — whose own header comment
explains it was "written to match the other three EXACTLY for the benchmark"). `build.sh` uses the
latter. Using the wrong file gave a disassembly with an extra guard branch that did not match the
brief's saved transcript — worth recording briefly because it shows what an actual mismatch looks
like (visibly different instruction counts and an added `is_lt` test), in contrast to the
byte-identical match obtained once the correct source was used. This was my own error, not a defect
in the brief; the brief's own probes correctly built from `aoc/bench/Day01/`. It is, however, a
minor real hazard worth naming: nothing in the repo or the brief flags that two differently-shaped
`Spin` implementations coexist under `aoc/`, and a future reader rerunning "the benchmark" from
`aoc/2025/Day01/day01.bs` instead of `aoc/bench/Day01/bench_bs.bs` would get a different, still
non-reproducing-the-20%-gap-but-structurally-different result. Both whole-fold reruns (wrong file
and then corrected) landed in the same 1.00–1.03x band regardless, so this did not change the
top-line finding, only the disassembly-identity claim's precision.

### Scrutiny of the harness-bug (export-visibility) claim: real, independently confirmed

This is the most surprising sub-claim, so it got the most direct test. Two ten-line files:

```erlang
-module(vis_priv). -export([caller/1]).
helper(X) -> X + 1.
caller(N) -> Narrow = N rem 100, helper(Narrow).
```
```erlang
-module(vis_pub). -export([caller/1, helper/1]).   % only line that differs
helper(X) -> X + 1.
caller(N) -> Narrow = N rem 100, helper(Narrow).
```

Disassembling `helper/1` in each: `vis_priv` (helper private) emits
`{gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,{-99,99}}},{integer,1}],{x,0}}`; `vis_pub` (helper
exported, otherwise byte-identical source) emits the same instruction with the annotation gone:
`{gc_bif,'+',{f,0},1,[{x,0},{integer,1}],{x,0}}`. **The only difference between the two files is
the export list, and that alone changes whether `beam_ssa_type` can prove the argument's range.**
This is not a plausible-sounding story invented to explain away an inconvenient result — it is a
real, directly-reproducible property of whole-module type inference (an exported function is
callable from anywhere, so the optimiser cannot narrow its argument type from local call sites
alone), and I reproduced it from scratch with a minimal case, independent of the brief's own
flawed/corrected transcripts (which I also independently examined and found internally
consistent with this mechanism: the flawed run's Erlang `spin/4` carries no `{tr,...}` on the
untyped `+` where beam-sharp's private `Spin` already had one; the corrected run's Erlang `spin/4`
gains the same annotation once only `run/1` is exported). **Verdict: this claim is sound, not
circular, and not overstated.**

### Scrutiny of the `no_type_opt` causal claim: mechanism confirmed, magnitude claim needs a caveat the brief doesn't state

`no_type_opt` is real: confirmed directly by reading `expand_opt(no_type_opt=O, Os) -> ... [O,
no_ssa_opt_type_start, no_ssa_opt_type_continue, no_ssa_opt_type_finish | Os]` with the "kept so
test suites can recompile with this option" comment, **at its correct location**,
`/opt/otp28-src/lib/compiler/src/compile.erl:1090–1096` (the actual OTP 28.5 that built `bsc` and
ran every timing in this brief — see the citation problem below for why this location differs from
what the brief cites). Compiling a fresh file both ways confirms it strips `{tr,...}`.

The **magnitude**, however, turned out to be shape-sensitive in a way this brief's presentation
("costs 1.21–1.22x — almost exactly the ticket's originally-reported 1.20x") does not flag. My
first fresh test (`myloop.erl`, a 3-argument loop with a hardcoded `+1` step, only one
`{tr,...}`-annotated operand per iteration) gave only **1.04–1.05x** with `no_type_opt` — nowhere
near 20%. Suspecting the difference was the number of annotated operands / registers lost, I wrote
a second fresh file (`myloop4.erl`) with a genuine loop-carried `Step` argument (4 arguments,
mirroring `Spin/4`'s register and annotation footprint, though written independently and with
different arithmetic — mod 97, not mod 100). That gave **1.21–1.22x**, matching the brief closely.
So: **the ~20% figure is not a general property of "losing `{tr,...}` costs ~20%"; it is specific
to loops with this register/annotation shape (a stack-carried second loop-invariant-but-not-provably-
constant argument whose type annotation also disappears).** The brief's claim is still
**defensible** — it was always specifically about reproducing the number on the *same-shaped* loop
as the ticket's, not claiming shape-independence — but stating "almost exactly the ticket's
originally-reported 1.20x" without noting that a differently-shaped loop of the same general kind
gives ~5% invites a reader to treat 20% as a more universal constant than the evidence supports.
This is worth a one-line caveat if this brief or its hazard-comment recommendation is carried
into `CONTEXT.md` or `bs_emit.erl`. **Verdict: mechanism sound; magnitude claim sound but
under-caveated.**

### The citation problem: §4's specific line numbers point to the wrong OTP source tree

This is the most significant finding of this verification. The brief's probes README states
`no_type_opt` is documented in "`compile.erl` in `compiler-8.2.6.3` (**OTP 28.5's bundled compiler
app**, installed at `/usr/lib/erlang/lib/compiler-8.2.6.3/src/compile.erl`)", and §4 of the brief
cites `compile.erl:876,2093` and `beam_ssa_opt.erl:257,429,433` for the structural claim that
`{tr,...}` is computed deep inside `beam_ssa_opt` via `beam_ssa_type`, downstream of anything
`bs_emit` controls.

**`/usr/lib/erlang/lib/compiler-8.2.6.3` is not OTP 28.5's compiler.** It is `apt`'s
separately-installed OTP 25 (`erts-13.2.2.5`), left on this container from before OTP 28 was built
from source at `/opt/otp28-src`. Confirmed directly: running the actual OTP 28.5 that built `bsc`
and ran every probe in this brief (`/opt/otp28-src/bin/erl`) and asking it
`code:lib_dir(compiler)` returns `/opt/otp28-src/lib/compiler` — a different directory, different
file size (112KB vs 70KB), different modification date, and a different `COMPILER_VSN` (`9.0.6`,
not `8.2.6.3`) than the file the brief cites. The two files are structurally different documents
(the real OTP 28.5 one has `-moduledoc` blocks the apt one lacks, and roughly 1000 more lines), so
the cited line numbers land on unrelated code in the real file: `compile.erl:876` in the real
source is inside `forms/1`'s doc comment, not the SSA-opt pass list (which is actually at line
1758); `beam_ssa_opt.erl:257,429,433` land on an unrelated pass-list entry and an unrelated
`ssa_opt_dead` clause, not `ssa_opt_type_start/continue/finish` (which are actually at lines
262/264, 441–442, 445–446 in the real file).

**The underlying architectural conclusion survives independent re-verification against the correct
file**, which is the important mitigating fact: I located the real OTP 28.5's equivalents myself —
`beam_ssa_type:opt_start/opt_continue/opt_finish` are indeed called from `beam_ssa_opt.erl`'s
`module_passes/1` (not at the cited lines, but present and doing what the brief says), downstream
of `kernel_to_ssa` and gated by `{unless,no_ssa_opt,{pass,beam_ssa_opt}}` in `compile.erl`'s real
pass list at line 1758; and neither `beam_ssa_type.erl` nor `beam_call_types.erl` in the real
source reads a compiled module's own `-spec` attribute (confirmed by grep — the only `-spec` hits
in both files are those modules' own function specs). So **the conclusion the brief draws from §4
is still true**, but it was reached by reading the wrong installed copy of the compiler and
reporting its provenance incorrectly, and every specific line-number citation in §4 is wrong for
the OTP actually in use. `bs_emit.erl:36` (this repo's own file, correctly read) and `bsc.erl:828`
(off by ~3 lines from the actual `compile:file/2` call at line 831, but the same four-line
statement) are unaffected — the problem is confined to the OTP-source citations. **This should be
corrected**: re-cite against `/opt/otp28-src/lib/compiler/src/{compile,beam_ssa_opt}.erl` before
this brief is treated as a citable reference, since as written it would send a future reader
checking these citations on this exact container to the wrong file and the wrong line numbers,
and on a different machine (without the apt/OTP-25 leftover) to nothing at all.

### Circularity check

No sign that the probes were tuned to the expected result. The two "flawed → corrected" narratives
(export visibility here; the guard mismatch in the benchmark's own README, predating this ticket)
are both the kind of self-caught error a genuine investigation produces, not a smoothed-over story:
the flawed transcripts are preserved unedited alongside the corrected ones, and the flawed run's
direction (beam-sharp *artificially winning* by ~20%, the mirror image of the ticket's complaint)
is not the direction a motivated brief would fabricate if trying to explain away an inconvenient
gap. The one procedural weakness is the citation problem above — reading the wrong installed OTP
copy without noticing is a real methodological lapse (the sort of thing "plausible but not
verified" looks like), but it is a citation/provenance error, not a fabricated or cherry-picked
result, and it happened to land on a conclusion that re-verification against the correct source
still supports.

### ARM64 confound: adequately flagged, not buried

The brief raises this in its opening paragraph, restates it as a named live possibility in §0,
gives it a full paragraph as Option A's "strongest counterargument," and devotes the whole of
Option B to it. That is about as prominent as a caveat can be without blocking on it. This
verification adds nothing new here — no ARM64 hardware was available to this review either — but
confirms the brief did not bury or understate it.

### Overall verdict: SOUND WITH CAVEATS

The headline claim (20% gap does not reproduce on this compiler/OTP/hardware) and the two
mechanism claims (export-visibility can produce a spurious ~20%-shaped asymmetry; `no_type_opt`
genuinely reproduces the ticket's proposed causal mechanism) all independently reproduced from
scratch, including from source files this review wrote itself rather than trusting the saved
transcripts. Two things keep this from a clean SOUND:

1. **The §4 structural citations (`compile.erl:876,2093`, `beam_ssa_opt.erl:257,429,433`) are to
   the wrong OTP source tree** — apt's leftover OTP 25 compiler, mislabeled as "OTP 28.5's bundled
   compiler app" — even though the conclusion they support holds up against the correct source.
   This needs a straightforward fix (re-cite against `/opt/otp28-src`) before the brief is relied
   on as a citable reference, but it does not change the recommendation.
2. **The `no_type_opt` magnitude ("almost exactly 1.20x") is shape-sensitive** in a way the brief
   states as if it were closer to a general finding; a differently-shaped loop of the same broad
   kind gives ~5%, not ~20%. Worth one caveat sentence wherever this finding is preserved
   (`CONTEXT.md` or a `bs_emit.erl` comment per the brief's own Option A).

Neither issue changes the recommendation: Option A (close as "not reproduced on current
`bsc`/OTP 28.5, architecture unconfirmed"; record the mechanism as a hazard comment, not a fix) is
still the right call given everything measured, independently, in this review.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012cL3SdJV7P9jk8MkcDfEni
