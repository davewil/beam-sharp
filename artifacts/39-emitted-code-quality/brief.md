# Decision brief: ticket 39 (ENG-211), emitted-code quality

Ticket not resolved, nothing under `wayfinder/` touched. Every number below comes from a probe in
`probes/` with its `.out` beside it. Machine: 4-vCPU Linux container, x86-64 JIT, OTP 28.0 (erts 16.0).
It was shared with other sessions (load average 11 to 16), so **min** is the column to trust. Medians and
maxima are noise-dominated. Ratios of mins agreed to within 0.5% across every re-run.

## Headline: the ticket's 20% does not reproduce, and its premise is wrong in two places

| Ticket claim | Result here | Probe |
|---|---|---|
| bsc runs ~1.20x slower than Erlang/Elixir | **NOT REPRODUCED.** bsc/Erlang min = **0.99x**: 16.62-16.75 ms vs 16.73-16.83 ms. Two harnesses, 300 interleaved rounds x3, plus the repo's own `bench.erl` x3 | 02 |
| Erlang, Elixir, Gleam cluster within 3% | **NOT REPRODUCED for Gleam.** Gleam is **0.64x**, 10.8 ms vs 16.8 ms. Erlang, Elixir (recompiled on OTP 28) and bsc form the cluster | 02 |
| `Wrap`/`Spin` disassemble identically, 26 instrs each | Reproduces, **including operand types** | 03, 04 |
| Erlang has `{tr,{x,0},{t_integer,{0,99}}}`, bsc has a bare `{x,0}` | **NOT REPRODUCED.** bsc's `Spin` and `Wrap` carry the same `{tr,...}` ranges, 7 `tr` operands vs Erlang's 8. The extra Erlang one is in `sign`, which is written differently | 03, 04 |
| `-spec` is not the cause | Reproduces: instructions identical with and without the 7 specs, times equal (16.84 vs 16.83 ms) | 10 |
| Gap lives in `Spin` | Moot. A single 673,364-click `Spin` takes the same time as the whole fold, so `Spin` is all of the cost, but there is no gap | 05 |
| Same machine code | **x86 JIT assembly for `Spin` and `Wrap` is identical** (diff = one callee-name case, `Hit` vs `hit`) | 14 |

So there is nothing on x86-64/OTP 28.0 to attribute. The ticket's numbers were Apple Silicon (arm64 JIT),
erts 16.4 and Gleam 1.18.1. I cannot run any of those here. `git log` is truncated to 51 commits starting
2026-09-29, so the compiler of 2026-08-15 cannot be rebuilt either. Treat the 20% as **unreproduced on a
second machine, not disproved on the first**. Do not resolve the ticket on the claim "bsc is slower".

## Sub-decisions the ticket implies

1. **Cause attribution.** What explains the gap? Here it does not exist (probes 02, 14).
2. **Is the missing `{tr}` annotation the cause (§3.2)?** No. Stripping annotations from hand-written Erlang
   changes nothing (probe 06). Stripping them from bsc costs +3.5 to 4.4%, but because bsc's two FFI
   `is_integer` guards then survive, not because `tr` is absent (probe 15).
3. **Should `bs_emit` carry interval facts to the JIT, and how (§3.3)?** The Abstract Format has one
   channel, **guards and tests**. `-spec` is not a channel. bsc already uses the channel for refined
   parameters and refined FFI returns.
4. **Does spec widening (ticket 13) matter for speed?** No (probes 08, 10).
5. **What is the ceiling claim (§2)?** "B# knows more than Erlang, so it should be ahead" is not supported.
   The real lever is an optimiser flag (`inline`), not a type fact.

## Evidence the ticket's §2 premise is wrong

- **B# does not know `Wrap` returns 0..99.** `private Dial Wrap(int n)` with the `rem` body is *refused*:
  `not covered by the declared return type: int <= -1 | int >= 100` (probe 11a). `d + 1` under `d < 99`
  is refused for `Dial` too (11b). The checker's intervals live in patterns, refinements and residuals. They
  do **not** flow through FFI results or arithmetic. "beam-sharp knows the same fact in a stronger form"
  is false for this program.
- **Nothing is thrown away at the emission boundary, because nothing declarative is emitted that OTP
  would read.** `beam_core_to_ssa.erl:196` has `include_attribute(spec) -> false`. The spec reaches Core
  (6 matches in `lib08.core`) and is dropped before `beam_ssa_type` runs (probe 08). OTP's analyser infers
  `0..99` from the body regardless of what B# declares. Ticket 04's "mandatory signature discards the
  range" tension is therefore moot for the middle end.
- **Ranges B# does know already reach the JIT, through guards.** An exported `Dial` parameter lowers to
  `is_integer, >=0, =<99`. A refined FFI return lowers to the same guard on the result (probes 11c, 18).
  Then:
  - OTP's `arg_types` propagation (`beam_ssa_type.erl:424-440`: local functions get the join of call-site
    types, exported ones get `any`) gives the **private** callee `Next` `{tr,{x,0},{t_integer,{0,99}}}`
    with no guard of its own.
  - The JIT acts on it: the guarded add shows `# add without overflow check`, and `is_integer + >= + =<`
    fuses into one `is_int_in_range` (probe 08, `+JDdump`). Source: `beam_jit_common.hpp:267-279`
    `always_small` needs both bounds, and `x86/instr_arith.cpp:191` is the "add without overflow check" path.
- **Ticket 18's FFI guard is free only because the analyser proves it away.** With `+no_type_opt`, bsc's
  `Wrap` keeps two `is_integer` tests (12 instrs vs Erlang's 8) and runs +3.5 to 4.4% slower (probe 15).
  That is a hidden dependency of the 18 design on `beam_ssa_type` running. It is also where a 3% gap
  would come from if the ticket-time bsc ever emitted its FFI result guard in a form the analyser could not
  fold. I could not confirm that.

## The measured lever: `inline` (what Gleam is doing)

Gleam's own output carries `-compile([no_auto_import, ..., inline])` (`probes/16_gleam_generated.erl:2`).
`wrap` and `hit` are inlined into `spin`, so `Spin` has no frame (25 instrs, 0 `allocate`, 1 call). That, not
types, is why Gleam is 36% faster on this machine. Elixir's forms carry only `compile no_auto_import`
(`work/ex_forms.term:3`) and Erlang has no default inlining.

Giving **bsc's own `.abstr`** one extra form does the same (probes 07, 12), with identical answers:

| variant (min ms, 3 runs x100 interleaved rounds) | ms | vs default |
|---|---|---|
| bsc default | 16.67 / 16.73 / 16.72 | 1.00 |
| bsc `+inline` | 10.75 / 10.63 / 10.42 | **0.63** |
| bsc `{inline,[{'Wrap',1},{'Hit',1}]}` | 10.83 / 10.80 / 10.79 | 0.65 |
| Erlang `+inline` | 10.77 / 10.80 / 10.77 | 0.64 |
| Gleam 1.12 | 10.79 / 10.78 / 10.81 | 0.65 |

## Options

### Option A: close with the baseline retracted, change nothing in the emitter

```
// no B# change. Day01 as written; bsc output already matches Erlang's instructions, tr operands and x86 JIT code.
```
Delta: **zero emitter work.** Write the decision as "no emission-quality gap on x86/OTP 28.0, ranges reach the
JIT through boundary guards, `-spec` is not a speed channel". Keep `aoc/bench` as the harness. Evidence:
probes 02, 03, 04, 10, 11, 14, 18.

Strongest counterargument: the ticket's numbers came from the author's machine, and one container is one data
point. Closing this way risks burying a real arm64 regression. Gleam being 36% faster than everything else
here is itself unexplained across machines (the ticket saw 3%). A closed ticket stops anyone re-running on
Apple Silicon.

### Option B: emit `inline` for a computed set of private helpers

```
private int Wrap(int n)        // small, non-recursive, private
private int Hit(int pos)
private (int,int) Spin(...)    // self-recursive: NOT listed
```
Compiler delta, concrete:
- a pass over the symbol table that selects private, non-recursive, small functions. Recursion needs a call
  graph, which the checker has to build for termination or reachability already;
- one emitted form in `bs_emit:forms/1`: `{attribute, 0, compile, {inline, [{'Wrap',1},{'Hit',1}]}}`. I
  tested exactly this form on the real `.abstr` (probe 12) and it matches `+inline`;
- a `bsc` option or `.bs` pragma to turn it off;
- the same case on `inline_size`, which defaults to 24 (`compile.erl:112-115`).

Evidence: 0.63 to 0.65x on the benchmark (probes 07, 12). Cost on the 22-module examples corpus: +0.9% BEAM
bytes (27,400 to 27,656; probe 12). Compile-time change is below noise and the wall time is dominated by `erlc`
VM start, so that comparison is **inconclusive** (probes 12, 16).

Strongest counterargument, from ticket 13's own tooling promises:
- `compile.erl:77-90`: "exceptions are reported as occurring in the function the body was inlined into", and
  "inlining does not necessarily improve running time... can increase stack use".
- Measured: an inlined `div` by zero **drops the callee's stack frame** (probe 13: `trace13:boom` vanishes).
- A `function_clause` from an inlined multi-clause helper keeps its class here, but the frame becomes
  `'-inlined-f/1-'`. The documented conversion to `case_clause` did **not** occur on OTP 28.0 (probe 17).
- The compiler's tests mention `function_clause` 29 times across the test files. None of those was run under inlining,
  so I do not know which assert on frame names.
- It is one microbenchmark of tiny helpers on one architecture.

### Option C: make the checker propagate intervals through arithmetic and FFI, then lean on the existing guards

```
private Dial Wrap(int n)
Wrap(n) -> :erlang.rem(:erlang.rem(n, 100) + 100, 100)   // today refused; would be accepted
```
Delta: interval transfer functions in `bs_check`/`bs_types` for `+ - *` and FFI-declared BIFs with known result
ranges (`rem`, `band`), i.e. Ticket 20's algebra extended from patterns to expressions, plus whichever emitted
guard keeps the range visible. The guard-emission half already exists (probe 18).

Evidence for value is thin: **0%** on the AoC loop, where OTP already infers the ranges (probes 03, 14).
**3 to 5%** on a synthetic loop whose callee is opaque, comparing `plain` / `is_integer` / `is_integer + range`
(mins 50.1-52.7 / 50.6-51.2 / 48.4-49.2 ms; probe 09, three runs, direction consistent, size close to
noise).

Strongest counterargument: this is language work (a new checker feature and a new refusal-to-acceptance
boundary) justified by a single synthetic 4% that exists only when the callee is opaque. CLAUDE.md says
features raise tickets rather than make decisions, so this belongs in its own ticket, not here.

## Recommendation

**Option A for the ticket, with the Option B experiment raised as its own feature ticket.** In order:

1. Resolve 39 as: the 20% did not reproduce on x86-64/OTP 28.0; instruction, `tr` operand and JIT code are
   identical to Erlang; spec is not a speed channel (compiler drops it at `beam_core_to_ssa.erl:196`);
   B# intervals reach the JIT through boundary guards. State the arm64 and OTP 28.4 numbers as unreproduced,
   not refuted.
2. Retire §2's framing ("beam-sharp knows more and throws it away"). The checker does not derive 0..99 for
   this program (probe 11a, 11b).
3. Raise one new ticket from the same data: **should bsc emit `inline`?** It is the only lever measured above
   noise (-35%), and its price is stack-trace legibility (probes 13, 17), which tickets 13 and 14 sell. It
   is a decision for David, as a program that compiles and a crash that reads differently.
4. If anyone has Apple Silicon, re-run `aoc/bench` with `probes/bench2.erl` before resolving. That is the
   only way to reproduce or kill the original number.

## Claims not reproduced / caveats

- **The 20% gap itself. Not reproduced** (probe 02). The `{tr}` absence in bsc's `Spin`: **not reproduced** (probe 03).
- **Gleam 1.12.0 here, 1.18.1 in the ticket.** Gleam's 36% lead is `inline` in 1.12's generated Erlang
  (`16_gleam_generated.erl:2`). Whether 1.18.1 still emits it, or whether arm64 hides the benefit, is
  unknown. The ticket's Gleam ratio (1.00 vs Erlang 1.03) is inconsistent with this machine.
- **Gleam project built dependency-free.** The repo's `gleam.toml` needs `gleam_stdlib` from hex (offline). The
  source uses only the prelude, so I built a copy without the dependency (probe 00). Nothing in the repo changed.
- **Elixir 1.14.0, not 1.19.5, and it cannot run on OTP 28** (`bs_add` load error). I extracted Elixir's Erlang
  forms on OTP 25 and recompiled them with the OTP 28 compiler (probe 01). That measures Elixir's *generated
  code* on OTP 28, not Elixir 1.19.5. It equals Erlang (0.99x), same as the ticket's cluster.
- **OTP 28.0 (compiler 9.0), not 28.4.** The `{tr}` behaviour may differ in 28.4. I read the 28.0 sources
  and JIT source in `/tmp/tc/otp_src_28.0`.
- **x86-64 JIT only.** The arm JIT source exists (`jit/arm/instr_arith.cpp`) but I did not run or compare it.
- **Load.** The container ran at load 11 to 16, which makes medians and maxima unreliable. The ratios of mins
  held within 0.5%. The 3 to 5% results (probes 09, 15) are the size where I would want a quiet machine.
- **Compile time is inconclusive.** `erlc`/`bsc` wall includes ~250 ms of VM boot (probe 16). I did not isolate
  per-module compile cost, and the corpus is 22 small modules.
- **Not measured:** records and dispatch (ticket §3.4 remainder, ticket 18 F3 tag guard), `fib(100,000)`
  dead heat (not re-run), whether `inline` helps any program besides `Day01`, and Elm (a JS target with no
  analogue of this question, so not surveyed).
- **Benchmark source asymmetry.** `bench_erl.erl` `sign/size_` are written differently from the B#
  `Sign/Size` (13 vs 10 instrs and 10 vs 9; probe 04). They run once per rotation, not per click, so they do not
  move the number, but the "identical" claim holds only for `Wrap`, `Hit`, `Spin`, `Clicks`, `PartTwo`.
- `bsc` adds one function to every module, `bs@type_atoms/0` (6 instrs), and compiles with `debug_info`, which is
  why `Day01.beam` is 2,332 bytes against `bench_erl.beam` at 1,320 bytes (probes 04, 16).

## Probe index

| Probe | Claim tested | Result |
|---|---|---|
| `00_build` | build all four on OTP 28 | ok (Gleam dep-free copy; Elixir via 01) |
| `01_elixir_forms` | Elixir forms recompilable on OTP 28 | ok, 13 forms |
| `02_reproduce_gap` | bsc ~1.20x slower | **no**: 0.99x (min), Gleam 0.64x |
| `03_disasm` | identical instrs; bsc lacks `tr` | identical; **`tr` present in bsc** |
| `04_instr_diff` | normalised diff erl vs bsc | identical except `sign`/`size_` source differences |
| `05_spin_isolation` | gap in `Spin`? | `Spin` = whole cost; no gap |
| `06_strip_annotations` | do `tr` annotations cause speed (§3.2) | Erlang: no (0 to 1.4%); bsc: +3.2% (see 15) |
| `07_inline_lever` | what makes Gleam fast | `inline`: 0.63 to 0.65x for Erlang, bsc and Gleam alike |
| `08_range_in_abstract_format` | does the optimiser read specs? do guards carry ranges? | spec ignored (`beam_core_to_ssa.erl:196`); guard gives `{0,99}`, `is_int_in_range`, "add without overflow check" |
| `09_guard_cost_benefit` | payoff of the range guard | -3 to -5% in an opaque-callee loop; near noise |
| `10_spec_strip` | spec not the cause | confirmed |
| `11_does_bsharp_know_the_range` | B# derives 0..99 / carries it through `+` | **no**; refined params get boundary guards, private callee inherits `tr` |
| `12_inline_attr_and_cost` | attribute form works; corpus cost | works; +0.9% bytes; compile time inconclusive |
| `13_inline_stacktrace` | inlining changes crash reports | callee frame dropped for `badarith` |
| `14_jit_asm_diff` | same machine code | `Spin`/`Wrap` identical (4 diff lines, names only) |
| `15_no_type_opt_residue` | why bsc is slower without `type_opt` | the 2 retained FFI `is_integer` guards; +3.5 to 4.4% |
| `16_neighbours_and_compile_time` | Gleam/Elixir flags, sizes, compile time | Gleam emits `inline`; Elixir doesn't; times inconclusive |
| `17_inline_error_class` | `function_clause` becomes `case_clause` | **not on OTP 28.0**; frame name `-inlined-f/1-` |
| `18_ffi_refined_return` | refined FFI return emits range guard | yes; JIT gets `{0,99}` |

Support files: `probes/env.sh`, `probes/bench2.erl` (interleaved harness), `probes/src/*`, `probes/16_gleam_generated.erl`.
Build outputs are under `work/`.
