# Brief for ticket 39 (ENG-211): why is instruction-identical code slower, and what is the ceiling?

Decision brief only. Nothing under `wayfinder/` or `compiler/` was touched. Probes: `artifacts/probes/39/`
(`bash artifacts/probes/39/run.sh`, ~3 min, exits non-zero if any observation fails; last output in `results.txt`).

## 1. Question and the gating sub-decision

The ticket asks for a cause and a ceiling. Its working hypothesis is that `bs_emit` throws away interval
facts at the emission boundary, so the JIT sees a bare `{x,0}` where Erlang has `{tr,{x,0},{t_integer,{0,99}}}`.
**On OTP 25 / x86-64 JIT that hypothesis did not survive the ticket's own §3.2 experiment** (annotations
stripped, 0.98-0.99x of baseline, i.e. noise), and **the one lever that moved the hot loop was not type
information at all: `-compile(inline)`** (1.14x faster, and it is exactly what Gleam emits). Nothing here
reproduces beam-sharp's reported 20%: `bsc` cannot run in this sandbox.

**Gating question, asked alone: may `bs_emit` emit optimiser directives (a `compile` attribute), or is the
emitted module deliberately directive-free?** Today it is directive-free: the module has only `module`, `export`,
`behaviour`, `type`, `file` and `spec` attributes (`compiler/src/bs_emit.erl:74-97`; `grep 'attribute, ?A, compile'`
finds nothing). Whether to emit range-carrying guards, narrower specs, or to reconsider ticket 04's mandatory
signatures all *follow* from this answer, because the measurements below show those three levers are null or
negative on this toolchain, so they have nothing to be decided about until a lever exists that works.

Follows from it (not briefed): which functions get inlined (all private / author-marked / size-limited);
whether guards should ever carry intervals (measured: no); the ticket-04 "tension" (measured: absent at the BEAM level).

## 2. Evidence

| claim | probe / citation | result | status |
|---|---|---|---|
| This host is a JIT VM | `run.sh` header | `OTP 25 erts-13.2.2.5 flavor=jit x86_64`, Elixir 1.14.0 | measured here |
| The hot loop is where the time is (ticket §3.1) | `bench.erl` `spin_only/1` vs `part_two/1` | spin-only 8.88 ms vs full 9.03 ms (plain Erlang): ~98% of the run | measured here |
| `bsc` build path loses nothing in `wrap/hit/spin` | `pipe.escript` replays `bsc.erl:833-846` (all annotations 0, `~p` `.abstr`, `from_abstr`+`debug_info`) on hand-written forms | asm of `wrap`, `hit`, `spin` incl. `{tr,..}` byte-identical to plain `erlc` | measured here (forms hand-written, not bsc output) |
| `erlang:rem` remote call = `rem` operator | `v_remote.erl` | identical asm (`bs_emit.erl:1045`: `e_op` is a plain `{op,..}`; foreign call is `{call,{remote,erlang,rem}}`, `:1120`) | measured here |
| `-spec` (wide or narrow) is invisible to the optimiser | `v_spec.erl`, `v_narrowspec.erl` (`-spec wrap(integer()) -> 0..99`, `spin(0..99,-1..1,0..2^27-1,..)`) | asm identical to no-spec; time 0.998-1.00x | measured here |
| Ticket's refutation of the spec holds | same | 6.51 vs 6.54 ms cited by ticket; here 1.00x | measured here (agrees) |
| Stripping `{tr,..}` from spin does not slow it (ticket §3.2 causation test) | `v_noanno.erl` (`spin/4` exported, so arg types unknowable: asm shows bare `[{x,0},{x,1}]` exactly as ticket reports for beam-sharp) | 0.984-0.992x of baseline (noise); with inlining 0.989-1.000x | measured here; **contradicts the ticket's mechanism on OTP 25** |
| bs_emit return-guard (`case rem(..) of V when is_integer(V) -> V end`) is free without inlining | `v_retguard.erl` from `bs_emit.erl:1120-1131, 1241-1247, 1282-1283` | asm of wrap/hit/spin identical, time 0.999-1.009x | measured here |
| That return guard did not exist when the ticket was written | `compiler/features/F42-...md` Status "done 2026-09-11", F52 "done 2026-09-19"; ticket raised 2026-08-15 | the 20% measured a `bsc` that emitted no guard on `:erlang.rem` | cited (repo history is squashed, no git log to confirm) |
| Range guards do **not** hand the optimiser an interval | `v_guard.erl` (`Left >= 0, Left =< 16#7FFFFFF` etc.) | operand still `{tr,{y,2},{t_integer,any}}`; 6+ extra `is_ge` tests per iteration; time 1.01-1.03x (slower) | measured here (OTP 25; relop narrowing may exist in 28: not verified) |
| Optimiser infers `wrap/1`'s return from the body regardless of spec | `var_info {x,0} {t_integer,{-99,99}}` after `call wrap/1` in `v_spec`, `v_narrowspec` | present with `integer()` spec | measured here |
| `-compile(inline)` explains a 13% gap | `v_inline.erl`, `v_inline_bsc` | 1.136x faster than plain (min over 60 rounds); asm: `wrap`/`hit` folded into `spin`, `{tr,{x,0},{t_integer,{0,99}}}` appears on the `hit` compare | measured here |
| Gleam emits `inline`, Erlang/Elixir do not | generated `gleam/build/.../bench_gleam.erl` line 2: `-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline])`; Elixir `module_info(compile)` options `[no_spawn_compiler_process,from_core,no_core_prepare,no_auto_import]` | Gleam == Erlang+inline (0.999x), Elixir == Erlang (0.998x) | measured here |
| bs_emit's return guard defeats the default inliner | `v_rginline_bsc`: spin still contains `call wrap/1`; `v_inline_bsc` does not | guarded+inline 1.02x slower than plain inline (borderline, >=2% in 4 runs, not asserted) | measured here |
| An explicit `{inline,[{wrap,1},{hit,1}]}` inlines the guarded `wrap` | `v_rgexplicit.erl` | spin has no `call wrap/1`; 1.003x of plain inline | measured here |
| Inlining removes helper frames from stack traces | `st_plain.erl`/`st_inline.erl` | `[h,g,do_apply]` vs `[f,do_apply,try_clauses]` | measured here |
| beam-sharp is 1.20x slower on OTP 28 / Apple Silicon | ticket / `aoc/bench/README.md` | not re-run | **not verified** |
| Emitted `-spec` widens intervals to `integer()` only when there is no Erlang spelling | `bs_emit.erl:1585-1591` (`int_part`: `{Lo,Hi}` emits `range`, `0..inf` emits `non_neg_integer`) | declared ranges already reach the abstract format | cited (read from source) |

Falsifiers that were live: noanno >3% slower (would have confirmed the ticket; got -1 to -2%); guards narrowing
the `tr` (would have confirmed "abstract format can carry it"; got `any`); guarded wrap changing asm without inline
(got identical). Any of these could have gone the other way.

## 3. Neighbour survey

**Erlang.** `erlc` default has no `inline`; options list for a plain `erlc` module is `[]` (`run.sh` section 2). Inference of
argument and return types is automatic for local functions and independent of `-spec` (`v_narrowspec`). Compiler
source is not installed (`/usr/lib/erlang/lib/compiler-8.2.6.3` has no `src`), so `beam_ssa_type` behaviour is cited from output only.

**Elixir.** Same bytecode as Erlang: options `[no_spawn_compiler_process,from_core,no_core_prepare,no_auto_import]`, no
`inline` (probe). Timing 0.998x of Erlang. Elixir 1.14 here, not 1.19.5.

**Gleam.** Emits `-compile([..., inline])` in every module it generates (generated `bench_gleam.erl` line 2). Gleam
compiler is a binary, no source to cite; the generated file is the evidence. Gleam also emits a widened `-spec` per
function (same file, `-spec spin(integer(), ...)`), which the optimiser ignores.

**Elm.** N/A: Elm targets JavaScript, not the BEAM, so there is no emitted-BEAM-code comparison. Not probed.

## 4. Measurements

Command: `RUNS=60 bash artifacts/probes/39/run.sh`. 60 rounds, every variant once per round with rotated order, 673,364
iterations, real `aoc/2025/Day01/input.txt`, answer 6770 checked for every variant. Min over rounds (ms); noise
threshold 3% per the brief.

| variant | full min | median | p90 | vs plain |
|---|---|---|---|---|
| plain Erlang `v_erl` | 9.03 | 11.7 | 14.0 | 1.000 |
| Elixir | 9.01 | 11.6 | 15.5 | 0.998 |
| Erlang + bs_emit return guard (bsc build path) | 9.02 | 11.7 | 13.8 | 0.999 |
| widened specs / narrowed specs | 9.01 | 11.6 | 13.6 | 0.998-1.00 |
| tr annotations stripped (`v_noanno`) | 8.89 | 11.5 | 14.0 | 0.984 |
| range guards (`v_guard`) | 9.15 | 11.8 | 13.4 | 1.013 |
| `-compile(inline)` | 7.95 | 10.0 | 10.4 | 0.88 |
| Gleam | 7.94 | 10.2 | 10.7 | 0.88 |
| guard + default `inline` | 8.07 | 10.3 | 11.5 | 0.89 (1.02x vs plain inline) |
| guard + `{inline,[{wrap,1},{hit,1}]}` | 7.93 | 10.2 | 10.5 | 0.88 |

Variance: min-to-median spread is 25% (9.0 vs 11.7) on this sandbox, with p90 up to 15.5; only min and
round-robin comparisons are trustworthy. Run-to-run, min is stable to ~1% across five invocations.
Code size: `v_erl.beam` 1288 B, bsc-path 1792 B, inline+bsc 1668 B (`wc -c`). Compile time was not measured
(modules this small do not discriminate).

## 5. Options

The gating question has two answers worth writing as programs. (A third, "emit range guards/specs to carry
intervals", is measured above and does not belong: guards add 6+ tests per iteration and the optimiser did not narrow;
specs are ignored; both would be dead weight.)

### Option 1: stay directive-free (status quo)

B# the author writes (`aoc/bench/Day01/bench_bs.bs`, unchanged):

```csharp
private int Wrap(int n)
Wrap(n) -> :erlang.rem(:erlang.rem(n, 100) + 100, 100)

private (int, int) Spin(int pos, int step, int left, int zeros)
Spin(pos, step, 0, zeros) -> (pos, zeros)
Spin(pos, step, left, zeros) ->
    var next = Wrap(pos + step)
    Spin(next, step, left - 1, zeros + Hit(next))
```

Compiles to: `wrap/1`, `hit/1` as separate functions, `call wrap/1`, `call hit/1` inside `spin/4`, plain Erlang's code
(`v_retguard_bsc`, 1.000x). Compiler delta: none.
Evidence: matches Erlang and Elixir within 0.2%. Strongest counterargument: beam-sharp then sits permanently ~13% behind
Gleam on call-heavy loops (measured here), and the "20% slower" ticket is closed by declaration rather than by cause.

### Option 2: emit an explicit inline list for private functions

Same B# source. The emitter appends one attribute listing the module's private, non-recursive, single-body functions:

```erlang
-compile({inline,[{'Wrap',1},{'Hit',1}]}).
```

Compiles to: `Spin` with `Wrap` and `Hit` folded in (`v_rgexplicit_bsc`, 1.003x of plain inline, 0.88x of plain Erlang),
including with the F42 return guard present, which the blanket `-compile(inline)` fails to inline (`v_rginline_bsc`).
Compiler delta, concrete: in `bs_emit:forms/1` (`bs_emit.erl:74-97`) add one
`{attribute, ?A, compile, [{inline, [{name(F,B), arity(F)} || F <- Fns, not is_public(F), single_clause(F), not_recursive(F)]}]}`
form; `not_recursive` needs a call-graph walk the emitter does not have today (a pass over `body_exprs`, or the checker
recording local calls in the module map beside `foreigns`, `bs_check.erl:156`). An unlisted-recursion test case: I compiled
`{inline,[{spin,1}]}` on a self-recursive function and `erlc` terminated normally (`rec_inline.erl`, run.sh section 4), so recursion
is not a hard hazard, but listing it buys nothing.
Evidence: 13% on this loop; 0.999-1.003x parity with Gleam.
Strongest counterargument: **stack traces lose frames** (probe 4: `[h,g,...]` becomes `[f,...]`), and F15's whole
point is that a crash names the `.bs` function and file; an inlined helper will be reported against its caller. Also the
13% is measured on one tight loop on OTP 25; the ticket's fib(100,000) result says workloads dominated by the runtime
will show nothing, so the benefit is narrow.

### Option 3: blanket `{attribute, ?A, compile, [inline]}` as Gleam does

Compiler delta: one constant attribute. Evidence: Gleam parity (0.999x), 13% faster than plain. Strongest counterargument:
interacts badly with the emitter's own guards: with the F42 return guard on `:erlang.rem`, `Wrap` exceeds the default
inline size and is **not** inlined (`v_rginline_bsc`: still `call wrap/1`), leaving 2% on the table, and the result then
depends on guard size, an invisible coupling between ticket 18's boundary tier and performance. It also inlines
public-adjacent code the author may not expect to vanish from traces.

## 6. Recommendation

**Option 2 is the cheap, measured lever, but I would not decide it yet.** The ticket's 20% is unreproduced here (no `bsc`,
OTP 25 not 28, and the measured `bsc` pre-dates F42/F52). The decision that does not depend on the missing
measurement is narrow: **allow `bs_emit` to emit a `compile` directive, scoped to an explicit list of private
functions**, because it is the only lever that moved a number here and it composes with the guards the emitter already
emits. Do **not** emit range guards or narrower specs for performance: guards cost tests per iteration and the optimiser
did not narrow (OTP 25), specs are ignored. The ticket-04 "tension" is real for the *checker* but empty at the BEAM level: the
optimiser re-infers `{-99,99}` from `Wrap`'s body whatever the declared `int` is (`v_spec` asm).

What would change my mind: (a) one run of the ticket's own harness on OTP 28 (`bsc` plus `sed` of
`{attribute,0,compile,[{inline,..}]}` into `Day01.abstr`) showing the gap is not inlining; then the annotation
hypothesis is live again and §3.3 needs an OTP 28 `beam_ssa_type` that narrows on relops; (b) a stack-trace
requirement from F15 that makes a lost frame unacceptable; then Option 1.

## 7. Not verified here / limits

- **OTP 25, not 28.** OTP 28 prints `{0,99}` where OTP 25 prints `{-99,99}`; its `beam_ssa_type` may narrow on guards and
  use annotations the JIT here ignores. Apple Silicon (ARM64 JIT) vs x86-64: unmeasured, and the JIT is where `tr` annotations
  are consumed.
- **`bsc` could not run** (lexer needs OTP 26+ `leex`, no rebar3). The `*_bsc` variants replay bsc's build path on
  hand-written forms that I transcribed from `bs_emit.erl`; they are not bsc's output. Real `bsc` forms carry real line
  numbers where mine carry 0; `{line,..}` was stripped before comparing asm.
- **The ticket's 20% was not reproduced and not explained.** On this host plain Erlang, Elixir and the bsc-path replica are
  all equal; Gleam is 13% faster for a reason (inlining) the ticket's table (Gleam 1.18.1, Gleam == Erlang) does not show.
  Either Gleam 1.18.1 no longer emits `inline` or the ticket's cause is something else on OTP 28.
- Gleam 1.12.0 and Elixir 1.14.0, not 1.18.1 / 1.19.5.
- Records and dispatch (F3 boundary guard) not measured, as in the ticket's §3.4.
- Compile time and beam size cost of inlining measured only on a 7-function module.
- Compiler source (`beam_ssa_type`, `sys_core_fold`) is not installed, so inliner thresholds are described from probe output only.
