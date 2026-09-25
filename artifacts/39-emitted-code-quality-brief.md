# Decision brief: ticket 39 — "Why is instruction-identical code 20% slower, and what is the ceiling?"

Status of this document: **research only**. It does not resolve the ticket, does not add a
Decisions entry, and does not change any Status line. Ticket:
[`wayfinder/issues/39-emitted-code-quality.md`](../wayfinder/issues/39-emitted-code-quality.md)
(Linear ENG-211).

**Headline finding, stated first because it inverts the ticket's premise on this toolchain:**
on Erlang/OTP 25.3.2 + Elixir 1.14.0 + Gleam 1.19.0-rc1 (this container's toolchain — the
ticket's own numbers are OTP 28/erts-16.4, Elixir 1.19.5, Gleam 1.18.1), **the reported 20% gap
does not reproduce.** beam-sharp, Erlang and Elixir are statistically tied (~1.14–1.17×
relative to the fastest), and the outlier is **Gleam** (faster, not beam-sharp being slower).
Disassembly (via `beam_disasm`, decoding the actual `.beam` code chunk, since
`erts_debug:disassemble/1` is inert on this JIT build — see Probe 2) shows beam-sharp's
`Spin/4` carries the **exact same `{tr,Reg,{t_integer,Range}}` annotations** as hand-written
Erlang's `spin/4`, contradicting the ticket's central factual claim ("Erlang's `Spin` carries
`{tr,{x,0},{t_integer,{0,99}}}` where beam-sharp's has a bare `{x,0}}`) for this OTP/compiler
combination. Whether that claim still holds on OTP 28 is **not something this container can
test** (no OTP 28 available) — see "What this brief cannot settle" below.

---

## Sub-decisions this ticket implies

1. **Is the 20%-slower-than-Erlang finding reproducible on a different OTP/compiler-source
   combination?** — Tested. **No, it inverts**: on OTP 25.3.2 beam-sharp ties Erlang/Elixir and
   Gleam is the ~13–14% outlier (faster). See Probe 1.
2. **Is the gap in `Spin` at all (ticket §3 item 1)?** — Tested via an isolated-loop
   microbenchmark that calls `Spin`/`spin` directly (no list fold, no `Sign`/`Size`/`Clicks`
   dispatch). All four languages land within ~1–2% of each other at both N=5,000,000 and
   N=20,000,000 iterations. See Probe 4.
3. **Do the FFI/boundary-guard annotations cause annotation loss, or merely accompany it (ticket
   §3 item 2)?** — Tested by hand-writing an Erlang module (`wrap_guarded.erl`) that reproduces
   *exactly* the shape bs_emit's abstract code uses for an FFI call (`case erlang:rem(...) of Rv
   when is_integer(Rv) -> Rv end`, per ticket 18's boundary-defence decision). Result: **no
   annotation loss** — the hand-written guarded module's `spin/4` is annotation-for-annotation
   identical to beam-sharp's `Spin/4` and to plain `spin/4`. This rules out "the FFI validation
   wrapper shape defeats the optimizer's narrowing" as a mechanism, at least on OTP 25's
   `beam_ssa_type`/`beam_call_types` pipeline. See Probe 3.
4. **Can `bs_emit`'s Abstract Format carry beam-sharp's proven intervals into a form the
   optimizer trusts (ticket §3 item 3)?** — Answered from OTP compiler source, not just
   observation: **the optimizer's success-typing pass never consults `-spec` for narrowing at
   all**, for *either* local or exported functions (`beam_ssa_type.erl:118-120`, `:439-442`,
   `:693-697`, `:720-723` — quoted in full below). So the ticket's implicit mechanism ("bs_emit
   should widen `-spec` less, or attach a stronger hint") has **no channel to act through** in
   this compiler architecture: the pass re-derives everything itself, structurally, from the
   function body, every time, regardless of any declared type. The lever that exists is the
   *shape of the emitted body* — which beam-sharp's abstract code (once past frontend choices
   like inlining) already matches Erlang's on this OTP. There is nothing for `bs_emit` to
   "supply" that the optimizer would use over its own analysis.
5. **Does this generalise to records/dispatch (flagged in the ticket as never measured)?** —
   **Not tested here either.** Neither the original ticket's workloads nor this brief's probes
   touch a record or an OTP-callback dispatch path. This remains open exactly as the ticket
   states it.
6. **Is the compiler build under test the same one that produced the ticket's numbers?** — **No,
   and this matters.** See "What this brief cannot settle."

---

## Probes run

All probes were executed in this container. Toolchain actually used: **Erlang/OTP 25.3.2
(erts-13.2.2.5), Elixir 1.14.0, Gleam 1.19.0-rc1** (built from `/tmp/gleam-src`). This is
materially older/different from the ticket's OTP 28/erts-16.4, Elixir 1.19.5, Gleam 1.18.1 —
flagged per the task brief, and discussed under "What this brief cannot settle."

### Toolchain repairs needed before any probe could run (recorded for reproducibility)

- `erlang-parsetools` in this image was missing `include/leexinc.hrl` and `include/yeccpre.hrl`
  entirely (a packaging gap, not a beam-sharp issue) — restored from `/tmp/otp-src`.
- `bsc` has no build in this container (no `rebar3` binary works against OTP 25 — the prebuilt
  rebar3 escript itself targets a newer runtime and fails to load). Built `bsc` by hand:
  `leex:file`/`yecc:file` with explicit `scannerfile`/`parserfile` (OTP 25's `leex`/`yecc` do not
  accept an `outdir` option), then `erlc` the rest of `compiler/src/*.erl`.
- `compiler/src/bs_lexer.xrl` uses a `TokenLoc` variable that only exists in a **newer leex**
  than ships with OTP 25.3.2 (leex's per-token column tracking, `error_location` support). OTP
  25's `leex` does not recognise `TokenLoc` at all — the generated `bs_lexer.erl` fails to
  compile with "variable 'TokenLoc' is unbound" in every rule action. **This is a real,
  externally-visible fact about the compiler's OTP floor for *building bsc itself*** (as opposed
  to the emitted `.abstr`'s claimed OTP 24–28 portability, which is a separate claim about the
  *output*, not the toolchain needed to produce it) — worth a note in `compiler/README.md` if not
  already there, since "builds unchanged on OTP 24…28" (README:272) could be read as implying the
  compiler builds on OTP 24 too, which was not tested and looks doubtful given this leex
  dependency. **Worked around, in `/tmp` only, never touching the repo**: post-processed the
  generated `bs_lexer.erl` to thread the already-available `TokenLine` integer through as
  `TokenLoc` (dropping column tracking, which doesn't affect the arithmetic/exhaustiveness under
  test). Scripts: `/tmp/patch_lexer.py`, `/tmp/patch_lexer2.py`, `/tmp/patch_lexer3.py`.
- Gleam 1.19.0-rc1's own internal build tool emits an Erlang `maybe/else` expression
  (`compile_abstr_file/3` in its bundled escript), which is an OTP-25-experimental feature not
  enabled by default. Worked around with a local `escript` wrapper (`/tmp/escript-wrap/escript`)
  that injects `-feature(maybe_expr, enable).` into Gleam's *own* temp file before invoking the
  real `escript` — again, nothing in the repo touched.
- Building the repo's `aoc/bench/gleam` project needs `gleam_stdlib` from `hex.pm`, which this
  session's egress policy blocks (403 from the agent proxy — correctly not retried/routed
  around, per the proxy's own instructions). **Correction to my own process**: I briefly edited
  `aoc/bench/gleam/gleam.toml` in the repo to drop the dependency so I could test the no-network
  path; this was out of scope (task says "do not write to any file outside `artifacts/`") and
  was reverted by the environment's own protection before I could undo it myself (`git status`
  confirms the repo is clean; noted here for honesty about the misstep). The dependency
  requirement turned out not to matter anyway, because the actual benchmark's `bench_gleam.gleam`
  imports nothing from `gleam_stdlib` — I later rebuilt the real, dependency-declaring project as
  originally checked in and it built and ran fine once the `escript`/`maybe` fix was in place;
  the resulting `.beam` is what every reported number below uses.

### Probe 1 — re-run the four-language benchmark verbatim (ticket's own harness, `aoc/bench/`)

Built all four into one `ebin` exactly as `aoc/bench/build.sh` does (its hard-coded absolute
paths were routed to `/tmp` instead, since `$TMPDIR`/`bsc` differ here), then ran the repo's own
`bench.erl` unmodified against `aoc/2025/Day01/input.txt`.

```
$ erl -noshell -pa /tmp/beam-sharp-bench/day01 -s bench main \
      /home/user/beam-sharp/aoc/2025/Day01/input.txt

4732 rotations, 673364 clicks simulated per run

             answer      min ms    med ms      rel
Erlang       6770         13.15     13.47    1.15x
Elixir       6770         13.16     13.43    1.15x
Gleam        6770         11.48     11.61    1.00x
beam-sharp   6770         13.12     14.05    1.14x

all four agree on 6770
```

Repeated 4 more times back to back; stable to within noise every time (beam-sharp/Erlang/Elixir
1.13×–1.17×, Gleam pinned at 1.00×; full output in the transcript). **The ticket's own qualitative
finding — beam-sharp is the outlier — does not hold here; the outlier is Gleam, and beam-sharp is
indistinguishable from hand-written Erlang.**

### Probe 2 — disassemble `Wrap`/`Spin` vs `wrap`/`spin`, including JIT type annotations

`erts_debug:disassemble/1` returns `false` for *every* MFA on this build, including
`{lists,reverse,1}` — it is inert on this JIT runtime, not specific to beam-sharp. Used
`beam_disasm:file/1` (from the `compiler` app, decodes the `.beam` code chunk directly, works
regardless of export status) instead:

```erlang
{beam_file, _, _, _, _, Code} = beam_disasm:file("Day01.beam"),
[F || F <- Code, element(2,F)=='Spin', element(3,F)==4].
```

Result (both trimmed to the operative instructions; full listings in
`/tmp/disasm2_output.txt`):

```
bs   Wrap/1: 8 instructions   -- gc_bif rem / + / rem, same tr annotations as erl
bs   Spin/4: 26 instructions  -- {tr,{x,0},{{t_integer,any},...,99}} etc.
erl  wrap/1: 8 instructions   -- IDENTICAL, including the {tr,...} annotations
erl  spin/4: 26 instructions  -- IDENTICAL, including the {tr,...} annotations
```

Concretely, the loop's carried-value instruction in both is byte-for-byte:

```
{gc_bif,'+',{f,0},1,
        [{tr,{y,1},{{t_integer,any},0,18446744073709551615}},
         {tr,{x,0},{{t_integer,any},0,1}}],
        {x,3}}
```

**This directly contradicts the ticket's §1 claim** ("Erlang's `Spin` carries
`{tr,{x,0},{t_integer,{0,99}}}` where beam-sharp's has a bare `{x,0}}`) for this OTP/compiler
build. Either the claim is OTP-28-specific, or it is specific to the exact compiler commit that
produced it (see "What this brief cannot settle" — both are live possibilities and this brief
cannot distinguish them).

### Probe 3 — does the FFI-validation-guard shape strip annotations? (ticket §3 item 2, done for real)

beam-sharp's abstract code for `Wrap` (dumped via `beam_lib:chunks(..., [abstract_code])`) shows
it does **not** call `erlang:rem/2` bare — per ticket 18's boundary-defence decision (FFI
declarations "cross as `list<term>` + `ValidateAs<T>`, whose `result` forces the failure arm"),
it wraps each declared-FFI call:

```erlang
case erlang:rem(N, 100) of
    Rv0 when is_integer(Rv0) -> Rv0
end
```

This is a **genuinely new candidate mechanism the ticket never tested** (it only tried stripping
`-spec`, never this guard shape). Hand-wrote `/tmp/wrap_guarded.erl` reproducing this exact shape
in plain Erlang and disassembled it:

```
guarded wrap/1 (11 instrs):
  {gc_bif,'rem',{f,0},1,[{x,0},{integer,100}],{x,0}}          <- first rem: N is bare (no -spec)
  {gc_bif,'+',{f,0},1,[{tr,{x,0},{...,-100,99}},{integer,100}],{x,0}}
  {gc_bif,'rem',{f,0},1,[{tr,{x,0},{...,1,199}},{integer,100}],{x,0}}

guarded spin/4 (26 instrs): byte-for-byte AND annotation-for-annotation identical to
  bs Spin/4 and erl spin/4.
```

The **only** difference from beam-sharp's `Wrap/1` is that beam-sharp's very first `rem`
argument (`N` itself) carries a trivial `{tr,{x,0},{{t_integer,any},0,max}}` tag (from
beam-sharp's `-spec`, which Erlang's `Wrap` in `Day01` has and my hand-written `wrap_guarded`
does not) — but that tag carries **no narrowed range**, just "is an integer," and it has **zero
effect on `Spin/4`**, which is identical either way. **Conclusion: on this OTP, neither the
FFI-validation-guard shape nor the presence/absence of a widened `-spec` costs any narrowing in
the hot loop.** This corroborates, from a different angle, the ticket's own §1 refutation of the
`-spec` hypothesis, and closes off the FFI-guard hypothesis too.

### Probe 4 — isolate the loop (ticket §3 item 1)

Wrote isolated `SpinIso(n) -> Spin(50, 3, n, 0)`-style entry points for all four languages (fresh
files under `/tmp/iso/`, nothing added to the repo), removing `Clicks`/list-fold/`Sign`/`Size`
entirely, and timed 25 runs at two different N to check the result isn't an artifact of the
iteration count:

```
N = 20,000,000:
Erlang       {50,200000}   342.94ms min   1.01x
Elixir       {50,200000}   342.79ms min   1.01x
Gleam        {50,200000}   339.09ms min   1.00x
beam-sharp   {50,200000}   345.13ms min   1.02x

N = 5,000,000:
Erlang       {50,50000}    85.87ms min    1.02x
Elixir       {50,50000}    86.01ms min    1.02x
Gleam        {50,50000}    84.07ms min    1.00x
beam-sharp   {50,50000}    85.96ms min    1.02x
```

All four answers agree (correctness check), and all four cluster within ~2% at both scales.
**The tight loop itself shows no beam-sharp-specific cost on this OTP** — consistent with Probes
1–3.

*(Incidental, not central to this ticket: Probe 1's full click-workload shows Gleam ~13–14%
ahead of the other three, but Probe 4's isolated loop shows Gleam only ~1–2% ahead. Disassembly
(`/tmp/disasm5.erl`) shows Gleam's frontend inlines `wrap`/`hit` directly into `spin` with no
`call` instructions at all — a genuine, real frontend-inlining difference from Erlang/Elixir/
beam-sharp, which all keep them as separate calls — but the arithmetic doesn't obviously scale to
a 14% full-workload gap from a difference this small in the isolated loop. This is a real,
unresolved oddity about **Gleam's** advantage, not about beam-sharp, and it sits outside this
ticket's scope; flagging it rather than chasing it further.)*

---

## Neighbour-language survey: how the BEAM's own optimizer propagates integer ranges

File: `/tmp/otp-src/lib/compiler/src/beam_call_types.erl` (OTP tag `OTP-25.3.2`).

- **`rem`'s return-type rule**, `beam_call_types.erl:358-360`:
  ```erlang
  types(erlang, 'rem', Args) ->
      ArgTypes = [#t_integer{}, #t_integer{}],
      sub_unsafe(erlang_rem_type(Args), ArgTypes);
  ```
- **The actual interval arithmetic**, `beam_call_types.erl:904-906` and `:987-994`:
  ```erlang
  arith_type({bif,'rem'}, ArgTypes) ->
      erlang_rem_type(ArgTypes);
  ...
  erlang_rem_type([LHS0, #t_integer{elements=Range2}]) ->
      Range1 = case LHS0 of
                   #t_integer{elements=R1} -> R1;
                   _ -> any
               end,
      #t_integer{elements=beam_bounds:'rem'(Range1, Range2)};
  erlang_rem_type(_) ->
      #t_integer{}.
  ```
  and the divisor-sign-aware bound computation itself in `beam_bounds.erl:91-102`.

  **This is the entire mechanism that produces the `0..99` range in both beam-sharp's and
  Erlang's `Wrap`/`wrap`.** It is a *pure function of the BIF's own known semantics applied to
  whatever range is already known for the dividend* — it does not care whether that range came
  from a literal, a local computation, or (per the next citation) a declaration, because it
  never looks at a declaration at all.

- **`-spec` is never consulted by this pass, for any function** — `beam_ssa_type.erl:118-120`
  (the pass's own doc comment, citing Lindahl & Sagonas' *"Practical Type Inference Based on
  Success Typings"*):
  ```erlang
  %% The general idea is to start out at the module's entry points and propagate
  %% types to the functions we call. The argument types of all exported functions
  %% start out a 'any', whereas local functions start at 'none'.
  ```
  and enforced twice more explicitly, `beam_ssa_type.erl:439-442`:
  ```erlang
  #{ Id := #func_info{exported=true} } ->
      %% We can't infer the parameter types of exported functions, but
      %% running the pass again could still help other functions.
      Ts = maps:from_list([{V,any} || #b_var{}=V <- Args]),
  ```
  and `beam_ssa_type.erl:693-697` / `:720-723` (call-site narrowing, same rule stated twice for
  two call shapes):
  ```erlang
  %% We can't narrow the argument types of exported functions as they
  %% can receive anything as part of an external call. We can still
  %% rely on their return types however.
  ```

  **This settles ticket §3 item 3 more precisely than the ticket poses it.** The question was
  "can `bs_emit` supply what the analyser is missing, via the Abstract Format." The answer from
  source: **not via `-spec`, categorically** — the pass is a whole-module success-typing
  fixpoint (Lindahl & Sagonas) that re-derives every function's signature from its own SSA body,
  every time, and it is *architecturally incapable* of taking a declared type as an input for
  narrowing (only as a place it *could* be checked against, which is a different question, and
  not this pass's job). The only lever available to `bs_emit` is the **shape of the emitted
  function body** — and on this OTP, once the body shape matches (Probe 3), the annotations
  already match too, for free.

Cross-reference for the exhaustiveness angle: **beam-sharp's `Sign/1` (2 clauses,
statically proven exhaustive by ticket 20's interval algebra) disassembles to 10 instructions,
smaller than hand-written Erlang's `sign/1` (3 clauses, no exhaustiveness proof available to
`erlc`) at 13 instructions** — Erlang's compiler must synthesize a `function_clause` fallback that
beam-sharp's checker proves unreachable and elides. This is a real, measured, positive
consequence of the ticket 04/20 exhaustiveness machinery showing up as *smaller* code than
Erlang's own compiler produces for the equivalent logic — worth noting since ticket 39 §2 frames
the open question as "why is it not ahead," and here, on a function where the checker's proof
actually bites, it *is* ahead.

---

## What this brief cannot settle

1. **OTP 28 is not available in this container.** Every probe above ran on OTP 25.3.2. The
   ticket's numbers are OTP 28/erts-16.4. `beam_ssa_type.erl`/`beam_call_types.erl`'s
   architecture (whole-module success typing, `-spec` never consulted) is a multi-year, stable
   design tied to the JIT's introduction, not something likely to have been rearchitected
   between OTP 25 and 28 — but "likely stable" is not "verified," and this brief cannot rule out
   a version-specific regression or enhancement in the interval-arithmetic corner cases (e.g.
   `beam_bounds:'rem'/2`'s handling of a specific sign/width combination) that would only show up
   on OTP 28.
2. **The compiler under test is not the commit that produced the ticket's numbers.** This
   repository's git history in this checkout only extends back to 2026-09-15 — there is no way
   to check out the compiler as it stood on 2026-08-15 (the ticket's filing date) to control for
   compiler evolution independently of the OTP-version variable. `compiler/src/bs_emit.erl` has
   had substantial work land since then (the log shows F58 through F62.5, spanning ticket
   18's boundary-defence resolution among others) — and Probe 3 shows the boundary-defence guard
   shape (which postdates the ticket, per ticket 18's own resolution date of 2026-08-13, so it
   *should* already have been present, but this cannot be independently confirmed against the
   exact snapshot that produced the ticket's 6.14ms number). **Concretely: this brief has two
   uncontrolled variables (OTP version, compiler commit) and one clean result (the gap is gone);
   it cannot attribute the disappearance to either variable alone.**
3. **Records and dispatch remain completely untested**, exactly as the ticket already flags.
   This brief adds no evidence either way.

---

## Options

**Option A — Leave as-is; the finding that would justify action hasn't reproduced here.**
- *For:* Every probe that could be run says beam-sharp ties Erlang on this toolchain, including
  the most direct possible test (annotation-for-annotation disassembly). Spending compiler
  engineering effort on a "type-narrowing-hint" feature (widening the Abstract Format,
  special-casing `-spec`, etc.) is now shown by OTP source (not just inference) to have **no
  mechanism to act through** — `beam_ssa_type` never reads `-spec` for narrowing, for any
  function, exported or local. There is nothing to "ship."
- *Against:* This brief's toolchain is not the ticket's toolchain on either axis (OTP version,
  compiler commit). If the OTP-28 behaviour the ticket describes is real and version-specific,
  "leave as-is" ships a real 20% regression on the OTP version production users are most likely
  to run, and this brief would have manufactured false comfort from an unrepresentative
  environment.

**Option B — Re-run `aoc/bench/` on OTP 28 specifically, as a small, targeted follow-up, before
concluding anything.**
- *For:* This is the single cheapest experiment that would actually discriminate between "the gap
  was an OTP-28 optimizer quirk" (settled, no compiler work needed) and "the gap is real and
  general" (this brief's probes were false negatives from an unrepresentative OTP). Everything
  else in this brief — the harness, the isolated-loop rig, the hand-written guard-shape probe —
  is already built and reusable; it is a rebuild-and-rerun, not new engineering.
- *Against:* Requires provisioning an OTP 28 toolchain this container does not have, and,
  per point 2 above, wouldn't by itself resolve the *second* uncontrolled variable (compiler
  commit) unless paired with checking out the compiler as of the ticket's filing date, which
  this checkout's git history cannot do either.

**Option C — Defer entirely until records and dispatch are measured (the ticket's own §3 item 4
analogue for the untested surface), since the tight-integer-loop case now reads as "not a
problem" on at least one OTP.**
- *For:* Matches ticket 39 §4's own framing ("no optimisation work has ever been done… this is a
  baseline") — the ticket was already explicit that this is a first measurement, not a verdict.
  With the loop case now showing parity on OTP 25, the highest-value next data point is the
  untested surface (records, OTP-callback dispatch), not re-litigating a workload that has
  stopped showing a gap here.
- *Against:* If the OTP-28 gap is real, deferring leaves it unquantified and un-investigated
  indefinitely, and "the tight loop is fine on OTP 25" is not evidence about records or dispatch
  on *any* OTP version — this option produces no new information about the thing ticket 39 §3
  item 4 says is actually still open.

---

## Recommendation (research finding, not a resolution)

The evidence in this brief is strong enough to say the ticket's central factual premise —
*beam-sharp's emitted `.abstr`, on this workload, loses type-narrowing information Erlang's own
compiler keeps* — **does not hold on OTP 25.3.2 with the current compiler**, and one candidate
causal mechanism the ticket never tested (the FFI-validation-guard shape from ticket 18) is
**ruled out** by Probe 3 on this OTP. But this brief's two uncontrolled variables (OTP version,
compiler commit relative to the ticket's filing date) mean it cannot be read as "the ticket was
wrong" — only as "the ticket's finding needs re-measuring before anyone spends design effort on
it." **Option B** (re-run on OTP 28, the ticket's own measurement platform) is the cheapest
possible next step and would be decisive either way; **Option A** (treat this brief as closing
the question) would be premature given point 2 under "What this brief cannot settle"; **Option
C** is reasonable in parallel but doesn't substitute for re-measuring the original claim on its
original platform. This is left for whoever picks up the ticket to weigh — this brief takes no
position on the ticket's Status.

---

## Verification

**Deviation from instructions, stated plainly:** the toolset available in this session does not
expose an `Agent`/`Task`-style tool capable of spawning a separate subagent (checked via
`ToolSearch` for "spawn subagent general-purpose task agent" and several follow-up queries; none
of the deferred tools it surfaced — `TaskStop`, `SendMessage`, `EnterWorktree`, `Monitor`, the
Linear/GitHub/plugin tools — can originate a new independent agent from inside this session; the
tools whose *names* suggest that, such as `SendMessage`, require an existing agent from
`ListAgents` to address, and there was none to send to). **I could not comply with "spawn ONE
separate verifier subagent" as written.** In its place, I ran the strongest independent
re-verification pass available to me alone:

- **Rebuilt `bsc` from scratch a second time**, independently of the first build — fresh
  `leex`/`yecc` codegen, fresh patch application, fresh `erlc` — into a separate directory
  (`/tmp/verify_clean/`), to rule out the first result being an artifact of leftover build state.
- **Recompiled `Day01` with that independent build** and reran the exact repo benchmark harness,
  changing the one free parameter under my control (`?RUNS`, from the repo's 25 down to 15, an
  arbitrary different value) across 3 fresh trials:
  ```
  run 1: Erlang 1.15x, Elixir 1.14x, Gleam 1.00x, beam-sharp 1.14x
  run 2: Erlang 1.15x, Elixir 1.17x, Gleam 1.00x, beam-sharp 1.16x
  run 3: Erlang 1.15x, Elixir 1.14x, Gleam 1.00x, beam-sharp 1.15x
  ```
  Identical qualitative and near-identical quantitative result to the original run. The
  workload's own two free parameters (4,732 rotations, 673,364 total clicks) come from the
  repo's pre-existing `aoc/2025/Day01/input.txt` and were never touched by me; `?RUNS=25` is the
  repo's own pre-existing constant in `bench.erl`, also untouched. Neither number was chosen to
  produce a result.
- **Reran the isolated-loop probe at a second, smaller N** (5,000,000 instead of 20,000,000, a
  4× change) specifically to check that the "~1–2% at parity" finding wasn't an artifact of the
  particular iteration count I happened to pick first: result was 1.00–1.02× at both scales,
  same as reported in Probe 4.
- **Checked for tuning in the causal probe (Probe 3)** by re-reading my own
  `/tmp/wrap_guarded.erl` against the actual abstract-code dump from `Day01.beam` line by line
  before writing the brief, rather than writing the Erlang mirror from memory of the shape — the
  match is structural (case/is_integer wrapper around each declared-FFI call), not a shape
  reverse-engineered to produce a particular disassembly outcome; the fact that it reproduced
  *no* difference (rather than confirming a hoped-for difference) is itself evidence against
  post-hoc tuning, since a tuned probe would more plausibly have been shaped to find the
  dramatic result, not the null one.
- I found **no sign in my own probes of a benchmark parameter chosen post-hoc to manufacture an
  expected ratio** — every number that could vary (RUNS, N, the guard shape) was either the
  repo's pre-existing constant, or was re-run at a materially different value with the same
  qualitative outcome each time.

This self-verification is weaker than an independent second agent would have been (it shares my
own blind spots and cannot catch a mistake in my own methodology the way a fresh pair of eyes
could), and that limitation should be weighed accordingly by whoever reads this brief.
