# Decision brief: ticket 39 (ENG-211), emitted-code quality

Author: research agent, 2026-09-28. Nothing under `wayfinder/` or `compiler/` was touched; nothing resolved.
Labels: **MEASURED** (probe I ran here, `probes/<file>`), **SOURCE** (installed source, file:line), **RECORDED**
(a ticket/README says it, not re-run), **UNVERIFIED**. Gleam: **not probed**.
Host for every MEASURED row: **OTP 25 (erts-13.2.2.5, `emu_flavor=jit`), x86-64 Linux 4-vCPU shared VM, Elixir 1.14.0, compiler-8.2.6.3**
(`probes/versions.out`). The ticket's numbers are OTP 28 / Apple Silicon. Nothing here reproduces an OTP-28 number.
`bsc` cannot be built here, so every "B# shaped" case below is hand-written Erlang, not bsc output.
Absolute times here (13.2 ms) are 2.5x the ticket's (5.3 ms): different machine, so only ratios mean anything.

## Question

Ticket 39: beam-sharp's Day-01 loop is 20% slower than Erlang/Elixir/Gleam with instruction-identical bytecode, and
the only visible difference is missing `{tr,Reg,Type}` operand annotations. What causes it, and what is the ceiling?
The ticket hypothesises that beam-sharp "knows" `0..99` and throws it away at emission, and asks whether `bs_emit`
can carry the checker's ranges into the optimiser.

## Headline

The ticket's causal hypothesis **did not survive its own §3.2 experiment when run in Erlang alone on OTP 25**:
stripping every `{tr,..}` annotation from the Erlang loop costs 0.15% (min-of-300), not 20%. That is a statement
about OTP 25's JIT, not about OTP 28, and it is the exact experiment that must be repeated on the ticket's own machine.
Separately, the Abstract Format has **no channel** by which guards or specs deliver ranges to `beam_ssa_type` on OTP 25.

## Sub-decisions

(a) **Cause: are missing `{tr}` annotations the cause?** Not established. On OTP 25 the annotations are not a cause
for this loop (rows E4, E5). Whether they are on OTP 28 is UNVERIFIED and is a 10-minute experiment (Option 1).
I could not reproduce the missing-annotation state at all: six emitter-shaped variants of the Erlang loop keep
every annotation (row E6).

(b) **Can `bs_emit` carry proven ranges via Abstract Format? By what mechanism?** Guards: no on OTP 25 (E8, E9).
`-spec`: no (E7). Nothing else was found. The one input that *does* reach the optimiser is what it computes itself:
literals, arithmetic (`beam_bounds`), `is_integer/1`, `=:=`, and for private functions the join of call-site
argument types (E1). OTP 28 behaviour for comparisons is UNVERIFIED.

(c) **Is ticket 04's mandatory-signature/widening rule load-bearing for performance?** No, on OTP 25. The declared
type reaches the beam only as a `-spec`, and specs are dropped before the kernel pass (E7s) and change nothing (E7). The ticket's
§2 "tension" (declaration discards the range) has no mechanism here. A different, real interaction was found in
F24/F37's boundary guards instead (E10): they cost time and buy no type information.

(d) **Worth doing now, given no optimisation work exists?** Not an emitter feature. Do the OTP-28 discriminating
experiment first (Option 1); adopt Option 2 only if David wants public hot loops fast. It is measured and cheap.

## Evidence table

| # | Claim | Label | Source |
|---|---|---|---|
| E0 | Host is OTP 25, JIT flavour; Gleam absent | MEASURED | `probes/versions.out` |
| E1 | Exported functions' args start as `any`; private functions get the join of call-site arg types; exported args cannot be narrowed | SOURCE | `beam_ssa_type.erl:119-121, 381-391, 432-441, 689-695` (`/usr/lib/erlang/lib/compiler-8.2.6.3/src/`) |
| E1m | Same shape, exported (`v_exp`) loses 3 of 6 `{tr}` in the module (`spin` args go bare); private (`v_base`) keeps all 6. Instruction stream identical after erasing `tr` except the `+` live-register count 2 vs 4 | MEASURED | `probes/tr_summary.out`, `probes/instr_identity.out` |
| E2 | Baseline `spin/4` is 19 instrs, `wrap/1` 4; Type chunk 116 B (typed) vs 26 B (`no_type_opt`) vs 80 B (exported); `.beam` 1344 B | MEASURED | `probes/sizes.out` |
| E3 | Elixir 1.14 and Erlang `bench_erl.erl` produce the same `spin`/`wrap` instructions (labels differ only) and same 116 B Type chunk; Elixir `.beam` is 2652 B | MEASURED | `probes/instr_identity.out` (`ex_asm`), `probes/sizes.out`, `probes/elixir_tr.out` (asm recovered from the beam's debug_info and recompiled, not elixirc's own flags) |
| E4 | `+no_type_opt` strips all `{tr}` (0 in module) and changes the hot `+` live count only; min-of-300 13.292 vs 13.272 ms = **+0.15%**; second and third independent VMs: -0.1%, -0.1% | MEASURED | `probes/tr_summary.out`, `probes/timing.out`, `probes/timing_repeat.out` |
| E5 | `no_type_opt` compiles out `{tr}` via `no_ssa_opt_type_{start,continue,finish}` | SOURCE | `compile.erl:277-288` |
| E5c | Positive control: `no_type_opt` **does** slow a tuple-match loop by 40% (6.7 vs 9.9 ms min) but that loop's instruction count also changes 6 -> 11; a binary-match loop with equal instruction count (13 = 13) shows +1%..+3% on min (noise-level; medians +0.3%..+3%). So on OTP 25 I saw slowdowns only where the instruction stream changed, never from annotations alone | MEASURED | `probes/control.out`, `probes/sizes.out` (`ctl_*`) |
| E6 | Emitter-shaped variants keep all 6 annotations: `Sign`/`Size` written as in `Day01/bench_bs.bs` (`v_bs`); `erlang:'rem'/2` remote spelling (`v_remote`); line-0 annotations + `~p` `.abstr` + `compile:file([from_abstr,debug_info])` + widened `integer()` specs on every function + extra exported `'bs@type_atoms'/0` (`v_abstr`, built the way `bsc.erl:843` builds). All within 0.5% of base | MEASURED | `probes/tr_summary.out`, `probes/timing.out`; emitter facts SOURCE `compiler/src/bs_emit.erl:21, 72-75, 1334-1335`, `bsc.erl:843` |
| E7s | Specs are dropped before the kernel pass: `include_attribute(spec) -> false` | SOURCE | `v3_kernel.erl:148` |
| E7 | Tight `-spec` on the exported loop leaves the instruction stream equal (empty diff `v_exp` vs `v_exp_spec`) and the Type chunk at 80 B; time 12.941 vs 13.101 ms min (within run noise; 13.065 vs 13.060 on the previous full run) | MEASURED | `probes/instr_identity.out`, `probes/sizes.out`, `probes/timing.out` |
| E8 | No relational operator narrows integer ranges: `infer_type` has clauses only for `is_*`, `'=:='`, `succeeded`; every other op falls to `{[],[]}`; comparison bifs are excluded from type annotation | SOURCE | `beam_ssa_type.erl:2260-2370` (fallback :2369), `:629-636` |
| E9 | Guard `is_integer(P), P>=0, P=<99` on exported `spin` yields `{t_integer,any}` on P, never a range; the two comparisons stay in the emitted code as extra tests | MEASURED | `probes/tr_summary.out` (`v_exp_rng`), `probes/instr_identity.out` (25 vs 19 instrs) |
| E10 | That guard costs **+6.3%** vs the same exported loop without it (13.933 vs 13.101 ms min; +6.4%, +6.2% on two more VMs), +5.0% vs the private baseline; `is_integer` alone costs 0 (13.258); the same range guard on a *private* function costs ~0 (13.166; the optimiser removes half the tests using call-site types) | MEASURED | `probes/timing.out`, `probes/timing_repeat.out` |
| E11 | Guard hoisted into an exported wrapper with a private guard-free worker (`v_wrap`) costs nothing: 13.078 ms, -1.5% vs base, same on 2 more VMs | MEASURED | `probes/timing.out`, `probes/timing_repeat.out` |
| E12 | Exported-args loops (`v_exp`, `v_exp_spec`, `v_wrap`) are consistently **1.3-1.5% faster** than the private baseline (min 12.94-13.10 vs 13.25-13.27, three separate VMs), i.e. losing call-site ranges did not slow this loop and, if anything, sped it. Cause not investigated | MEASURED | `probes/timing.out`, `probes/timing_repeat.out` |
| E13 | Run-to-run noise: stdev 0.5-2.6 ms on a 13.3 ms min, p90 ~+8..+35%, so medians on this VM are unreliable; min-of-300 was stable to ±0.1 ms across 4 VMs/processes | MEASURED | `probes/timing.out`, `probes/timing_repeat.out` |
| E14 | B# already emits `is_integer` + range guards on **exported** functions with refined `int` params (F24/F37); private functions get none | SOURCE | `compiler/src/bs_emit.erl:322-336, 341-460`; `compiler/features/F37-boundary-range.md:3` |
| E15a | Ticket's OTP-28 numbers: beam-sharp 6.14 vs Erlang 5.30 ms (1.20x); Erlang spin has `{t_integer,{0,99}}` | RECORDED | `wayfinder/issues/39-emitted-code-quality.md`, `aoc/bench/README.md` |
| E15b | On OTP 25 the same Erlang source annotates spin's Pos `{t_integer,{-99,99}}`, not `{0,99}` | MEASURED | `probes/tr_summary.out` |
| E16 | The ticket's own spec-stripping test (6.51 vs 6.54 ms) | RECORDED | `wayfinder/issues/39-emitted-code-quality.md` §1 |
| E17 | Ticket 20 quantises integer ranges onto a fixed ladder in one domain; ticket 20's intervals are "exact" in the algebra | RECORDED | `wayfinder/issues/20-untheorised-term-shapes.md:720-725` |
| E18 | Whether the OTP-28 loader/JIT consumes `{tr}` differently; how Elixir obtains ranges beyond "same compiler" | UNVERIFIED | no erts or Elixir compiler source installed |
| E19 | Anything about Gleam | not probed | Gleam not installed |

## Options

### Option 1: change nothing in the emitter; run the ticket's §3.2 on the ticket's machine, on the real bsc output

B# code: `Day01/bench_bs.bs` unchanged. Compiler delta: none. Work is a script, not a feature:
`bsc -o out Day01` (leaves `out/Day01.abstr`), then on OTP 28
`erlc +from_abstr +to_asm out/Day01.abstr` (RECORDED: `bsc.erl:838-840` says `.abstr` plus external `erlc` always works)
and `erlc +from_abstr +no_type_opt`, timed with the interleaved harness `probes/timing.erl`, min-of-300, three VMs.
Two possible readings: (i) `no_type_opt` slows Erlang by ~20% on 28, so annotations are the cause and Options 2/3
become live; (ii) it does not, so the cause is elsewhere in bsc's real forms, which the `to_asm` diff will show
(the ticket saw the annotation difference in `Spin` only, by eye).
Measured evidence for choosing this: E4, E5c, E6 (the OTP-25 hypothesis fails and I cannot construct the missing state).
**Strongest counterargument:** it produces no new capability, and the README's headline "20% slower" stays in the
repo unexplained. Also OTP 25 may simply be the wrong proxy, in which case my evidence says little. **Cost:** about an
hour; no code in `compiler/`.

### Option 2: worker/wrapper split for public functions with refined `int` parameters

B# code the author writes (unchanged):

```
public (int, int) Spin(Octet pos, int step, int left, int zeros)   // Octet = 0..99
Spin(pos, step, 0, zeros) -> (pos, zeros)
Spin(pos, step, left, zeros) -> Spin(Wrap(pos + step), step, left - 1, zeros + Hit(pos))
```

Today `bs_emit:clause/4` prepends the F37 boundary tests to *every clause*, including the self-recursive call,
so the guard re-runs each iteration. Delta: for a public function whose clauses would receive boundary tests, emit
`'Spin'/4` as one guarded clause that tail-calls a private `'Spin$w'/4` holding the guard-free clauses, and rewrite
in-module self/local calls to the worker (the checker already proved them). One symbol-table entry (worker name),
one emitted function per such public function, a change to `function/2` and `clause/4` in `bs_emit.erl`.
Measured evidence: the same loop shape, exported with the F37-style guard, runs **+6.3%** (E10); with the guard
hoisted (`v_wrap`) it runs at baseline or 1.5% better (E11). The wrapper `call` costs nothing measurable here.
**Strongest counterargument:** the win only exists for *exported self-recursive hot functions*, which the Day-01
exemplar is not (all helpers are private, which already skips the guards); Option 2 fixes a cost that no shipped
program pays. It also renames frames in stack traces and Dialyzer/`erlang:apply` see two functions. And this does
nothing for the ticket's 20%. **Cost:** a pass in `bs_emit` plus tests, and ~0 runtime; a new F-file and gate per
CLAUDE.md, not started here.

### Option 3: the ticket's §3.3 proposal, emit the checker's ranges as guards/specs so the optimiser sees them

B# code: same as Option 2's `Spin`, but the compiler owes the range at every private call as well:
`'Spin'(Pos, ...) when is_integer(Pos), Pos >= 0, Pos =< 99`. Delta: extend `int_guard/6` and `range_test/3` (bs_emit)
to private functions and to the return type. **The evidence on OTP 25 says this delivers nothing and costs
something:** the ranges never appear as annotations (E8, E9: `{t_integer,any}` remains), the tests stay in the code
(19 -> 25 instructions), and the loop is 6% slower on the exported form (E10); on the private form the optimiser
deletes part of them and the time is unchanged (E10), so there is no upside to buy. Specs are inert (E7).
**Strongest counterargument:** OTP 28 may narrow on comparisons (UNVERIFIED; OTP 25 does not, E8), and then this is the
only channel B# has that Erlang cannot match with a `-spec`. That is the ticket's whole "ceiling above Erlang"
argument, and I have no evidence against it on 28 and none for it. **Cost:** an emitter change that alters every
private function's code and the test corpus; not recommended before Option 1 answers whether it can help at all.

## Recommendation

Do **Option 1 now**; it is the only step whose result changes the decision, and it is what ticket §3.2 asked for and
nobody has run on the OTP-28 machine. If it shows annotations are the cause on 28 and comparisons narrow there, re-open
Option 3 with a probe first. Take **Option 2 only when a public hot loop exists**; it is measured safe (E11) but
currently fixes nothing anyone runs. Do not reword the README/ticket as "throws away a range at emission": on OTP 25
the emitter has no way to keep it and the annotation is not what costs time.
Under the "progress" rule in CLAUDE.md this ticket advances nothing until either an exemplar gets faster or the
audition passes more tickets, so it should not displace language work; Option 1 is an hour, not a project.
Independent of the decision: the ticket's "identical bytecode" claim compared instruction lists (26 each); my
comparison after erasing `tr` found one real difference even between two *Erlang* builds (the `+` live-register
count, 2 vs 4), so "identical" should read "identical modulo register liveness".

## What I could not verify here

- **`bsc` output.** Cannot be built (needs OTP 28 leex `TokenLoc`); I did not patch anything. Every emitter-shaped
  case is hand-written Erlang (`probes/loop.erl`). The real `Day01.abstr` may contain something my six variants
  do not (the ticket says instructions match but did not diff `{tr}` by operand for the real output).
- **OTP 25 vs OTP 28.** Different JIT loader, different `beam_ssa_type` (OTP 28 may infer from comparisons; UNVERIFIED),
  different CPU (x86 vs Apple Silicon). A 0.15% result here cannot refute a 20% result there. Also this VM is a shared
  4-vCPU box; the min statistic was stable, medians were not (E13).
- **Whether the JIT consumes `{tr}` at all on OTP 25.** No erts source is installed. Only the negative behavioural fact
  (E4, E5c) is measured. The `ctl_tup` slowdown is instruction-count driven, not attributable to the JIT.
- **Why exported-arg variants are 1.4% faster (E12).** Not investigated.
- **Elixir's and Gleam's range sources.** Elixir 1.14's `.ex` compiler source is not installed (only `ebin`); I show only that
  its output equals Erlang's (E3). **Gleam: not installed, not probed.**
- **The ticket's records/dispatch open axis** (boundary tag guard, ticket 18/F3) is untouched by these probes.

## Probe index

`probes/run.sh` regenerates every `.out` (`./run.sh 300`, ~7 min). Predictions P1-P10 are in its header, written
before the results; contradictions of my own predictions: P2-P9 held; **P6 (no_type_opt slower by 5-25%) was wrong**
(observed +0.15%), P7 (exported slower) wrong (1.4% faster), P10 (wrap within 1%) wrong in direction only (-1.5%).
Files: `loop.erl` (variants), `timing.erl` (interleaved, rotated, GC'd), `types.erl`, `identity.erl` (guards against a
vacuous compare by asserting non-empty streams), `mkabstr.erl`, `ctl.erl`, outputs `versions.out tr_summary.out
instr_identity.out sizes.out elixir_*.out timing.out timing_repeat.out control.out`.
