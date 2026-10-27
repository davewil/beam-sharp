# Ticket 39 (ENG-211) — decision brief: the 20% gap, and what B# owes the BEAM optimizer

**Status: the decision stays OPEN.** Nothing here resolves 39. Run on **OTP 25.3 / Elixir 1.14**, not the pinned
OTP 28.5 (see *Limits*). Every probe is in `probes/`, with its captured `.out` beside it.

## What this session could and could not reproduce

The ticket's number (beam-sharp 1.20x, bare `{x,0}` where Erlang has `{tr,{x,0},{t_integer,{0,99}}}`) is a
**recorded OTP 28 / Apple Silicon claim**. I built a *shimmed* real `bsc` on OTP 25 (`00_build_shim_bsc.sh`: only the
lexer's `TokenLoc` is replaced by `{TokenLine,1}`, so columns are lost; `bs_emit`, `bs_check`, the parser are the repo's
own) and compiled the ticket's own `aoc/bench/Day01`. Rebuilt twice, byte-identical `.abstr`.

**MEASURED here, and it does not match the ticket:**

| claim in ticket | measured on OTP 25.3 | probe |
|---|---|---|
| beam-sharp 1.20x behind Erlang/Elixir | bsc 1.00–1.01x, Erlang 1.07–1.29x, Elixir 1.00–1.23x over 3 runs; order flips | `01` |
| Spin/Wrap carry fewer `{tr,..}` than Erlang's | per-function annotation multisets **equal** for all six functions (`07`); the differ *fires* on a `+no_type_opt` control | `07` |
| 26 identical instructions in Wrap and Spin | Wrap, Hit, Spin, Clicks sequences identical after label normalisation. Sign/Size differ because `bench_bs.bs` writes them as 2 clauses where `bench_erl.erl` has 3 (source difference, 4,732 calls) | `08` |
| `-spec` plays no part | `-spec f(0..99) -> 0..6` leaves the beam **byte-identical in size** (792 B) and the `{tr}` unchanged | `03` c0 vs c1 |

So on OTP 25 there is no annotation gap and no time gap. That does not refute the ticket: it says the cause, if real,
lives in something OTP 28 does differently, or in the machine. It also means **every question below is gated on one
re-run on the pinned toolchain** (`07_tr_diff.sh` with `BSC=…` prints "annotation gap reproduced" or not in seconds).

## Sub-decisions the ticket implies

1. **Is there a gap on the pinned toolchain?** Gating. Nothing else is askable until it is answered.
2. **Does a mandatory signature (ticket 04) discard narrowing?** (ticket §2's "structural reason".)
   *Measured:* no, at the emission level. bsc emits `-spec` but the compiler ignores it (`03` c1), and `Wrap`'s return range
   `-99..99`/`1..199` is re-inferred from the body even though B# declares `int Wrap(int n)` (`07`, `01` asm). The checker's
   declaration never reaches the optimizer, so it cannot be what discards ranges.
3. **Should the checker's proven ranges be emitted, and how?** The only channel the Abstract Format has is code, i.e. guards.
4. **What is the ceiling?** Below.
5. **Records and dispatch** (§4: "never measured"). Measured here, `05`.

## What the optimizer actually consumes (survey, real installed source)

- Erlang `compiler-8.2.6.3/src/beam_ssa_type.erl:18-26` — types are *inferred* from expressions; pass one derives function
  signatures module-wide, pass two optimizes with them. `:629-655` `benefits_from_type_anno`: `{tr,..}` is attached only to
  bifs, `=:=`/`=/=`, calls, map ops, `bs_create_bin`. `:812-` `opt_ranges`: ranges exist for the JIT's `element/2` etc. There is
  no read of the user's `-spec` anywhere (the only `spec` hits are its own function specs: `:78,:424,:471,:743,:812,:2166`).
- `compile.erl:268-283`: `no_type_opt` switches off all three type passes; `:277` shows ranges (`no_ssa_opt_ranges`) arrived as an `r24`-era
  option, so OTP 25 has them and the optimizer is version-sensitive.
- bsc compiles with `[from_abstr, debug_info, …]` only (`bsc.erl:843`).
- Elixir 1.14: sources are not installed (ebin only), so no file:line. Measured only: `BenchEx` times with Erlang (`01`).
- Gleam: **unavailable** (binary download denied by the permission classifier). Elm: JS target, no BEAM analogue; not run.
  So "how neighbours solve it" is: *Erlang and Elixir hand the optimizer nothing and rely on inference; no installed language
  injects a declared type into the BEAM compiler.* I could not check Gleam.

## Two other things measured that bear on the options

**A range guard is not a type channel, on OTP 25.** (`03`, `06`) After `is_integer(N), N >= 0, N =< 99` the operand of
`N + 1` is still `{tr,{x,0},{t_integer,any}}`. `is_integer` *is* carried (`t_integer,any` vs none). bsc already emits exactly that
guard on public refined parameters (`Octets.Next`, `06`: `is_integer andalso >= 0 andalso =< 255`) and the optimizer still sees `any`.
Cost: +20 B for two range tests (792→812 B); `is_integer` alone +4 B.

**A redundant guard is erased; a loop-carried one is not free.** (`04`, two runs, `a2` is a byte-identical control)

| variant of Spin | tests in Spin | min vs plain `a` (noise: control `a2` = +3.2%, +1.3%) | median |
|---|---|---|---|
| `when Left > 0` (the README's accidental guard) | 2 | **+11.1%, +12.7%** | +2.3%, +1.8% |
| `when Pos >= -99, Pos =< 99` (optimizer already knows it) | 1 (elided) | -0.2%, -3.7% | -0.9%, +0.4% |
| `when Zeros >= 0, Zeros =< 1000000` (true, not inferable) | 3 | +3.6%, -1.5% | -0.1%, -1.0% |

An extra compare in the loop is visible at the minimum and hidden in the median; a fact the optimizer already has costs nothing.
The first draft of the last variant used `Pos =< 98`, false at `Pos = 99`; the answer check crashed it, so it was replaced, not tuned.

**§3.2 experiment (strip types from Erlang itself), inconclusive.** (`02`, two saved runs, control `d2` identical to `d`)
`+no_type_opt` removes every `{tr}` (6→0) and var_info (11→0): min vs default **-3.1% and +12.5%** in the two saved runs (control `d2` vs `d`: -2.6%, -4.0%;
an earlier unsaved run read +7%). It was the *fastest* variant once and the slowest once. This VM's identical-code noise (~5% at min, ~25% min/median spread) is too large
to resolve the ticket's 6.14 vs 5.30. **No evidence that stripped annotations cause 20%; none that they do not.**

**Records and dispatch** (`05`, `RecLoop.bs`, a record updated 2,000,000 times in a private `Spin`). Real bsc output carries
the tag test `map_get Kind` + `is_eq_exact` **on a private function** (ticket 59's asymmetry, now seen in asm: two copies, one on the
base-case label and one on the recursive path, `RecLoop.S`). Medians, two runs, controls agree within 3%:
no-tag-test 130/134 ms and 124/129 ms; hand-written Erlang with a tag test 155 and 151 ms (+17–20%); bsc's own 174 and 161 ms.
Minima were unresolvable (identical controls differ 6–17%). Direction consistent, size indicative only.

## The options

**Gating question, asked alone: does the 1.20x gap reproduce with the real `bsc` on OTP 28.5?** Everything below follows
from that answer, so the options are the three things a session can do about 39 now.

### Option A — Re-measure on the pinned toolchain first; change nothing in the compiler

```csharp
// aoc/bench/Day01/bench_bs.bs, unchanged
private int Wrap(int n)
Wrap(n) -> :erlang.rem(:erlang.rem(n, 100) + 100, 100)
```
Compiler delta: **none.** Work: run `01` and `07` with `BSC=compiler/_build/default/bin/bsc` on OTP 28.5; if `07` says "gap
reproduced", diff the `.S` of `Wrap`; if not, re-time with a quieter machine and `a2`-style controls, and close the 20% as
unreproduced.
- Evidence: `07` (equal annotations, self-tested), `01`, `03` c1 (spec ignored), `08`.
- **Strongest counterargument:** the ticket's own numbers were repeated runs on Apple Silicon ("consistently") and the cluster of
  three other languages at ±3% argued the harness was sound. OTP 25 may simply lack the behaviour, in which case this option
  defers a real defect and adds a step without producing a fix.

### Option B — Emit the checker's proven range wherever the optimizer cannot re-derive it

```csharp
type Pos = int where value >= 0 and value <= 99
private int Next(Pos p)           // today: no guard (private); proposal: guard when 99 is narrower than inferred
Next(p) -> (p + 1) rem 100
```
Compiler delta: extend `bs_emit:guard_one/7` (`bs_emit.erl:274`; `int_guard/6` at `:335`) from "exported only" to "private too
when the checker's interval is strictly narrower than what `beam_ssa_type` would infer", which needs an *inference mirror* in
`bs_emit` (a pass computing what OTP derives), plus a gate that the extra tests stay below N bytes.
- Evidence: `06` (the range guard already emitted publicly; operand stays `any` on OTP 25), `03` c3/c4 (+20 B, no `{tr}` gain),
  `04` (a redundant guard is erased, a true-but-unknown one costs 0–4% min, a loop-carried compare +11–13%).
- **Strongest counterargument:** on OTP 25 it buys nothing and costs tests; whether OTP 28's optimizer *does* consume range guards
  is exactly what I could not measure. It also doubles ticket 59's argument (private functions already pay the record tag test).

### Option C — Record the ceiling as "Erlang's own inference", and take the cheap wins that are not about types

```csharp
public (int, int) Run(Rec r)      // RecLoop.bs: a record updated in a private loop
```
Compiler delta: (i) none for ranges: the ticket's §2 thesis (ticket 04 discards narrowing) is replaced by the measured fact
that declarations never reach the compiler; (ii) the one measured emitted cost is the tag test on private functions, a
two-line change in `guard_one/7` (the `none when Public` shape: private → no tag test), *but that is ticket 59 / ENG-241's decision, not this one's*.
- Evidence: `05` (record loop: +17–20% median from the tag test), `03` c1 (spec inert), `07`/`08` (Wrap's wrapper is erased).
- **Strongest counterargument:** `05` is one micro-benchmark with an allocation-dominated loop and noisy minima; a decision to
  drop the private tag test also reopens ticket 59's "a forged record can pass through an exported function" argument, which no
  number here touches. And C leaves the ticket's headline 20% unexplained.

## Recommendation

**Option A, then C's second half through ticket 59.** The gate is one command on the real toolchain, it can produce
a defect worth fixing (a real `{tr}` difference to chase) or retire the number, and it costs no compiler work. Do **not** do B before
`07` runs on 28.5: on OTP 25, range guards are not a type channel, so B's whole payoff is unmeasured. Treat the ceiling claim in
ticket §2's thesis as *not needed to explain anything on OTP 25* (declarations never reach the optimizer, and there is no gap here). The checker itself, where the thesis lives, was not tested.

## Not verified / limits

- **Not the pinned toolchain.** OTP 25.3 (apt), Elixir 1.14. The repo pins OTP 28.5 (`.tool-versions`); `bsc` itself cannot build here (needs OTP 27 `leex`
  `TokenLoc`). The shim loses token columns only; bsc's other behaviours I did not run (checker/diagnostics).
- **Machine noise.** Shared 4-vCPU Xeon, JIT flavour on; identical code differs up to ~5% at min and ~25% min/median.
  Differences under ~10% are not claimed anywhere above.
- **RECORDED, not re-executed:** the ticket's OTP 28 / Apple Silicon table and `{t_integer,{0,99}}` annotation (ticket §1, `aoc/bench/README.md`);
  the fib(100,000) dead heat (not re-run); ticket 59's "+14 bytes" tag-test and ticket 18's `is_integer` +3-5 bytes figures (their `26a`/ticket 18); Gleam (unavailable).
- `05`'s Erlang sides are hand-written equivalents, not bsc output; only the `RecLoop` row is bsc-emitted.
- `-spec` inertness (`03` c1) is the *compiler's* behaviour on OTP 25; `dialyzer` use of the spec is untouched.

## Probe index (all under `probes/`, `08` depends on `07`'s output dir; all scripts hard-code the author's scratchpad paths)

| id | question | hypothesis falsified? |
|---|---|---|
| `00_build_shim_bsc.sh` | build bsc on OTP 25 (lexer shim) | rebuilt; `.abstr` byte-identical |
| `01_bench_day01.sh` | does bsc Day01 trail Erlang/Elixir on OTP 25? | **H1 falsified** (no 1.2x) |
| `02_strip_types.sh` | does stripping `{tr}` slow Erlang ≥10%? | **inconclusive** (noise ≥ effect) |
| `03_carry_ranges.sh` | do spec/guards carry ranges to the optimizer? | spec no; `is_integer` yes; range guard no (OTP 25) |
| `04_guard_cost.sh` | what do guards cost in the hot loop? | loop-carried compare +11–13% min; redundant ≈0 |
| `05_record_dispatch.sh` | what does the private-function tag test cost? | +17–20% median, minima unresolved |
| `06_public_boundary.sh` | does bsc's public range guard reach the optimizer? | no: operand stays `any` (OTP 25) |
| `07_tr_diff.sh` (+`.py`) | does bsc lose `{tr}` vs Erlang? | **H7 falsified on OTP 25**; self-test fires; **re-run on 28.5 first** |
| `08_wrapper_erased.sh` | is bsc's `is_integer` foreign wrapper erased? | yes for Wrap/Hit/Spin/Clicks |


## Verification status
Independently re-run: `verification/VERIFIER.md`. All probes reproduce on OTP 25.3. The shim (lexer columns only) cannot bias emitted code: rewriting every column in `.abstr` left the Code chunk md5 identical. Corrections from the verifier, which supersede the numbers above:
- **No time gap on OTP 25 stands**, measured better by the verifier's interleaved harness (`verification/ilv.erl`, four run orders, byte-identical renamed Erlang copy as control): 0-2.7% spread across Erlang, Elixir and bsc, bsc not slower. The author's own harness spread up to 1.29x on identical-class code, so the '~5% noise at min' above is wrong for it; trust `ilv.erl`, not `bench4`.
- **02** is not just 'inconclusive': `+no_type_opt` was 3-7% slower at min in 3/3 reruns. That is evidence against annotations causing a 20% gap.
- **04**: the verifier measured +5-9% at min (about 0-2% median) for `when Left > 0`, not +11-13%; read the +11-13% as the high end. Redundant and true-but-unknown guards are about 0.
- **05**: the tag test cost +29-32% at min and +16-27% at median over 3 reruns (noise control within 3%), stronger than stated.
- **07** `{tr}` equality is real (the `+no_type_opt` control fires on Wrap, Hit, Spin, Clicks); Sign and Size are 0=0 and uninformative. The ticket's `{0,99}` annotation exists only on OTP 28, so it cannot appear here.
- Citation fix: Wrap's inferred ranges come from the `Day01.S` that `07` builds, not '01 asm'. Absolute beam sizes depend on the build path; only the +20 B and +4 B deltas reproduce.
Recommendation A (re-run 07 and 01 on OTP 28.5, using `ilv.erl` as template) stands.
