# Decision brief — ticket 39 (ENG-211): why is instruction-identical code 20% slower, and what is the ceiling?

Status of the ticket: **open, left open.** This brief decides nothing.
Probes: `artifacts/probes/39/` — `./run.sh` re-runs everything below; `results.txt` is one full run.

## What was run, and what it cannot say

- **OTP 25.3 / BeamAsm JIT / x86_64 Linux, 4 cores, Elixir 1.14.0, Gleam 1.12.0.** The ticket's numbers are OTP 28 / erts-16.4 /
  Apple Silicon (ARM JIT). **Absolute times and the 20% figure are therefore not comparable, and nothing here measures OTP 28
  or ARM.** Every "no gap" below means "no gap on this VM".
- `bsc` was built from `compiler/src` on OTP 25 with a one-line lexer patch (OTP 25's leex has no `TokenLoc`); diagnostics'
  columns are wrong, emitted forms are not affected.
- The AoC puzzle input is not in the repo. `probes/39/time.erl` generates 4,732 rotations / 670,911 clicks from a fixed seed
  (the ticket's input: 4,732 / 673,364). All variants return the same answer (6638), checked before timing.
- Timing is interleaved round-robin, 41 rounds, min and median. **Noise floor, measured:** two byte-identical copies of the
  Erlang reference (`e0`, `e0b`) differ by 0.0–1.8% (min) across the three runs in `results.txt`, and by 4.5% in one earlier
  noisy run that I did not keep.
  Treat differences under ~3% as zero.

## Sub-decisions the ticket implies

1. Is the 20% gap there to explain at all?
2. If operands carry less type information, does that cost time?
3. Can the abstract-format emission path carry B#'s interval facts to the optimiser (ticket §3.3)?
4. What is the ceiling — and what lever moves it?
5. (Left open by the ticket: records and dispatch.) What does the boundary tag guard cost?

## Evidence

### 1. At HEAD, on this VM, the instruction stream and the annotations are identical, and so is the time

`disasm.escript` normalises labels and names and digests the instruction stream; equal digest = identical code.
`bench_erl.erl` vs `bsc` on `aoc/bench/Day01/bench_bs.bs`:

| function | Erlang (`e0`) | B# as emitted (`bs0`) |
|---|---|---|
| `wrap` | 4 insns, 3 `{tr,..}`, digest 2384507592 | **same digest** |
| `hit` | 5 insns, digest 2203081286 | **same digest** |
| `spin` | 19 insns, 4 `{tr,..}` incl. `{t_integer,{-99,99}}`, digest 2175485888 | **same digest** |

The ticket's observed difference — *"Erlang's loop has `{tr,{x,0},{t_integer,{0,99}}}` where beam-sharp's has a bare `{x,0}`"* —
**does not reproduce**: B#'s `spin` carries `{tr,{x,0},{t_integer,{-99,99}}}` too, because OTP's own pass infers `wrap`'s return
range from the emitted body (success-type machinery in `beam_ssa_type.erl`: `st_join_return_types` ~1694/1725, `update_success_types` ~1746; `beam_call_types.erl:358` for `rem`. Corrected by the verifier: `:812` is `opt_ranges`, an `element/2` range-check pass, not this mechanism).
Timing: `bs0` ≈ `e0` ≈ `e0b` in every run (`min` 10.79 / 10.78 / 10.77 ms in run 1; 10.65 / 10.58 / 10.77 in run 2), inside the noise floor.

Two things changed in the emitter since the ticket was written and both are visible in the `.abstr`: `Wrap` now wraps each
`:erlang.rem` result in `case E of V when is_integer(V) -> V end` (the foreign-return boundary guard, ENG-357), and
`bs_emit` emits a spec per function. Both are **no-ops to the optimiser**: variants `bs1` (specs stripped), `bs2` (guard
stripped) and `bs3` (both) have the same digests as `bs0` and the same times.
**I could not check the emitter as of 2026-08-15** (the repo's history starts 2026-10-05, 50 commits), so I can say the gap is
absent at HEAD on x86/OTP 25, not that it was absent then.

### 2. Losing the annotation does not slow this loop on this VM

`e1` is Erlang whose `wrap` returns through an opaque remote call (`opaque:id/1`): the range is genuinely unknown to the
optimiser. Disassembly: `spin` loses `{t_integer,{-99,99}}` (bare `{x,0}` in the `+` — the ticket's exact symptom),
`hit` loses its `{tr}`. Time: `e1` vs `e0` (`min`, three runs): 10.83 / 10.51 / 10.50 vs 10.78 / 10.58 / 10.75 ms — **no difference outside
the noise floor.** So on x86/OTP 25 "less type information" and "slower" are not linked. Whether they are linked on ARM/OTP 28
is **unmeasured**.

### 3. What the abstract format can and cannot carry

- **A `-spec` carries nothing to the optimiser.** `e3` (`-spec wrap(integer()) -> 0..99.`): digest identical to `e0`. `bs1` vs
  `bs0`: identical. (Consistent with the ticket's §1 and with `v3_core.erl` having no spec handling.)
- **A guard carries integer-ness, not an interval, on OTP 25.** `e2` adds `is_integer(Pos), Pos >= 0, Pos =< 99` to `spin`:
  19 → 25 instructions, the `{tr}` on `Pos` stays `{t_integer,any}`, and the time is `e1`'s. So the one in-band way an
  emitter has to state a range costs runtime tests and bought nothing here. **Unmeasured:** whether OTP 26–28's type pass
  narrows ranges from comparison guards (it would change this row).
- **What does reach the optimiser is the body.** Local return ranges are inferred from the emitted function body. B#'s
  mandatory signature (ticket 04) therefore does *not* discard the range for local calls: the checker's `int` return is a
  contract; the emitted body is still the evidence OTP reads. This answers the ticket's §2 "tension" for the local-call case.
  It is **lost across a module boundary** (e1 is that situation) — OTP's type pass does not see other modules.

### 4. The lever that does move the number: inlining, not annotation

Gleam's generated `bench_gleam.erl:2` begins `-compile([no_auto_import, …, inline])`. Adding only that to the same Erlang
(`e4`) gives `spin` = **15 insns, 8 `{tr}` including `{t_integer,{0,99}}`, digest 784669427 — byte-for-byte the digest of
Gleam's own `spin`**. Time, OTP 25, three full runs, `min`:

| | run 1 | run 2 | run 3 |
|---|---|---|---|
| Erlang `e0` | 10.78 | 10.58 | 10.75 |
| Elixir 1.14 | 10.84 | 10.33 | 10.85 |
| B# as emitted `bs0` | 10.79 | 10.65 | 10.79 |
| Erlang + `inline` `e4` | 9.44 | 9.03 | 9.49 |
| Gleam | 9.49 | 9.04 | 9.48 |
| B# + `{attribute,0,compile,[inline]}` `bs4` | 9.69 | 9.24 | 9.65 |
| B# + inline, foreign-return `case` removed `bs5` | 9.50 | 8.99 | 9.47 |

(These are the three runs in `results.txt`. Absolute times drift ~1.5% between runs, hence the within-run comparison.)

**Inlining is worth ~12% on this loop on this VM, and Gleam is that far ahead of Erlang/Elixir/B# here.** (The ticket's own
OTP 28 table had Gleam 3% ahead of Erlang; the size of the effect is VM-dependent.) B# can match it with one extra form in
the header `bs_emit` already builds (`bs_emit.erl:73-78`; today no `compile` attribute is emitted).

`bs4` is ~2–3% slower than `e4`, while `bs5` (inline + the `is_integer` boundary `case` removed) is **digest-identical to
Gleam's and `e4`'s and times the same**. Reading: with `inline` on, the foreign-return guard makes `Wrap`'s body exceed the
inliner's weight budget (`cerl_inline.erl:109` onward) and it is not inlined, costing ~2–3%. Without `inline` the guard is free
(item 1). This is measured; *why* it exceeds the budget is inferred from the weights, not separately probed.

Cost of the lever (`inline_cost.sh`): `.beam` bytes 2092 → 1988 (smaller here). **Stack traces change**: with `inline`, a
crash in an inlined helper shows `{st1,'-inlined-helper/1-',[-1]}` and **the caller's `run/1` frame is absent** (without
it: `helper`, then `run/1`). For a language whose ticket 12 chose let-it-crash, trace shape is a visible cost.
Compile time of `inline`: not measured.

### 5. Records: the Kind-tag guard costs ~30–45% of a 200k-record field sum — and private functions pay it

`rec_noguard.escript` removes *only* the `map_get('Kind', T) =:= 'Rec.Tag'` clause guard from the same module's `WeightOf`
(public) and `WeightP` (private). 200k record-maps, `SumPub` / `SumPriv`, min of 41:
tag test present 3.21–3.44 ms vs absent 2.26–2.53 ms (`results.txt`, §6), **≈ +1.0 ms ≈ +5 ns per call, +32–47% of a loop whose body is a map
read**. The listing also shows the private `WeightP` carries `map_get Kind` + `is_eq_exact` — direct evidence for ticket 59's
asymmetry claim. This is the biggest cost I measured, and a micro-benchmark upper bound: real bodies do more work per call.

## Neighbours

| language | what it does here | source |
|---|---|---|
| Erlang | infers ranges itself from bodies; specs are not inputs; `inline` is opt-in | `compiler-8.2.6.3/src/beam_ssa_type.erl:1694-1790`, `beam_call_types.erl:358`; `beam_ssa_codegen.erl:1550` (the `var_info` it prints); `cerl_inline.erl:109` (weights) |
| Elixir 1.14 | same pipeline, no `inline`; `spin` listing has the same `wrap` digest as Erlang | probe §3 (`dump_elixir.erl` recovers the forms); `@compile {:inline,…}` is per-module opt-in. *Elixir's own stdlib sources are not installed here (`/usr/lib/elixir/lib/elixir/lib/*.ex` absent), so I cite no Elixir source line.* |
| Gleam 1.12 | emits Erlang source with `-compile(inline)` and a spec per function; no range information of its own | generated `build/dev/erlang/bench_gleam/_gleam_artefacts/bench_gleam.erl:2,7`. *Gleam compiler source is not installed; I cite generated output only.* |
| Elm 0.19.1 | **not surveyed.** Targets JavaScript; `elm make` needs `package.elm-lang.org`, which returns 403 from this sandbox | — |

## Options

### A. Treat the gap as not reproduced: re-baseline, change nothing yet

Re-run `aoc/bench/` (and `probes/39/run.sh`) on the OTP 28 / Apple Silicon machine that produced the 20%; if `bs0` ≈ `e0`
there too, close "what causes it" as *an emitter that has since changed* and keep only the ceiling question.
- Evidence for: items 1 and 2 — identical code, identical annotations, identical time, and losing the annotation costs nothing here.
- **Strongest counterargument:** the one machine where the gap was seen is the one machine I could not test. On ARM the JIT may
  well specialise on `{tr}` in a way x86 does not; item 2 would then not transfer, and A defers the real finding.

### B. Emit `-compile(inline)` (Gleam's choice), and shape the foreign-return guard so `Wrap`-sized functions still inline

Compiler delta: one header attribute in `bs_emit`; for the guard, emit it so it does not enlarge the helper's weight (the `bs5`
shape: guard at the call site's boundary, or a shared `bs@check_int/1` — **not yet probed, only the guard's absence is**).
- Evidence for: item 4 — ~12% faster than Erlang/Elixir on this loop, digest-identical to Gleam; bytes smaller; this is the
  "ceiling above Erlang" the ticket asks about, reached with one line.
- **Strongest counterargument:** stack traces lose frames (measured), and `inline` is a module-wide, size-driven heuristic whose
  effect on code the benchmark does not contain (records, large bodies) is unmeasured, as is compile time. A language that
  promises readable crashes is paying observability for a benchmark that has one hot loop. The bs4→bs5 gap (2–3%) also says the
  boundary guard interacts with it, so B is two changes, not one.

### C. Try to ship B#'s interval facts to the optimiser through guards or specs

- Evidence: items 3 — specs: no effect; guards: +6 instructions, range not recovered, time unchanged.
- **Strongest counterargument (for C):** this is OTP 25. If OTP 27/28 narrows on `>=`/`=<` guards, `e2` would flip and C
  becomes the only way to use ticket 20's intervals. I have no OTP 28 here to say it does not. As measured, C has negative value.

## Recommendation

**A first, then B behind it.** A is nearly free and is the only thing that can say whether the original 20% exists anywhere:
run `probes/39/run.sh` on the Apple Silicon / OTP 28 machine and compare `bs0` to `e0`. If it still shows ~20%, the cause is not
annotations on this VM and not instruction count — the probes then localise it (the `e1` row is the experiment the ticket's
§3.2 asked for). Independently of that, B is the first measured evidence of a real ceiling above Erlang; I'd take it as a
separate decision *with* the stack-trace cost put to David as code (a crash trace with and without `inline`), because the
ticket's own rule says a design question is a program plus its compiler delta. I would **not** pursue C on current evidence.
The record tag guard (item 5) is the largest cost found and belongs to ticket 59, not here; it is the only place in this brief
where "static typing pays a runtime tax" is true.

## What is unmeasured (do not cite as fact)

OTP 26–28 behaviour of any row; ARM; whether `bs0` ≈ `e0` held on 2026-08-15; compile-time cost of `inline`; any workload
other than this loop and a 200k-record sum; the guard-as-shared-function shape in B; Elm.

## Independent verification (separate agent, re-ran every probe from clean copies)

Verdict: **sound with caveats.** All digests and timings reproduced. Mutations behaved as predicted: removing `inline` from `bs5` removed the speedup; keeping the guard but forcing `inline` on `Wrap`/`Hit` restored Gleam's digest and time (so the guard-exceeds-inliner-budget explanation is now tested, not only inferred); an identity transform in the record probe collapsed the 1.34-1.53x ratio to 1.00-1.06x.

Caveats a reader must carry:
1. **Noise floor is wider than stated above.** Byte-identical `e0` vs `e0b` differed by up to ~5.8% in `min` over nine runs. Use medians for effects under 3%; the 2-3% `bs4`/`bs5` gap shows in medians only. The ~12% inline effect is well outside the noise.
2. `e1` (opaque `wrap`) also changes `wrap`'s argument type to `number` and swaps a local return for a remote tail call, so "annotation loss costs nothing" is not a single-variable test (the extra call biases against the null result, so it is not hollow).
3. The record-guard figure (~5 ns/call, +34-53% on a record-sum microbenchmark) is an upper bound.
4. Everything is OTP 25 / x86; the ticket's 20% gap is untested. `bs2`/`bs3` emulate older emission and prove nothing about the actual 2026-08-15 emitter.
