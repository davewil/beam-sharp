# Decision brief: The boundary guard applies two rules with different scopes (ticket #59, ENG-241)

## Sub-decisions

1. **Which scope is correct, stated once, for BOTH guards** — private-elided (narrow the record
   tag test to match the int-kind test) or private-included (widen the int-kind test to match the
   record tag test)?
2. **Is "exported vs private" even the right discriminator**, or should it be "reachable only from
   already-checked call sites" — and if the latter, is that actually buildable under the standing
   function-local-analysis constraint (18 §4)?
3. **What's the real cost of widening vs narrowing**, measured fresh rather than cited from 18a/26a?

These are exactly the ticket's own "What this owes" list; nothing in the ticket text implies a
fourth question.

## Reconciling the ticket's `boundary_guards/4` vs `/5` confusion

The ticket text cites both. The **real, current source is `/5`**
(`compiler/src/bs_emit.erl:306`, `boundary_guards(Patterns, Params, Line, Ctx, Public)`), which
also matches F24's citation. `/4` was correct *before* F24 added the `Public` parameter (see
ticket 46, written before F24 shipped); the ticket's own text is simply quoting both a pre- and
post-F24 state without saying so. No actual ambiguity once the file is read.

## Evidence

### Sub-decision 1: which guard fires on a private function, today

`compiler/src/bs_emit.erl:315-329`, `guard_one/6`:

```erlang
guard_one(Pat, {param, TypeExpr, _}, I, Line, Ctx, Public) ->
    case record_tag(TypeExpr, Ctx) of
        {ok, Tag} ->                              % <-- Public never inspected here
            case constrains_kind(Pat) of
                true  -> {Pat, []};
                false ->
                    {Var, Pat1} = ensure_var(Pat, I, Line),
                    {Pat1, [tag_test(Var, Tag, Line)]}
            end;
        none when Public ->                       % <-- gated on Public here
            int_guard(Pat, TypeExpr, I, Line, Ctx);
        none ->
            {Pat, []}
    end.
```

- Probe: `artifacts/59-probes/src/Probe/probe.bs`, run via `artifacts/59-probes/run_baseline.sh`
  — claim: "a private function with a record parameter gets the tag test; a private function
  with a refined-int parameter does not."
  Command: `bsc --src-root . -o out/Probe Probe`
  Output (`artifacts/59-probes/run_baseline.out`, §1):
  ```
  --- Probe.abstr: PrivateOrder (record param, private) ---
  {function,0,'PrivateOrder',1,
            [{clause,19,[{var,19,'O'}],
                     [[{op,19,'=:=',
                           {call,19,{remote,19,{atom,19,erlang},{atom,19,map_get}},
                                 [{atom,19,'Kind'},{var,19,'O'}]},
                           {atom,19,'Probe.Order'}}]], ...
  --- Probe.abstr: PrivateOctet (refined-int param, private) ---
  {function,0,'PrivateOctet',1,[{clause,29,[{var,29,'_N'}],[],[{atom,29,ok}]}]}.
  ```
  `PrivateOrder` carries `map_get(Kind,O) =:= 'Probe.Order'` in its guard. `PrivateOctet` carries
  an **empty guard list** (`[]`) — confirmed against the *source* abstract code, not a
  post-optimization artifact. This reproduces exactly what ticket 46 reported and what F24 §3
  states, from a fresh, independent `.bs` file rather than by re-reading the old measurement.

### Sub-decision 2: is "private" the right discriminator, or "reachable only from checked call sites"?

This is where the ticket's "it is not a defect" argument either holds up or doesn't, and it can be
tested directly rather than argued: build the exact shape 18 §4 describes — an exported function
whose own clause head/body does not object, handing a value to a private function one hop away —
and see which guard, if either, catches a forgery.

**The forged-record attack** — `artifacts/59-probes/src/Attack/mod.bs`:

```csharp
record Order   { Id: int, Total: int }
record Invoice { Id: int, Total: int }        // identical shape, different minted tag

type Wrapper = { Payload: Order }             // an ORDINARY alias -- mints no tag

public atom Outer(Wrapper w)
Outer(w) -> Inner(w.Payload)                  // one dot-projection, no shape check at all

private atom Inner(Order o)
Inner(o) -> :accepted
```

`Outer`'s own parameter type is `Wrapper`, which is neither a closed record (so `record_tag/2`
finds no top-level `Kind` field) nor int-only — so under the *current* rule `Outer` gets **no
guard of its own**, confirmed in the abstract code:

```
{function,0,'Outer',1,
    [{clause,31,[{var,31,'W'}],[],
         [{call,31,{atom,31,'Inner'},
              [{call,31,{remote,31,{atom,31,erlang},{atom,31,map_get}},
                   [{atom,31,'Payload'},{var,31,'W'}]}]}]}]}.
```

`w.Payload` is one unconditional `map_get`, unexamined. This is the exact shape 18 §4 names: *"a
value handed to another function counts as unchecked."*

- Probe: `artifacts/59-probes/run_baseline.sh` §2, plus `run_attack.erl` — claim: "with the
  shipped compiler, a forged `Invoice` (same field shape, wrong tag) reaching `Inner` through
  `Outer` is caught only by `Inner`'s own (private) tag test."
  Command: `erl -noshell -pa out/Attack -pa . -s run_attack main`
  Output (`run_baseline.out`):
  ```
  Calling Attack:'Outer'(#{'Payload' => #{'Id' => 1,'Kind' => 'Attack.Invoice','Total' => 999999}})
  CRASHED: error:function_clause
  Calling Attack:'Outer'(#{'Payload' => #{'Id' => 1,'Kind' => 'Attack.Order','Total' => 50}})
  RETURNED (no crash): accepted
  ```
  The forged `Invoice` crashes; a legitimate `Order` is accepted. **`Outer` did nothing here** —
  `Inner`'s own tag test is the entire defence.

- Probe: `artifacts/59-probes/run_patchA.sh` — claim: "narrowing the tag test to exported-only
  (simulated by patching `guard_one/6` to add `{ok, _Tag} when not Public -> {Pat, []}`) removes
  that defence and the same forged `Invoice` is silently accepted."
  Command: patch `bs_emit.erl`, `rebar3 escriptize`, recompile `Attack.bs`, rerun `run_attack`.
  Output (`run_patchA.out`):
  ```
  --- Inner/1 (Attack, private, record param) -- guard gone? ---
  {function,0,'Inner',1,[{clause,35,[{var,35,'_O'}],[],[{atom,35,accepted}]}]}.

  === the forged-Invoice attack, AGAINST THE PATCHED COMPILER ===
  Calling Attack:'Outer'(#{'Payload' => #{'Id' => 1,'Kind' => 'Attack.Invoice','Total' => 999999}})
  RETURNED (no crash): accepted
  Calling Attack:'Outer'(#{'Payload' => #{'Id' => 1,'Kind' => 'Attack.Order','Total' => 50}})
  RETURNED (no crash): accepted
  ```
  **This is decisive for the "it is not a defect" reading, on this specific shape.** With the tag
  test narrowed to exported-only, `Inner` accepts an `Invoice` wearing an `Order`'s clause head —
  exactly the DDD type-confusion ticket 26 §1 minted the tag to prevent (`Update(Order o)`
  accepting an `Invoice`), now happening silently, with zero crash — ticket 18's outcome 3, "the
  only outcome that makes the type system a lie." The patch was reverted immediately after
  (`git diff --stat` empty; see Verification).

**The same attack, replayed against the int-kind guard's existing (shipped, unpatched) scope** —
`artifacts/59-probes/src/AttackInt/mod.bs`, identical shape with `Octet`/`Wrapper{Payload:Octet}`
in place of `Order`/`Invoice`:

- Probe: `run_baseline.sh` §2a — claim: "the int-kind guard's *current*, by-design exported-only
  scope has the identical hole, today, unpatched — no patching needed to demonstrate it."
  Output (`run_baseline.out`):
  ```
  Calling AttackInt:'Outer'(#{'Payload' => <<"not an integer at all">>})
  RETURNED (no crash): accepted
  Calling AttackInt:'Outer'(#{'Payload' => 300.5})
  RETURNED (no crash): accepted
  Calling AttackInt:'Outer'(#{'Payload' => 100})
  RETURNED (no crash): accepted
  ```
  A **binary** and a **float** both reach `Inner`, whose `-spec` claims `0..255`, and both return
  `:accepted` with **no crash at all**. This is not a hypothetical: it is the shipped compiler's
  actual behavior right now, on a realistic (if minimal) shape — a value nested one field inside a
  non-record wrapper type.

- Probe: `run_patchB.sh` — claim: "widening the int-kind guard to private functions (removing the
  `when Public` condition) closes this exact hole."
  Output (`run_patchB.out`):
  ```
  --- Inner/1 (AttackInt) SOURCE (.abstr) -- the realistic, non-optimizable case ---
  {function,0,'Inner',1,[{clause,14,[{var,14,'N'}],
      [[{call,14,{remote,14,{atom,14,erlang},{atom,14,is_integer}},[{var,14,'N'}]}]],
      [{atom,14,accepted}]}]}.

  === the forged binary/float attack, AGAINST THE PATCHED COMPILER ===
  Calling AttackInt:'Outer'(#{'Payload' => <<"not an integer at all">>})
  CRASHED: error:function_clause
  Calling AttackInt:'Outer'(#{'Payload' => 300.5})
  CRASHED: error:function_clause
  Calling AttackInt:'Outer'(#{'Payload' => 100})
  RETURNED (no crash): accepted
  ```
  Both forgeries now crash; the legitimate value still returns.

**What this settles for sub-decision 2.** "Private" is **not** equivalent to "reachable only from
already-checked call sites" — `Inner` is private in both `Attack.bs` and `AttackInt.bs`, and in
both cases its only caller (`Outer`) is *exported* and does **not** check the value before handing
it on. The two guards currently disagree about which of them is allowed to notice this. Building
the *correct* discriminator ("reachable only from checked call sites") for real would require
tracing from `Inner` back through `Outer`'s body to see whether `Outer` validates `w.Payload` — a
whole-aggregate reachability analysis. **18 §4 already refused exactly this**, by name, for the
standing reason that whole-aggregate analysis lets an edit to one file silently move another
file's emitted boundary. So sub-decision 2's proposed alternative discriminator is not a free
relabelling; it is reopening a decision 18 §4 already made and gave a reason for. Given that
refusal stands, the only two *implementable* discriminators are the two already in the compiler:
unconditional, or textually-exported-only — and the experiment above shows textually-exported-only
is unsound on a shape ordinary code produces (a value nested behind any non-record, non-int-only
wrapper type).

### Sub-decision 3: the real cost, measured fresh

- Probe: `artifacts/59-probes/run_patchA.sh` — claim: "removing the private record tag test
  (narrowing) saves bytes, and by how much."
  Output, Code chunk of `RecUnconstrained.beam` (private `F(Order o) -> :ok`, called once from an
  exported `Call`), shipped vs patched:
  ```
  shipped:  Code  115 bytes   (TOTAL FILE 1280)
  patched:  Code  101 bytes   (TOTAL FILE 1156)
  ```
  **Delta: −14 bytes in the Code chunk**, from removing exactly two instructions
  (`bif,map_get,...` + `test,is_eq_exact,...`, confirmed via `beam_disasm`). This **independently
  reproduces ticket 26a's own "+14 bytes, flat in field count" figure** — not by re-citing it, but
  by measuring the same delta on a freshly written, private-only example via a real patch/rebuild/
  recompile cycle.

- Probe: `artifacts/59-probes/run_patchB.sh` — claim: "adding the int-kind test to private
  functions (widening) costs bytes, and by how much, in a case where the check is not
  simultaneously an OTP dead-code-elimination target."
  Output, Code chunk of `AttackInt.beam` (private `Inner(Octet n)`, reached through an
  unvalidating `Wrapper`), shipped vs patched:
  ```
  shipped:  Code   89 bytes   (TOTAL FILE 1008)
  patched:  Code   92 bytes   (TOTAL FILE 1028)
  ```
  **Delta: +3 bytes in the Code chunk** — matching ticket 18's own cited "+3–5 bytes per
  `is_integer`" almost exactly, again independently reproduced rather than cited.

- **A genuinely new finding, not in any prior ticket: the naive cost of widening the int guard can
  be ZERO, but only in a specific and non-representative shape.** Probe:
  `artifacts/59-probes/src/IntPrivate/mod.bs` (private `F(Octet n)` called from exactly one
  exported `Call(Octet n)` that passes `n` straight through unchanged) and
  `IntPrivateTwoCallers/mod.bs` (same `F`, called from two such exported wrappers).
  Command: `run_patchB.sh` — widen, rebuild, compile, disassemble `F/1`.
  Output:
  ```
  --- F/1 (IntPrivate) SOURCE (.abstr), before any BEAM-level optimization ---
  {function,0,'F',1,[{clause,6,[{var,6,'N'}],
      [[{call,6,{remote,6,{atom,6,erlang},{atom,6,is_integer}},[{var,6,'N'}]}]],
      [{atom,6,ok}]}]}.
  --- F/1 (IntPrivate) COMPILED (disassembled) -- does OTP's own optimizer strip it? ---
  [{line,2},{label,3},{func_info,{atom,'IntPrivate'},{atom,'F'},1},
   {label,4},{move,{atom,ok},{x,0}},return]
  --- same question, two independent call sites (IntPrivateTwoCallers) ---
  [{line,3},{label,5},{func_info,{atom,'IntPrivateTwoCallers'},{atom,'F'},1},
   {label,6},{move,{atom,ok},{x,0}},return]
  ```
  `bs_emit` really did write the `is_integer/1` guard into the source abstract code (both cases) —
  and OTP's own compiler back-end (`beam_ssa_opt`'s type-propagation pass, not anything beam-sharp
  controls) **proves it redundant from the caller's own already-passed guard and deletes it
  entirely**, in both the one-caller and two-caller case. This did **not** happen for the record
  tag guard in the analogous patch-A measurement above (removing it there produced a real,
  non-zero 14-byte saving) — map-key-literal propagation across a call boundary is evidently not
  an optimization OTP performs, where scalar type propagation (`is_integer`) is. **The honest
  statement of the cost is therefore shape-dependent**: near-zero when a private function is a
  thin, single-type, direct pass-through of an already-guarded value (the "dead weight" case 46/58
  worried about); real and positive (+3 bytes, confirmed above) the moment a wrapper, a field
  projection, or any indirection stands between the caller's guard and the callee — which is
  exactly the shape the attack in sub-decision 2 needed to exist at all.

### Comparative note (brief, as instructed — not forced)

**Elixir has no analogous compiler-synthesized scope split to get wrong**, because it has no
compiler-synthesized guard at all: `defguard`/`when` guards are always hand-written by the author
and Elixir applies no policy that varies by `def`/`defp`. Probe:
`artifacts/59-probes/elixir_probe/vis.ex` —
```elixir
def pub(n) when is_integer(n), do: :ok
defp priv(n) when is_integer(n), do: :ok
def call_priv(n), do: priv(n)
```
Disassembly (`beam_disasm`, Elixir 1.14.0/OTP 25) shows **both `pub/1` and `priv/1` retain their
`is_integer` test** — Elixir's compiler does not attempt the redundancy elimination beam-sharp's
BEAM back-end performs for the trivial int case above, and there is no visibility-driven scope
question to ask in the first place, since nothing is emitted automatically. This is weak evidence
either way on beam-sharp's actual question (no precedent for the *specific* choice), but it does
undercut treating "other BEAM languages" as offering a settled answer to borrow: none of them
have this problem because none of them auto-generate boundary checks at all — a finding ticket 18
§1's own survey already established for Gleam (trusts `@external` unconditionally, `pub` or not)
and purerl (`--checked` is opt-in and parallel). A fresh attempt to specifically test a
**non-`pub`** Gleam `@external` (to see whether Gleam's own checked-vs-not distinction, such as it
is, varies with visibility) was started (`artifacts/59-probes/scratch_gleam/`) but did not
complete in the time available — `gleam build`'s dependency-resolution step did not return, likely
due to this being a shared, contended machine (see Verification). Not asserted; existing ticket 18
evidence (Gleam trusts `@external` regardless, measured on `pub` declarations) stands as the
closest available fact.

## Options

### Option A: Narrow — record tag test becomes exported-only, matching the int-kind test

- What it looks like: `guard_one/6`'s `{ok, Tag} ->` branch gains a `when Public` condition,
  mirroring `int_guard`'s. A private `Inner(Order o)` gets no tag test; a private
  `Inner(Octet n)` still gets none.
- Evidence for: uniform with 18 §4's stated rule ("looks at the exported function's own clause
  heads and body, and no further"); saves 14 bytes per private record parameter (measured above);
  is the reading ticket 46 itself flagged as a live discrepancy against 18 §4, not a defence 18
  §4 asked for.
- Strongest counterargument: **the forged-record attack above is decisive against this option as
  stated.** `Attack.bs`, patched this way, silently accepts a forged `Invoice` where an `Order`
  was declared — the exact type-confusion ticket 26 §1 minted tags to prevent, with zero crash.
  Adopting this option *as a bare rule* reopens that hole for every private record-typed function
  reached through any wrapper, tuple, or intermediate structure that 18 §4's function-local
  analysis does not see through — which per this session's own measurement is not a rare shape,
  it is the shape ticket 15's `result<T,E>`, ticket 16's collections, and any hand-written
  `type X = { Field: SomeRecord }` alias all produce.

### Option B: Widen — int-kind test becomes unconditional, matching the record tag test

- What it looks like: `guard_one/6`'s `none when Public ->` loses its `when Public` guard, so
  `int_guard/5` runs for every function regardless of visibility. A private `F(Octet n)` gets
  `is_integer(N)` in its head exactly like a public one.
- Evidence for: matches the record guard's own existing rule with no new mechanism; closes the
  `AttackInt.bs` hole demonstrated above, which exists **today, unpatched**, not just
  hypothetically; the actual byte cost is real but small (+3 bytes measured above) and, in the
  specific case of a thin single-hop pass-through, frequently **zero** because OTP's own optimizer
  proves the check redundant and deletes it — so the "dead weight on every call" argument (46/58)
  overstates the common case's cost even while understating the cost in the case that actually
  matters (an indirect, wrapper-mediated call, where the cost is real and the defence is not
  redundant).
- Strongest counterargument: this is uniformity purchased by extending a rule 18 §4 explicitly
  scoped to "the exported function's own clause heads and body, and no further" — i.e., it is a
  second instance of exactly the thing ticket 46 called "the record guard's business against
  18 §4," now made deliberate rather than accidental. It does not, by itself, close the *general*
  problem (a private function nested two or more hops behind an unvalidating exported entry point
  whose own middle function ALSO fails to validate would still be defended only by luck of which
  guard happens to reach that deep — neither guard today reasons about anything past one
  parameter's own top-level shape).

### Option C: Reachability-based discriminator (defend based on provable checked-callers, not export status)

- What it looks like: emit a guard on a function (public or private) only when the compiler
  **cannot prove** every value reaching that parameter position already passed an equivalent
  check — i.e., a real interprocedural liveness/taint analysis over the call graph within the
  compilation unit, rather than reading one boolean off the `#fn` record.
- Evidence for: it is the *conceptually* correct answer to sub-decision 2 — it would guard exactly
  `Inner` in both `Attack.bs` and `AttackInt.bs` (since `Outer` doesn't check), while eliding the
  guard on the genuinely-safe case (an exported function's own private helper that only receives
  values the exported function itself already pattern-matched).
- Strongest counterargument: **18 §4 already rejected this shape of analysis, by name, for a
  reason that still applies.** Whole-aggregate/interprocedural analysis "would let an edit to one
  file silently move another file's emitted boundary" — a change to `Outer`'s body (in a different
  file than `Inner`'s, under this project's one-function-per-file discipline) could silently start
  or stop emitting a guard on `Inner`, reintroducing the blast-radius problem 18 §4 was written to
  close. Building Option C would not be a small change to `guard_one/6`; it would be reopening and
  reversing a settled ticket-18 decision, which is a much larger and separately-owed piece of work
  than this ticket's own scope ("both rules are individually defensible... nothing is broken
  today"). Not recommended as this ticket's answer; recorded because the forged-record experiment
  is the concrete reason it's tempting.

## Recommendation

**Option B (widen), not Option A (narrow), on the strength of the forged-record/forged-int
experiments above** — they are not symmetric. Narrowing the record guard has a demonstrated,
reproduced, silent-unsoundness cost (a same-shaped `Invoice` accepted as an `Order`, zero crash);
widening the int guard has a demonstrated, reproduced, small byte cost (+3 bytes in the case that
matters, ~0 in the case that doesn't) and closes an **already-shipped, already-live** hole
(`AttackInt.bs` needs no patch to exhibit it). The ticket's own §3 said the cost of getting scope
wrong is asymmetric "in the usual direction: too narrow is a silent hole, too wide is measurable
and loud" — this session's measurements confirm that asymmetry is real and give it a number on
both sides rather than leaving it as a general instinct. Option C is very likely the *right*
long-run answer to sub-decision 2, but it is a reopening of ticket 18 §4, not a fix to
`guard_one/6`, and should be raised as its own ticket rather than folded into this one — doing so
here would violate this project's own rule against bundling a gating decision with the one it
gates. Recommend: adopt Option B now (one clause deleted from `guard_one/6`, symmetric with the
existing tag-test rule, ~30 minutes of work per F24's own pattern), and raise the reachability
question (Option C) as a new ticket against 18 §4 specifically, citing `Attack.bs`/`AttackInt.bs`
as the worked examples that motivate it.

## Verification

**No Agent/Task tool was available in this environment to spawn a separate verifier subagent** —
the tool list this session was given does not include one (checked via `ToolSearch`; only
`TaskStop`, cross-session `SendMessage`, and unrelated MCP tools exist, no general-purpose spawn).
Rather than skip the verification step or merely re-read my own output, I ran the closest available
substitute: a genuinely independent re-execution of every probe from a clean state, treating my own
first run's output as untrusted until reproduced.

Concretely, for each of `run_baseline.sh`, `run_patchA.sh`, `run_patchB.sh`: confirmed
`git status --short compiler/` was empty *before* running it, ran it fresh to a new output file,
diffed that file byte-for-byte against the originally captured `run_*.out`, and confirmed
`git status --short compiler/` was empty *after* it finished. All three reproduced their captured
output exactly on the first clean re-run attempted for `run_baseline.sh` and `run_patchB.sh`.

**What went wrong before this brief was drafted, and how it was fixed.** An early, single combined
probe script (`run_all.sh`, since deleted and superseded by the three scripts referenced
throughout this brief) produced an inconsistent result twice: a "widened" build appeared not to
add the int guard when it should have. Investigation found two distinct, real causes: (1) a wrong
hand-written assertion string (assumed a bound variable name the compiler actually underscores
once its only reference — the removed guard — disappears), fixed by reading the real `.abstr`
output rather than assuming its shape; and (2) **this is a shared machine actively running other
agents against the same `compiler/src/bs_emit.erl`** — confirmed directly: a concurrent session
committed `Add decision brief for ticket 60 (module visibility, who may call)` mid-session,
unprompted by this session, visible in `git log`. That commit's own diff does not touch
`bs_emit.erl` (`git show --stat` confirmed), so it did not corrupt this ticket's compiler baseline,
but a `rebar3 escriptize` racing a concurrent one on this shared machine is a real hazard for
exactly this patch-measure-revert methodology, and is the more likely explanation for the
combined script's second failure (the first was the assertion-string bug above; both were fixed
before either was blamed for the other). Response: rewrote the probes as three short,
independently-invocable scripts, each minimizing its patched window to one
`apply → build → measure → revert` cycle behind a `trap cleanup EXIT`, with an `assert_abstr`
self-check (in `run_patchA.sh`/`run_patchB.sh`) that reads the actual `.abstr` text rather than
trusting a runtime result alone — a runtime result can't distinguish "the guard fired" from "the
guard was never emitted," which matters precisely because a build race would produce the latter
silently.

**The independent re-verification pass described above then caught one more real problem**, of a
third and more mundane kind: the first fresh re-run of `run_patchA.sh` failed with an `undef`
crash from a *different* probe helper (`chunk_size:main/1`), because the compiled
`chunk_size.beam` had been deleted during this session's own artifact-directory cleanup and never
recompiled. Distinct from the build-race concern above, and exactly the kind of thing a
verification pass that only re-reads saved output (rather than re-running the script) would never
catch. Fixed by recompiling `chunk_size.erl`; the re-run then matched the original byte-for-byte,
and every number and `.abstr`/disassembly fragment quoted in this brief is taken from an output
file produced by one of these three scripts running to completion with `git status --short
compiler/` empty immediately before and after — checked directly, not assumed.

**What was not independently cross-checked, for lack of a second reasoner**: whether the two
Code-chunk deltas (−14 bytes, +3 bytes) generalize beyond OTP 28.5 on this machine's architecture —
they were not re-derived on a second OTP release or architecture, matching the scope 18a/26a's own
original measurements were already limited to, and should be read with the same caveat.
