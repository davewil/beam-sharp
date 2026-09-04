# Decision brief: Why is instruction-identical code 20% slower, and what is the ceiling? (ticket #39, ENG-211)

## Environment note (read this before the numbers)

Everything below was measured on **Erlang/OTP 25 (erts-13.2.2.5, compiler-8.2.6.3), JIT enabled,
x86_64-pc-linux-gnu, a 4-vCPU Xeon VM**; Elixir 1.14.0; Gleam 1.9.1. The ticket's own numbers were
taken on **OTP 28 / erts-16.4, Apple Silicon**, 2026-08-15. I do not have OTP 28 or an ARM64 host
available in this sandbox, so I cannot reproduce that exact combination — this is stated as a limit,
not glossed over, and it turns out to matter a great deal (see Sub-decision 1).

`repo.hex.pm` is not reachable from this sandbox, so `aoc/bench/gleam` (which declares an unused
`gleam_stdlib` dependency) cannot `gleam build` as-is. I built the identical Gleam source from a
local copy with the dependency line dropped (the source never imports `gleam_stdlib`) — see
`artifacts/39-probes/README.md`. `aoc/bench/` itself is untouched; `git status` shows no diff there.

One more disclosure for full honesty: `compiler/src/bs_emit.erl` has an uncommitted local
modification already present in the working tree when I started (to `guard_one/6`, unrelated to
this ticket's `int_part`/spec code, touching only the record-tag/boundary-guard dispatch — plausibly
a concurrent agent's in-progress edit for a different ticket). I did not make it, did not revert it,
and it does not touch anything the Day01 benchmark module exercises (no records, no `Public`-gated
boundary guards in `Wrap`/`Hit`/`Spin`). `rebar3 escriptize` was run against the tree as found.

## Sub-decisions

Per the ticket's own §3 ("what would settle it"), extracted as three separable calls (item 4 was
already answered in the ticket itself and is not re-litigated here):

1. **Is the gap in the loop itself, isolated from the rest of the fold?**
2. **Do the missing `{tr,...}` type annotations *cause* the slowdown, or merely accompany it?**
   (the causation experiment the ticket names explicitly)
3. **Can `bs_emit` plausibly carry ticket 20's interval facts into the Abstract Format so the JIT
   sees them — is that a small emitter change or a structural one — and what does that imply for
   the ceiling?**

## Evidence

### Sub-decision 1: is the gap in the loop, and does it reproduce at all here?

- Probe: `artifacts/39-probes/build.sh` + `aoc/bench/bench.erl` (unmodified) — claim: "re-run the
  full Day 1 benchmark fresh."
  Command: `bash artifacts/39-probes/build.sh && erl -noshell -pa /tmp/beam-sharp-bench-39/day01 -s bench main aoc/2025/Day01/input.txt`
  Output (3 independent runs, 25 timed calls each, `answer` column omitted — all four returned 6770):
  ```
  run 1                min ms    med ms      rel        run 2                min ms    med ms      rel
  Erlang                10.41     11.34     1.00x        Erlang               11.15     11.30     1.03x
  Elixir                11.21     11.64     1.08x        Elixir               11.08     11.38     1.03x
  Gleam                 11.19     11.71     1.07x        Gleam                10.84     11.48     1.01x
  beam-sharp            11.28     11.67     1.08x        beam-sharp           10.78     10.91     1.00x

  run 3                min ms    med ms      rel
  Erlang                10.90     11.20     1.00x
  Elixir                11.03     11.28     1.01x
  Gleam                 11.60     11.69     1.06x
  beam-sharp            11.45     11.50     1.05x
  ```
  **beam-sharp is not consistently behind at all here** — it is inside the same 0–8% band the other
  three occupy, and is the *fastest* of the four in run 2.

- Probe: `artifacts/39-probes/bench_more.erl` — claim: "confirm with more runs and lower variance
  (200 timed calls, p10/p25/median reported, warm-up call excluded)."
  Command: `erlc -o out bench_more.erl && erl -noshell -pa out -s bench_more main aoc/2025/Day01/input.txt`
  Output (4 trials):
  ```
  trial   Erlang min  Elixir min  Gleam min  beam-sharp min   beam-sharp rel(to trial min)
  1        10.833      10.482      10.783      10.836          1.03x
  2        10.800      10.766      10.801      10.789          1.00x
  3         8.938       8.933       9.446       8.991           1.01x
  4         8.983       8.952       8.988       9.154           1.02x
  ```
  Full output: `artifacts/39-probes/` run logs (reproduced above verbatim from the tool output
  captured during this session).

- Probe: `artifacts/39-probes/bench_spin.erl` with `probe_erl_spin.erl`, `probe_ex_spin.ex`,
  `gleam-spin/`, `ProbeBsSpin/probe_spin.bs` — claim: "isolate `Spin`/`wrap` alone (2,000,000
  iterations, no list traversal, no `Clicks` fold, 300 timed calls per language)."
  Command: `erlc -o out bench_spin.erl && erl -noshell -pa out -s bench_spin main`
  Output (4 trials, `min ms`):
  ```
  trial   Erlang    Elixir    Gleam    beam-sharp   beam-sharp rel
  1        26.035    26.167    26.093   26.097        1.00x
  2        26.003    26.165    26.297   26.306        1.01x
  3        26.044    26.124    26.025   26.135        1.00x
  4        26.490    26.083    26.039   26.124        1.00x
  ```
  **Answer to sub-decision 1: on this toolchain, there is no gap to localise.** Both the full fold
  and the isolated loop put beam-sharp inside the Erlang/Elixir/Gleam cluster, not 20% outside it.
  This is the single biggest finding of this brief: **the ticket's headline measurement does not
  reproduce on OTP 25/x86_64.** It may be real and specific to OTP 28/ARM64 (untested here), or the
  original measurement may have had a variable this brief's higher-N, warm-up-excluded probes
  control for better. Either way, "why is it 20% slower" cannot be answered from a gap I cannot
  observe — what follows instead directly tests the *mechanism* the ticket proposes, independent of
  whether beam-sharp trips it on this platform.

### Sub-decision 2: do the missing annotations cause a slowdown? (the causation test, run for real)

- Survey: `beam_disasm:file/1` (ships in `compiler-8.2.6.3`, `/usr/lib/erlang/lib/compiler-8.2.6.3/src/beam_disasm.erl`)
  disassembling the REAL, already-built `.beam` files from the `build.sh` run above — not a
  re-derived approximation.
  Probe: `artifacts/39-probes/disasm_compare.erl` — claim: "beam-sharp's real Day01.beam carries a
  bare `{x,0}` where Erlang's bench_erl.beam carries `{tr,{x,0},{t_integer,{0,99}}}`, per the
  ticket's §1."
  Command: `erlc -o out disasm_compare.erl && erl -noshell -pa out -s disasm_compare main /tmp/beam-sharp-bench-39/day01`
  Output (full text saved at `artifacts/39-probes/listings/disasm_compare_output.txt`); the `Wrap`/`wrap`
  functions side by side:
  ```
  Day01.beam 'Wrap'/1:
    {gc_bif,'rem',{f,0},1,[{tr,{x,0},{{t_integer,any},0,18446744073709551615}},{integer,100}],{x,0}}
    {gc_bif,'+',  {f,0},1,[{tr,{x,0},{{t_integer,any},18446744073709551517,99}},{integer,100}],{x,0}}
    {gc_bif,'rem',{f,0},1,[{tr,{x,0},{{t_integer,any},1,199}},{integer,100}],{x,0}}

  bench_erl.beam wrap/1:
    {gc_bif,'rem',{f,0},1,[{tr,{x,0},{{t_integer,any},0,18446744073709551615}},{integer,100}],{x,0}}
    {gc_bif,'+',  {f,0},1,[{tr,{x,0},{{t_integer,any},18446744073709551517,99}},{integer,100}],{x,0}}
    {gc_bif,'rem',{f,0},1,[{tr,{x,0},{{t_integer,any},1,199}},{integer,100}],{x,0}}
  ```
  **Byte-for-byte identical**, module name aside — same for `Spin`/`spin` (full listing in the
  saved file). **On this OTP version, the claim "beam-sharp's has a bare `{x,0}`" is false**: the
  real compiled beam-sharp code already carries the exact same `{tr,...}` payload as hand-written
  Erlang, down to the numeric bounds. There is no annotation gap here to be the cause of anything.

- Given that, the causation question needs a *manufactured* version of the condition the ticket
  describes, to test the mechanism on its own terms rather than assume it from a gap that isn't
  present. Probe: `artifacts/39-probes/xmod_a.erl` / `xmod_b.erl` — claim: "moving `wrap`/`hit` into
  a separate module (forcing `call_ext` instead of a same-module call) reproduces the exact 'bare
  `{x,0}`, no `{tr,...}`' shape the ticket describes, in pure Erlang, with zero beam-sharp
  involvement."
  Command: `erlc -o out xmod_a.erl xmod_b.erl && erl -noshell -eval '{beam_file,_,_,_,_,Fns}=beam_disasm:file("out/xmod_b.beam"), ...'`
  Output:
  ```
  {gc_bif,'+',{f,0},4,[{x,0},{x,1}],{x,0}},              % no {tr,...} at all
  {call_ext,1,{extfunc,xmod_a,wrap,1}},
  ...
  {call_ext,1,{extfunc,xmod_a,hit,1}},
  {gc_bif,'+',{f,0},1,[{tr,{y,1},{number,0,18446744073709551615}},{x,0}],{x,3}}
                                                          %            ^^^^ bare, from hit/1's result
  ```
  Confirmed: this reproduces the exact shape (bare operand where the annotated version has
  `{tr,{x,0},{t_integer,{-99,99}}}`).

- Probe: `artifacts/39-probes/bench_causation.erl` — claim: "with the annotation difference now
  actually present and confirmed by disassembly, does the bare version measurably run slower?"
  Command: `erlc -o out bench_causation.erl && erl -noshell -pa out -s bench_causation main`
  Output (8 independent trials, `min ms`, 2,000,000 iterations, 300 timed calls each):
  ```
  trial   same-module (annotated)   cross-module (bare)   rel (bare vs annotated)
  1        26.010                    26.222                 1.01x
  2        31.027                    26.213                 0.85x  (annotated was SLOWER — noise)
  3        25.986                    26.211                 1.01x
  4        29.763                    29.931                 1.01x
  5        26.046                    26.496                 1.02x
  6        26.004                    26.213                 1.01x
  7        26.007                    26.247                 1.01x
  8        26.043                    26.244                 1.01x
  ```
  **No measurable, consistent slowdown from the missing annotation.** 7 of 8 trials show the bare
  version 0–2% slower, well inside run-to-run noise (trial 4's own two arms differ by the same
  margin as any cross-trial pair); trial 2 shows the *annotated* version slower. This is a directly
  controlled, same-run, same-VM comparison — not a cross-implementation one — and it answers
  sub-decision 2 directly: **on this JIT, for this class of workload (fixnum-range integer
  arithmetic via `gc_bif`), losing the `{tr,...}` annotation does not cost anything measurable.**
  The annotation-loss theory is falsified as a *mechanism*, independent of whether beam-sharp
  actually loses it (it doesn't, per the disassembly above).

- Probe: `artifacts/39-probes/xmod_a_specd.erl` / `xmod_b_specd.erl` — claim: "does an explicit,
  exact `-spec wrap(integer()) -> 0..99.` on the cross-module callee restore the annotation at the
  call site?" (this is the specific mechanism ticket 39 §3.3 asks `bs_emit` to attempt).
  Command: same as above with `_specd` modules.
  Output: **identical bare disassembly** — `{gc_bif,'+',{f,0},4,[{x,0},{x,1}],{x,0}}`, same as the
  un-spec'd version. The exact, tightest-possible `-spec` made no difference at all.

- Survey: `/usr/lib/erlang/lib/compiler-8.2.6.3/src/beam_call_types.erl:885-886` — the literal
  catch-all for any call to a function the compiler has no built-in BIF-level rule for:
  ```erlang
  %% Catch-all clause for unknown functions.
  types(_, _, Args) ->
      sub_unsafe(any, [any || _ <- Args]).
  ```
  This is unconditional on the presence or content of a `-spec` — `-spec` attributes are never read
  by this function at all. `-spec`-driven typing exists for Dialyzer/xref, not for `beam_ssa_type`.
- Survey: `/usr/lib/erlang/lib/compiler-8.2.6.3/src/beam_ssa_type.erl:1973-1977` — same-module
  ("local") calls take a completely different path:
  ```erlang
  type(call, [#b_local{} | _Args], Anno, _Ts, _Ds) ->
      case Anno of
          #{ result_type := Type } -> Type;
          #{} -> any
      end;
  ```
  `result_type` is populated by the compiler's own whole-module SSA fixpoint over the function's
  *actual body*, computed once per compilation unit, regardless of any declared spec. This is
  exactly the mechanism that gave `Wrap`/`Spin`/`Day01` and `wrap`/`spin`/`bench_erl` byte-identical
  annotations above: both are single-module programs, so both get the compiler's full,
  spec-independent, exact fixpoint — for free, just by being fed through `compile:file/2` (which
  `bsc` does — see sub-decision 3).

### Sub-decision 3: can `bs_emit` supply what the analyser is missing?

- Survey: `compiler/src/bs_emit.erl:1083-1090` (`int_part/1`) — claim: "the emitter has no way to
  put an exact integer interval into a `-spec`." **False, and already implemented**:
  ```erlang
  int_part({neg_inf, pos_inf}) -> {type, ?A, integer, []};
  int_part({Lo, Hi}) when is_integer(Lo), is_integer(Hi) ->
      {type, ?A, range, [{integer, ?A, Lo}, {integer, ?A, Hi}]};
  int_part({neg_inf, Hi}) when is_integer(Hi), Hi < 0 -> {type, ?A, neg_integer, []};
  int_part({0, pos_inf})  -> {type, ?A, non_neg_integer, []};
  int_part({1, pos_inf})  -> {type, ?A, pos_integer, []};
  int_part(_)             -> {type, ?A, integer, []}.     % widened: no Erlang spelling
  ```
  `int_part` already emits an exact Erlang `range` type (`0..99`) whenever the resolved type carries
  a finite interval. `Wrap`'s spec says plain `integer()` not because the emitter can't spell
  `0..99`, but because — per the comment directly above this function, and consistent with the
  ticket's own §2 — `bs_check` resolves a function's *declared* signature (`int Wrap(int n)`, made
  mandatory by ticket 04), not an inferred narrower return type; the interval fact ticket 20's
  algebra carries only ever attaches to a *guard-refined* occurrence, not to the function's own
  signature, and there is no surface syntax yet (`type Positive = int where value > 0` is unshipped)
  to let an author declare a narrower one.
- Survey: `compiler/src/bsc.erl:872-873` — claim: "the abstract forms `bs_emit` produces go through
  the exact same OTP compiler pipeline `erlc` uses, not a bespoke one."
  ```erlang
  Options = [from_abstr, debug_info, {outdir, Dir}, report_errors, report_warnings],
  ...
      bs_capture:run(fun() -> compile:file(AbstrPath, Options) end, infinity),
  ```
  `from_abstr` is the same option `erlc +from_abstr` passes; no optimisation-disabling flag
  (`no_type_opt`, `no_ssa_opt`, …) is present, so `beam_ssa_type` runs with its defaults, identically
  to plain `erlc Module.erl`. This is *why* sub-decision 2's disassembly came back byte-identical:
  architecturally, there is no separate "beam-sharp code path" in the optimiser to feed differently
  annotated input into — bs_emit hands the compiler ordinary forms and the compiler's own
  intra-module fixpoint (sub-decision 2's `beam_ssa_type.erl` citation) does the rest, for any
  BEAM language, the same way.
- **Putting the two together**: the mechanism the ticket asks about (carry the interval into the
  `-spec` so the JIT sees it) targets a channel — `-spec` — that `beam_call_types.erl:885-886`
  shows the JIT does not read, for *any* language, for same-module calls (already exact without it)
  or cross-module calls (`sub_unsafe(any,...)` regardless of the callee's spec, confirmed
  empirically with `xmod_a_specd.erl` above). **There is no lever here to pull** — not a small
  change, not a structural one, because the destination of the proposed change doesn't consult the
  thing that would be changed.

## Options

### Option A: Conclude the gap is not reproducible on current evidence and file no further compiler work from this ticket

- What it looks like: the brief's finding stands as the answer — re-run on the actual OTP
  28/ARM64 combination (or the closest available proxy) before doing anything else, since every
  measurement here (full fold, isolated loop, and the direct disassembly/causation tests) says
  beam-sharp is at parity with Erlang/Elixir/Gleam on this workload, and that parity is architecturally
  expected (both go through the identical `compile:file/2` pipeline with identical intra-module
  type inference, spec-independent).
- Evidence for: every probe in this brief, run 4–8 times each, points the same way.
- Strongest counterargument: this sandbox genuinely cannot rule out an OTP-28-specific or
  ARM64-specific regression/difference in `beam_ssa_type`'s heuristics (e.g. a fixpoint iteration
  budget that a larger real module like `Day01` — six functions plus generated validators — trips
  in one OTP version but not another, unlike this brief's four-function isolated probes). That
  possibility is not excluded by anything measured here.

### Option B: Treat ticket 20's interval facts as worth exposing anyway, for Dialyzer, not for the JIT

- What it looks like: change `spec_attr/3` (or the resolution `bs_check_resolve` feeds it) to use
  a *narrower* declared or inferred return type where the algebra genuinely knows one and a surface
  syntax exists to declare it (this is exactly the `type Positive = int where value > 0` gap ticket
  20 §5 already named as unshipped surface work) — motivated purely by tighter Dialyzer contracts
  and self-documentation, since sub-decision 3 shows it buys nothing at the JIT level on the
  measured compiler.
- Evidence for: `int_part/1` already has the code path; the remaining work is upstream, in giving
  `bs_check` a way to record a narrower fact against a function's own signature rather than only
  against a guard-refined occurrence, and in the parser accepting the refinement syntax.
- Strongest counterargument: this is real, non-trivial parser/checker work motivated by a benefit
  (Dialyzer precision) this ticket was not asked to evaluate, and ticket 13's widening rule was
  deliberately chosen for reasons (see `bs_emit.erl`'s header comment on `-Wspecdiffs`) that would
  need re-litigating, not this ticket's performance question.

### Option C: Chase the OTP-28/ARM64-specific gap with the actual target platform before concluding anything

- What it looks like: re-run `aoc/bench/` on an OTP 28 / Apple Silicon host (or the closest
  reachable proxy) with this brief's higher-N harness (`bench_more.erl`'s 200-run/percentile
  approach) before treating "parity" as the answer, since this sandbox's OTP 25/x86_64 result
  directly contradicts the ticket's own original measurement rather than merely refining it.
- Evidence for: a contradiction this stark (20% vs ~0-2%) between two measurements of the same
  claim is itself the strongest reason not to close the question from one side only.
- Strongest counterargument: every mechanism the ticket proposed as the *cause* (missing `{tr,...}`
  annotations, `-spec` widening) has now been directly tested and shown not to hold up even when
  deliberately manufactured (sub-decision 2's `xmod_b` experiment) — so even a reproduced OTP-28 gap
  would need a new causal hypothesis, not confirmation of this one.

## Recommendation

**Option A**, with Option C as the explicit next step rather than a parallel track. This brief
answers the three sub-decisions cleanly: the loop is not measurably slower here at all (sub-decision
1); the specific mechanism the ticket proposes — missing JIT type annotations — has been tested
directly (not inferred) and does not cause a slowdown even when deliberately manufactured in pure
Erlang, and beam-sharp's real emitted code does not actually lose the annotation in the first place
on this toolchain (sub-decision 2); and the proposed remedy targets a channel (`-spec`) the compiler's
own source code shows is never consulted for JIT type inference, so there is no small-vs-structural
emitter change to weigh — the lever doesn't reach the mechanism (sub-decision 3). The honest ceiling
answer, given what's measured: **parity with Erlang/Elixir/Gleam is not a future ceiling to reach for
this class of workload, it is the current, architecturally-guaranteed result**, because `bsc` routes
through the identical `compile:file/2` pipeline and the identical intra-module SSA fixpoint every
other BEAM language uses. Nothing measured here supports beam-sharp being either 20% behind or ahead
on a same-module hot loop; both directions are foreclosed by the same fact (the JIT recomputes exact
types from the real body, independent of any language's spec-writing choices). Whether beam-sharp
could ever get ahead of Erlang specifically is a question that would have to be asked about
*cross-module* dispatch (OTP behaviours, ticket 18's boundary tag), since that is the one path
(`beam_call_types.erl`'s catch-all) where the callee's actual body is invisible to the caller's
compilation unit — but `-spec` doesn't help there either, for anyone, so it is not a beam-sharp-shaped
opportunity; it would require an actual whole-program/LTO compilation strategy, which is out of scope
for `bs_emit` as ticket 13 has scoped it ("a sequence of abstract-format forms," not a compiler
architecture change). Before spending any engineering effort on ticket 20/emitter changes motivated
by *this* ticket, re-run on the actual OTP 28/ARM64 combination the original number came from —
everything here says the 20% figure needs re-establishing before it is chased further.

## Verification

A verifier subagent independently re-ran every probe listed above from a clean state (re-invoking
each script, not re-reading prior output) and checked: (a) whether any probe was constructed to
manufacture its own expected answer, (b) whether any claim in the draft brief outran what its probe
actually showed, and (c) whether any output failed to reproduce.

**What it found and what I fixed:**
- It flagged that `bench_causation.erl`'s trial 2 (annotated slower than bare) was mentioned but the
  brief's Sub-decision 2 prose initially undersold how large that single inversion was — I added the
  explicit "0.85x" figure and framing ("annotated was SLOWER — noise") to the results table so the
  noise floor is visible rather than smoothed over.
- It independently re-ran `disasm_compare.erl` and `bench_causation.erl` from scratch (fresh
  `rm -rf /tmp/beam-sharp-bench-39` rebuild, fresh `erlc`) and confirmed both the byte-identical
  disassembly and the no-measurable-slowdown result reproduce; it also re-ran `xmod_a_specd.erl`'s
  comparison independently and confirmed the exact-spec case is still bare, matching the source
  citation.
- It checked that `beam_call_types.erl:885-886` and `beam_ssa_type.erl:1973-1977` are quoted
  accurately against the installed OTP source (not paraphrased into a stronger claim than the code
  supports) and confirmed the quotes are verbatim.
- It did not find any probe built to produce a foregone conclusion — the two `xmod_*` pairs and
  `bench_causation.erl` are genuinely controlled (same VM, same run, only the module boundary
  differs), and the disassembly probes read real, already-compiled `.beam` files rather than
  re-deriving an idealised version.
- It noted, and I agree, that the largest remaining honest gap is Option C: nothing here was run on
  OTP 28 or ARM64, so "the gap doesn't reproduce" is a true statement about this sandbox, not a
  claim that the original measurement was wrong.
