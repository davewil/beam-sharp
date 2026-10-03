# Decision brief: ticket 39 / ENG-211 — emitted-code quality

Prepared for David. Ticket NOT resolved; nothing outside `artifacts/` was touched.
Every number is from a probe in `artifacts/probes/39/` (index at the end). Environment: **OTP 29 / erts-17.1,
Elixir 1.20.4, Gleam 1.18.1, Intel Xeon 2.8 GHz x86_64, JIT on** — not the ticket's OTP 28 / Apple Silicon.

## Headline: the ticket's premise does not reproduce, and two of its three "facts" are false here

| Ticket claim | Status on this machine | Probe |
|---|---|---|
| beam-sharp is ~20% slower than Erlang | **NOT REPRODUCED.** beam-sharp 17.0 ms, Erlang 17.2 ms median: 0.99x, inside the IQR | 01 |
| Erlang's loop has `{tr,..,{0,99}}`, beam-sharp's has bare `{x,0}` | **FALSE on OTP 29.** `Spin/4` is identical in all 27 instructions, `{tr}` and `var_info` included; the `.beam` `Type` chunk is **byte-identical** | 02, 03 |
| `-spec` is not the cause | **CONFIRMED.** Spec stripped, or narrowed to `0..99`: same asm, 1.00x / 0.99x | 04 |
| beam-sharp "knows 0..99 in a stronger form" and throws it away | **FALSE.** `bs_check` has no interval arithmetic: `op_type('%') -> int()` (`compiler/src/bs_check.erl:4138-4140`). `Digit Wrap(int n)` over the benchmark's body is **rejected**: `not covered by the declared return type: int <= -1 \| int >= 100` | 06 |
| Mandatory signature discards the range | **Not the mechanism.** The optimiser never reads a declaration (see Q3). B# lacks the range for a different reason: it never synthesised one | 04, 06 |
| Annotations *cause* the gap (§3.2 experiment) | Ran it. Erlang compiled `+no_type_opt` (every `{tr}` gone): **1.00x**. beam-sharp `+no_type_opt`: 1.02-1.04x. Annotations are worth <=4% on this loop | 04 |

**The thing that does move this loop is not type information. It is inlining.** Gleam's generated Erlang opens with
`-compile([no_auto_import, ..., inline])` (`01-rerun/build/gleam/build/dev/erlang/bench_gleam/_gleam_artefacts/bench_gleam.erl:2`).
Gleam runs at **0.64x** of Erlang here. Remove `inline` from Gleam's own output and it falls to 1.00x. Add
`-compile(inline)` to Erlang's source and it is 0.64x; add it to beam-sharp's emitted forms and it is 0.64x (probe 04).
In the ticket's own table Gleam was only 3% ahead of Erlang; **why is unexplained here** (UNMEASURED, see Limits).

## 1. The questions the ticket implies, gating one first

1. **(Gating) Is there a gap on the target to close?** Here: no. Everything below is conditional on re-measuring on
   OTP 28 / arm64, which this environment cannot do. Nothing is built on a gap that has not been seen twice.
2. May `bs_emit` carry compile *directives* the author did not write (`-compile(inline)`)? Gated by 1 only for
   motivation: the 36% win exists on any machine where calls cost something.
3. Does the optimiser read B#'s declared signature (so a mandatory signature could "discard" ranges)? **No** (below).
4. May `bs_emit` carry *interval facts* to the optimiser? Gated by 5.
5. Should `bs_check` synthesise intervals for arithmetic (`rem`, `+`)? Without it there are no facts to carry.
6. What is the ceiling? Measured below: inlining, not intervals.

Q3 evidence: `beam_ssa_type.erl:444-451` types a local function's parameters from the join of its call sites and
gives exported ones `any`; nothing in it consumes a `-spec`. Measured: `b1_bs_no_specs` and `b4_bs_narrow_spec` have the
same 70 instructions and 9 `{tr}` annotations as `b0_bs_as_is` (`04-variants/types.out`). The declaration is not "the
answer"; the optimiser infers from the body regardless, exactly as for Erlang.

## 2. What the forms can and cannot carry (probes 04, 05, 06)

| Channel | Carries a range into `beam_ssa_type`? | Cost | Measured |
|---|---|---|---|
| `-spec` (ticket 13's widened spec) | No | none | `b4`: identical asm, 0.99x |
| Guard in the forms (`when R >= 0, R =< 99`) | Yes: `Spin`'s `x0` became `{0,99}` (was `{-99,99}`) | two extra tests per call | `b5_bs_guard_fact`: **1.05x slower**. Only worth it if the guard is the contract anyway |
| Exported refined parameter (F37 already emits it) | Yes: `Twice(Digit)` -> `{tr,{x,0},{t_integer,{0,99}}}`; `Plain(int)` -> `{t_integer,any}` | the contract test, already shipped | `06-bs-range/run.out` |
| `-compile(inline)` / `{inline,[F/A]}` | Yes, by exposing the callee: after inlining `Wrap`, `Spin` carries `{tr,{x,0},{t_integer,{0,99}}}` (rem of a `>=0` range gives `0..99`, `beam_bounds.erl:316-322`) | code size | `b3`: **0.64x** |
| `erlc +from_asm` `{var_info,..}` / `{tr,..}` | Yes, **unverified**: `beam_validator.erl:1190-1195` `meet`s a claimed type "inserted by optimization passes" without proving it. A *lie* (`step` claimed `{1,1}`, truly `-1\|1`) was accepted by erlc | none | `a1` true fact 1.00x (no gain on this loop); `a2` lie accepted, same answer |

So the answer to ticket §3.3 is: the Abstract Format can carry ranges only as runtime tests or via the inliner. It cannot
carry them for free. The free channel (`from_asm`) exists but is a *claim* the validator trusts, and it buys nothing
measurable on this loop. A lie there is only caught by B#'s own proof.

## 3. Neighbours (quoted from sources I opened)

- **Gleam** ships `inline` in every module's `-compile` attribute (generated file above, line 2); its `.S` has `Wrap`
  and `Hit` gone (`02-asm/work/gleam.S`: functions `spin clicks part_two` only). It does no range work of its own.
- **Elixir 1.20.4** compiles via Core Erlang: `module_info(compile)` options are
  `[no_spawn_compiler_process,from_core,no_core_prepare,no_auto_import]` (`07-inline/run.out` section 2). No inline.
  Its `Spin` matches Erlang's instruction for instruction (`02-asm/run.out`), timing 0.99x. Elixir's source is not
  installed, so I cannot cite its compiler lines.
- **Erlang** (`compile.erl:89-90`): "Inlining is never default. It must be explicitly enabled", and
  `compile.erl:85-87` warns it "does not necessarily improve running time" and can hurt recursive functions.
- **OTP's own type facts**: `beam_ssa_type` infers from bodies and guards (`infer_relop`, `beam_ssa_type.erl:2729-2733`);
  `no_type_opt` (`compile.erl:1185-1191`) is the sanctioned way to strip them.
- Elm is installed but targets JS; not surveyed.

## 4. Options

### Option A — withdraw the premise; change nothing in the emitter

```csharp
private int Wrap(int n)
Wrap(n) -> :erlang.rem(:erlang.rem(n, 100) + 100, 100)   // unchanged
```
Compiler delta: none. Re-run `aoc/bench/` on OTP 28 / arm64 before touching the ticket again.
Evidence: 0.99x here; `.beam` identical in the parts the JIT reads (probe 03).
**Strongest counterargument:** it leaves a measured 36% on the table against Gleam, on exactly the code the ticket
says is "the emitted loop"; and the cause of the ticket's own 20% is then simply unexplained.

### Option B — emit `-compile({inline,[...]})` for small private functions (recommended)

```csharp
private int Wrap(int n)      // unchanged B#; bsc emits  -compile({inline,[{'Wrap',1},{'Hit',1}]}).
Wrap(n) -> :erlang.rem(:erlang.rem(n, 100) + 100, 100)
```
Compiler delta, concrete: (1) a pass in `bs_emit:forms/1` (next to the export attribute, ~`bs_emit.erl:74`) that lists
private, non-recursive functions under a size bound and emits one `{attribute,?A,compile,{inline,Names}}`; (2) one
new test over `Day01`: the `.beam`'s function list lacks `Wrap/1` and `Hit/1`. Blanket `inline` is the same one-line
delta (Gleam's choice) without the pass.
Evidence (probe 07, 3 x 40 rotated runs, medians vs Erlang): none 0.98-1.02x; `Wrap` only 0.68-0.72x;
`Hit` only 0.58-0.61x; both 0.63-0.65x; blanket `inline` 0.63-0.65x; `inline`+`{inline_size,100}` 0.56-0.57x.
Size: `.beam` 2168 B -> 2064 B (blanket). Across the 22 example modules the total is -0.4% (`Pipeline` -13.5%,
`Stats` +9.1%, `Names` +6.6%, 17 unchanged; probe 08).
**Strongest counterargument:** inlining changes what a failing program looks like. In probe 07 section 3 a crash in a
private `f/1` keeps `function_clause`, but the stack loses the `go/1` frame and gains `'-inlined-f/1-'`. B# promises
`function_clause` at the exported boundary (F37) and relies on tracebacks. A private callee that cannot fail
(exhaustive by construction) is safe; one reached through an FFI try-wrapper (F19/F42) needs checking. **Unmeasured:**
the runtime effect on any program other than this loop, and compile time (probe 08 times were noise-dominated, +/-30%).

### Option C — make B# carry interval facts (synthesise, then emit)

```csharp
type Digit = int where value >= 0 and value <= 99
private Digit Wrap(int n)          // today: rejected, int <= -1 | int >= 100 uncovered
Wrap(n) -> :erlang.rem(:erlang.rem(n, 100) + 100, 100)
```
Compiler delta: interval transfer functions for `+ - * rem div` in `bs_check` `op_type/1` (`bs_check.erl:4135-4140`);
then either guards in the emitted forms (cost measured: 1.05x) or `from_asm` (unverified channel, breaks the
"`.abstr` plus external `erlc` always works" obligation in `compiler/README.md`).
Evidence: the only way that costs nothing at run time bought 1.00x (`a1_true_fact`).
**Strongest counterargument:** it is the ticket's own thesis (beam-sharp should out-type Erlang) and it is the only
option that makes `Digit Wrap(int n)` writable. My probes find no runtime payoff, but they test one loop, and a payoff
would show on code where the JIT elides bignum overflow or tag checks that this loop does not need. UNMEASURED.

## 5. Recommendation

1. **Withdraw §1-§2 of the ticket as written.** The gap is absent, the `{tr}` claim is false on OTP 29, and the
   "stronger range" claim is false because the checker does not synthesise intervals. Say that plainly in the ticket.
2. **Take Option B, selective rather than blanket**, because it is the only lever with a measured effect, it needs
   no B# source change, and it is a single attribute. Do it only after (a) re-measuring Option A's baseline on the
   OTP 28 / arm64 machine and (b) deciding the traceback question in the counterargument, as a program that crashes
   inside an inlined private function and what the caller sees.
3. **Park Option C** until a workload shows a type fact is worth something. Ticket 20 owns the arithmetic-interval
   question and should be asked it alone: "does `a % 100` have type `-99..99`?"
4. Ask David the gating question alone: **"Is a private B# function allowed to disappear from the `.beam`?"** It is
   the same question as whether the stack frame is part of the language.

## Limits (UNMEASURED, or where the environment differs)

- **OTP 29 / x86_64 Xeon, not OTP 28 / Apple Silicon.** The ticket's gap, and the bare-`{x,0}` observation, may be
  real there. UNMEASURED. Absolute times are ~3x the ticket's (17 ms vs 5-6 ms): this is a slower, probably virtualised
  machine; ratios, not milliseconds, are the comparable quantity.
- Why Gleam was only 3% ahead in the ticket despite shipping `inline`: UNMEASURED (the repo's history is 50 commits and
  does not show how `bsc` built the `.beam` on 2026-08-15, so a different pipeline then cannot be ruled out).
- `bsc` was built by hand (rebar3 is broken on OTP 29); Gleam's unused `gleam_stdlib` dependency was dropped from a
  *copy* of `gleam.toml` because hex.pm is unreachable. Neither affects the emitted loop.
- Ticket §3.1 (time `Spin` alone) is moot: there is no gap to localise. §3.4 records/dispatch (the F3 tag guard) is
  still unmeasured, as is `fib`-style GC-bound code on this machine.
- Option B/C runtime effects beyond Day01: UNMEASURED. Compile-time effect of inlining: UNMEASURED (noise).
- The `from_asm` lie was accepted and changed nothing observable; I did not construct a lie that crashes the VM.
- `compile.erl` says inlining converts `function_clause` to `case_clause`; my one probe kept `function_clause`.
  I report what ran, not what the manual says; other shapes are UNMEASURED.
- Elixir compiler source is not installed; Elixir claims rest on its `.beam` and `module_info` only.

## Evidence index (all under `artifacts/probes/39/`; each has `run.sh` and a captured `.out`)

| Claim | Probe |
|---|---|
| 4 languages re-measured: Erlang 17.2, Elixir 17.0, beam-sharp 17.0, Gleam 11.0 ms medians; IQR 0.2-1.3 ms; 3 x 60 rotated runs plus the repo harness x3 | `01-rerun/run.out` |
| `{tr}` counts, `Spin` listings, function lists per front end | `02-asm/run.out` |
| Normalised asm identical for `wrap hit spin clicks part_two`; `Type` chunk byte-identical; `sign`/`size` differ by source only | `03-equivalence/run.out` |
| Spec stripped / narrowed / `no_type_opt` / inline / guard-fact variants, 3 x 40 runs; `.beam` size, `{tr}` and instruction counts | `04-variants/run.out`, `types.out` |
| `from_asm` accepts true fact and lie; timing unchanged | `05-from-asm/run.out` |
| `bs_check` has no arithmetic intervals; `Digit Wrap` rejected; F37 boundary guard gives `{0,99}` | `06-bs-range/run.out` |
| Selective vs blanket inline; shipped compile options per language; crash shape under inline | `07-inline/run.out` |
| Inline across 22 example modules: size and compile time | `08-corpus/run.out` |
| OTP source citations: `beam_ssa_type.erl:444-451, 2729-2733`; `beam_validator.erl:1190-1195`; `beam_bounds.erl:316-322`; `compile.erl:85-90, 1185-1191` | `/tmp/otp/lib/erlang/lib/compiler-10.0.6/src/` (read directly) |

## Verifier findings (independent re-run, see probes/39/VERIFY.md)

Central claims REPRODUCED: no gap on OTP 29/x86_64, identical Spin/4 asm and Type chunk, spec
irrelevant, `no_type_opt` costs ~1-4%, inlining ~0.64x, option B ratios.

**Probe 05 (`from_asm` fact injection) is CIRCULAR and its rows are withdrawn.** Its `var_info`
edits leave the Type chunk byte-identical, so "lie accepted, same answer" and "true fact 1.00x"
were guaranteed by construction; the fixtures also keep a stale module atom in `func_info`. A
`{tr}` edit does change the Type chunk (verifier builds c1/c2), so whether the optimiser trusts
injected facts is **UNMEASURED**. This weakens only Option C's evidence (already parked); the
Option B recommendation does not depend on it. A few compile.erl line citations are off by 1-3.
