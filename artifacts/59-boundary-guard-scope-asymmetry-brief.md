# Ticket 59 — the boundary guard scope asymmetry: research brief

Status of this document: research only. It does not resolve ticket 59, does not edit
`wayfinder/issues/59-boundary-guard-scope-asymmetry.md`, and changes no `Status:` line. All
probes referenced below live under `artifacts/_probes/59/`; every claim about emitted code or
runtime behaviour was produced by actually compiling and running `bsc`, never asserted from
reading source alone.

## 0. What was actually run

- OTP 28.5, built locally at `/opt/otp28-src`.
- `bsc` built from an unmodified copy of `compiler/` at `/tmp/ticket59-scratch/compiler`
  (`rebar3 escriptize`, escript at `_build/default/bin/bsc`) — this is the "current" binary
  referenced throughout.
- A second `bsc`, built from the same copy after one scratch patch to `bs_emit.erl`
  (`artifacts/_probes/59/59c_narrow_patch.diff`) — this is the "narrowed" binary, used only to
  demonstrate what the narrow option would do. **This patch was never applied to the tracked
  tree**; it exists only in `/tmp/ticket59-scratch`.
- The code read directly: `compiler/src/bs_emit.erl`, `guard_one/7` (lines 262–278) and
  `int_guard/6` (lines 327–343), and the header comments at lines 239–250 and 310–325.

## 1. The asymmetry, confirmed directly in the code and in real output

`bs_emit:guard_one/7` is the single place both guards are decided:

```erlang
guard_one(Pat, {param, TypeExpr, _}, Accept, I, Line, Ctx, Public) ->
    case record_tag(TypeExpr, Ctx) of
        {ok, Tag} ->                              % <-- NO Public check here
            case constrains_kind(Pat) of
                true  -> {Pat, []};
                false -> {Pat1, [tag_test(Var, Tag, Line)]}
            end;
        none when Public ->                       % <-- Public IS checked here
            case kind_only(TypeExpr, Ctx) of
                float -> float_guard(Pat, I, Line);
                _     -> int_guard(Pat, TypeExpr, Accept, I, Line, Ctx)
            end;
        none ->
            {Pat, []}
    end.
```

`Public` is threaded through to every call site and is read exactly once outside this branch —
it is not that the tag branch cannot see it, it simply never asks.

**Reproduced with a real compile** (`artifacts/_probes/59/src/Probe59/probe59.bs`, one private
record-taking function and one private refined-int-taking function, each with a public wrapper
that does nothing but forward the same value):

```
$ bsc --src-root . -o out Probe59
```

Emitted forms (`artifacts/_probes/59/out/Probe59.abstr`):

| function | visibility | parameter | emitted guard |
|---|---|---|---|
| `InnerRecord/1` | **private** | `Order` | `map_get('Kind', O) =:= 'Probe59.Order'` |
| `InnerOctet/1` | **private** | `Octet` (`0..255`) | *(none — bare pattern, empty guard list)* |
| `OuterRecord/1` | public | `Order` | same tag test |
| `OuterOctet/1` | public | `Octet` | `is_integer(N) andalso N>=0 andalso N=<255` |

This is exactly ticket 46's finding, reproduced independently at `2b97180`-successor code: the
tag test does not consult `is_public/1` and the private function receives it anyway; the kind
test does.

## 2. Cost, remeasured independently

Method: `artifacts/_probes/59/59a_asymmetry_cost.erl`, deliberately built to the same discipline
as `18a_guard_cost.erl` / `26a_record_erasure_cost.erl` — one function (`amt/1`) plus
`module_info` per module, equal-length module names within a pair, `deterministic` compile, a
byte-identical noise-floor pair, `beam_lib:chunks/2` for the `Code` chunk. Guard bodies are
copied verbatim from what `bsc` actually emitted in §1, not reinvented. Full output:
`artifacts/_probes/59/59a_output.txt`.

| pair | `.beam` file | **`Code` chunk** | instrs |
|---|---|---|---|
| noise floor | +0 (0.0%) | +0 (0.0%) | +0 |
| **TAG test** (the record guard, as emitted on `InnerRecord/1`) | +24 (4.3%) | **+14 (19.2%)** | +3 |
| **KIND+RANGE test** (the full `Octet` guard, as emitted on `OuterOctet/1`) | +28 (5.3%) | **+16 (23.9%)** | +3 |
| KIND alone (`is_integer` on a plain `int`, no refinement) | +4 (0.8%) | **+3 (4.5%)** | +1 |

**Agreement with the cited figures**: exact. The tag test measured here is +14 bytes of `Code`,
identical to 26a's cited "+14 bytes, flat in field count" for the tagged-map discriminator. The
kind-alone test measured here is +3 bytes, at the low end of 18a's cited "+3–5 bytes per
`is_integer`". Neither remeasurement moved the number; both simply confirm it from a different
harness. The one new number is the *combined* kind+range guard bsc actually emits for a refined
`int` (+16 bytes) — F24/F37 never reported a byte figure for it, only a corpus insertion count
(34 guards, 9/15 modules), so this fills a real gap rather than contradicting anything.

**What this settles about §3 of the ticket ("the cost if the answer widens")**: widening the int
test to unconditional costs +16 bytes of `Code` per private `Octet`-typed parameter (or +3 for an
unrefined `int`); narrowing the tag test saves +14 bytes of `Code` per private record parameter.
The two are close enough (14 vs. 16) that neither direction has a decisive cost advantage over
the other — the ticket's own framing, "too narrow is a silent hole, too wide is measurable and
loud," is right that the costs are comparable and small; the decision has to be made on the hole,
not the bytes.

## 3. The forgery scenario, constructed and run — this is the crux

Ticket 59's "It is not" argument claims a forged record can reach a private function *by being
passed through an exported one*, because 18 §4's function-local analysis stops at the exported
function's own clause heads and does not trace values handed onward. This was constructed
directly rather than argued.

**The construction** (`artifacts/_probes/59/src/Probe59b/probe59b.bs`):

```csharp
module Probe59b

record Order { Id: string, Total: int }
type T = Order | int

int Inner(Order o)                    // PRIVATE
Inner(o) -> o.Total

public int Bump(T n)                  // EXPORTED, parameter is a UNION
Bump({ Total: t } n) -> Inner(n)
Bump(n)               -> 0
```

**Why this is the shape that matters, read from the actual emitted forms**
(`artifacts/_probes/59/outb/Probe59b.abstr`):

- `Bump`'s own parameter gets **no boundary guard at all**. `record_tag/2` only recognises "a
  single closed record" (it pattern-matches the resolved type against `ints := []`); a union
  with an `int` member fails that match and falls through to `none`. `int_guard` then requires
  `is_int_only`, which is also false for a union with a map part. So neither branch of
  `guard_one/7` fires — verified: `Bump`'s clause carries an empty guard list, `[]`.
- `Bump`'s clause pattern `{ Total: t } n` desugars to a **presence-only** Erlang map pattern,
  `#{'Total' := _T} = N` — no `Kind` key anywhere in it. Erlang map patterns match on presence of
  the listed keys and are silent about every other key, present or absent. This is the same
  idiom `examples/Shop/shop.bs`'s `Band({ Total: t })` already uses in the shipped corpus (there
  over a non-union `Order`, where it is harmless).
- The only thing that can possibly reject a forged value is **`Inner`'s own guard**.

**The probe** (`artifacts/_probes/59/59b_forgery_transcript.txt`): a hand-built Erlang map with
only a `Total` key — no `Kind`, no `Id` — simulating a foreign (non-`bsc`) caller, invoked with
`apply/3` exactly as the task specified:

```erlang
apply('Probe59b', 'Bump', [#{'Total' => 42}])
```

| build | `Inner/1`'s guard | result |
|---|---|---|
| **current bsc** (tag test unconditional) | `map_get('Kind', O) =:= 'Probe59b.Order'` | `crashed: error:function_clause` — **safe** |
| **narrowed bsc** (`artifacts/_probes/59/59c_narrow_patch.diff`, tag test exported-only) | *(none — Inner is private)* | `returned 42` — **silent unsoundness** |

This is not a hypothetical. It is ticket 06's outcome 3, live, on a program that is legal B#
today, using a pattern idiom the corpus already ships. Under the current (unconditional) scheme
it is safe *only because* the private callee's own tag test catches what the exported caller's
own boundary guard could not — which is exactly ticket 26 §1's argument ("no body ever checks
which record a map claims to be… the callee guards because the caller's analysis stopped at its
own boundary") stated in the ticket and now demonstrated rather than argued.

### A structural finding the ticket did not ask for, but that decides it

Why does the analogous attack not exist for the int/kind channel? Because **a map pattern admits
partial evidence and an int test does not.** `{ Total: t }` can be *true* of a value that is not
an `Order` at all (any map with a `Total` key), because Erlang map patterns are subset tests. There
is no equivalent "partial" test for `is_integer`: a value either passes it or it does not, and
F24 §6 (ENG-330) already closed the one place a *comparison*-based partial proof could stand in
for it (`n >= 0` narrowing a union member without pinning its kind). So narrowing the tag test to
match the int test's scope does not make the two guards symmetric in risk — it imports a
vulnerability class (partial structural evidence satisfying a full-identity claim) that the int
side was never exposed to in the first place, because ints have no partial pattern to exploit.
This is the asymmetry's actual root, one level below "18 §4 says exported, 26 §1 says always":
the two guards are cheap to state as parallel, but they defend against different-shaped attacks,
and only one of those shapes is reachable through a pattern that looks completely ordinary.

**A related, unbuilt gap this surfaces, out of scope for this brief but worth naming**: even
under the *current* unconditional scheme, `Inner`'s protection is incidental — it only exists
because `Inner`'s own declared parameter type happens to be a single closed record, so
`record_tag/2` fires on *its* boundary regardless of what `Bump` proved. A private helper that
instead took the whole union `T` (not `Order`) would get no guard from either mechanism, at any
setting of this ticket's decision, because `record_tag/2` never fires on a union. F24 §6 built a
narrowing-site fix for exactly this shape on the int channel (`apply_guard/3` intersecting with a
range at the point of narrowing, not at either function's own parameter); no equivalent exists
for the record channel. That is a new ticket's problem, not this one's, but a "narrow" resolution
of 59 should not be read as having covered it — it has not, in either direction.

## 4. Prior art — deliberately not forced

Per the task brief: no other BEAM language performs static boundary defence against forged FFI
terms at all, and ticket 18 already established this with direct measurement (Gleam's
`@external` publishing a false `-spec` for a value that arrives wrong-shaped,
`prototypes/10c_gleam_forge.erl`, `prototypes/18c_gleam_ffi_trust.gleam`; purerl's `--checked` is
off by default and admittedly partial). There is consequently no external precedent for *how* to
scope a guard between exported and private — the entire mechanism ticket 59 is arguing about does
not exist anywhere else on the platform to compare against. Re-deriving that finding here would
not add evidence; it is cited rather than reproduced, and no further cross-language survey was
attempted, per the task's own instruction not to manufacture relevance.

## 5. Sub-decisions implied

1. **Which scope is right, stated once, for both guards.** The two guards are not defending
   against symmetric risks (§3's structural finding), so "the same rule for both" is not free —
   whichever way this goes, it has to be justified per-guard, not by analogy from one to the
   other.
2. **Whether "exported" is the right discriminator at all.** 18 §1's finding that BEAM elision is
   exported-vs-local (one entry label) rather than local-call-vs-remote-call is unaffected by
   anything measured here — it is a fact about the runtime, not a policy choice, and both guards
   already live with it (an exported function pays its guard on every call, including from inside
   its own module). What is genuinely open is whether *private* should pay nothing, and §3 shows
   that for the tag test specifically, "private" is not the same claim as "every call site is a
   checked beam-sharp call site" the moment the *caller* is a union-typed exported function whose
   own clause pattern is a partial map test.
3. **The cost, both directions, now measured rather than cited**: narrowing the tag test saves
   +14 bytes of `Code` per private record parameter (confirms 26a); widening the int test costs
   +16 bytes of `Code` per private refined-int parameter, or +3 for a plain `int` (confirms/fills
   in 18a). The two are close enough that cost is not the deciding factor either way.

## 6. Options

### Option A — narrow the tag test to exported-only (match the int test's scope)

Mechanically: the scratch patch in `59c_narrow_patch.diff` is the whole change.

- **Evidence for**: 18 §4 is explicit and unambiguous about the scope of rule C ("the exported
  function's own clause heads and body, and no further… a private function's every call site is
  a checked beam-sharp call site"). Saves +14 bytes of `Code` per private record parameter,
  matching 26a. Makes the two guards genuinely uniform, which is what the ticket's title asks for.
- **Evidence against, and it is decisive**: §3's probe. This is not a theoretical hole — it is a
  legal B# program, using a pattern idiom already shipped in `examples/Shop/shop.bs`, that
  silently returns a forged value under this exact patch and crashes correctly without it. The
  hole is not closed by anything else in the compiler (no narrowing-site guard for records exists
  the way F24 §6 built one for ints). Adopting A without also building a narrowing-site guard for
  the record channel is adopting a demonstrated defect, not merely a theoretical risk 18 §4 failed
  to anticipate.
- **Steelman**: 18 §4's own justification for function-local analysis is to bound an agent's
  blast radius to one file — and by that same argument, `Bump`'s author (or an agent editing
  `Bump`) is the one who introduced the partial pattern, in `Bump`'s own file, so the "which file
  changed" diagnosis still holds even though the *runtime* hole crosses into `Inner`. One could
  argue this is `Bump`'s bug (an under-constrained pattern on a union) rather than a boundary-
  guard scope question at all — the checker could plausibly be tightened to require a full
  identity proof before a union member is passed to a function typed at that member, which would
  close §3's hole without touching `guard_one/7` at all. This brief did not build that checker
  change or measure its cost, so it is recorded as the strongest counter-argument rather than as
  a competing recommendation.

### Option B — widen the int test to unconditional (match the tag test's scope)

- **Evidence for**: uniform in the other direction, and §3's structural finding shows the tag
  test earns its keep by being unconditional — the same argument extends to any future
  guard-decidable kind test emitted through the same code path (F24's own header comment already
  flags `atom`, `binary`, `tuple`, `list` as owed). Costs +16 bytes of `Code` for a refined
  `Octet` parameter, +3 for a plain `int` — measured, not assumed, and comparable to the
  tag test's own +14. No demonstrated hole was found on the int side that this would close (§3's
  structural argument is that ints do not have an equivalent partial-evidence gap, given F24 §6
  already closed the comparison-narrowing case) — so this option's benefit is uniformity and
  defence-in-depth against a *future* partial-evidence channel on the int side, not a closure of
  a demonstrated defect the way removing A's hole would be.
- **Evidence against**: 18 §4 and §5 ("no opt-out") were argued and decided specifically for the
  *exported* boundary; extending them to every private function is a real, if small, departure
  from a considered decision, for a benefit that (per §3) is prophylactic rather than measured
  against an actual hole. It also makes ticket 18's own §4 sentence ("a private function's every
  call site is a checked beam-sharp call site") false for the int test where it is currently true
  by construction, for no proven gain.
- **Steelman for NOT doing this**: nothing broke. The +16/+3 bytes buys defence against an attack
  this brief could not construct. Given the standing instinct in this repository against
  "prophylactic" work with no demonstrated defect (see F24's own framing: "nothing here was
  decided — the decision is not in the compiler," built only once a live defect existed), B is
  the weaker case of the two widenings on offer, and should not be adopted merely for symmetry
  with A.

### Option C — keep the asymmetry, document why, close ticket 59 as "working as found"

- **Evidence for**: §3 already supplies the "why" the ticket asked for — the tag test earns its
  unconditional scope because records admit partial-evidence patterns and the boundary needs a
  guard that closes that specific gap; the int test does not need the same treatment because it
  has no equivalent partial-evidence gap once F24 §6 closed the comparison case. This is not
  "both are defensible and we shrug" — it is a real, asymmetric reason, now demonstrated, for an
  asymmetric rule. Zero implementation cost.
- **Evidence against**: does not close the adjacent gap named in §3 (a private helper typed at
  the *union* itself, not at a single closed record, still gets no guard from either mechanism).
  Leaving the ticket "documented, not fixed" without also raising that adjacent gap as its own
  ticket would repeat the exact failure mode this repository's working rules warn against —
  closing a decision ticket while a defect it surfaced sits unrecorded.
- **Steelman against**: a future reader who only sees "both are defensible" without reading this
  brief's §3 has no way to tell C apart from indecision; the CLAUDE.md working rule that a design
  question is "B# code plus the compiler delta, and nothing else" pushes toward *some* mechanical
  change, not a documentation-only close, unless the documentation itself is treated as the
  deliverable (which the ticket's own framing — "Type: `wayfinder:decision`" — allows).

## 7. Recommendation

**Option C, but not as a shrug: record the asymmetry as intentional, on the ground §3 supplies
(records admit partial-evidence patterns that a foreign caller can satisfy without being what
they claim; refined ints, after F24 §6, do not), and raise the adjacent gap §3 found — a private
helper typed at a bare union gets no tag protection from either mechanism — as its own ticket
rather than folding it into 59's answer.**

This is not "do nothing": §3's probe is the concrete evidence 59 asked for and was missing, and
it resolves the object-level dispute between 18 §4 and 26 §1 in 26 §1's favour, but on a narrower
and more precise ground than 26 §1 itself stated — not "no body ever checks," but specifically
"a map pattern can be partially satisfied by a forged term in a way an int test cannot." Option A
(narrow) is refused on demonstrated evidence, not on the prose argument alone. Option B (widen)
is not recommended because nothing measured here shows it closes a hole; it is available as a
defence-in-depth move if a future ticket finds a partial-evidence channel on the int side, but
adopting it now would be exactly the kind of prophylactic change this repository's own working
history (F24's framing) argues against.

## 8. Probes-run appendix

All under `artifacts/_probes/59/`:

| file | what it is |
|---|---|
| `src/Probe59/probe59.bs` | private + public record- and `Octet`-taking functions; source for §1 |
| `out/Probe59.abstr`, `out/Probe59.beam` | current-`bsc` compile of the above |
| `59a_asymmetry_cost.erl` | independent byte-cost measurement, method matched to 18a/26a |
| `59a_output.txt` | its run output — the table in §2 |
| `src/Probe59b/probe59b.bs` | the union-parameter forgery construction, source for §3 |
| `outb/Probe59b.abstr`, `outb/Probe59b.beam` | current-`bsc` compile (tag test unconditional) |
| `outb-narrowed/Probe59b.abstr`, `outb-narrowed/Probe59b.beam` | narrowed-`bsc` compile |
| `59c_narrow_patch.diff` | the scratch patch to `bs_emit.erl` that produced the narrowed build (never applied to the tracked tree; built and kept only in `/tmp/ticket59-scratch`) |
| `59b_forgery_transcript.txt` | the `apply/3` forged-call run against both builds — the table in §3 |

No tracked file under `compiler/` was modified. All builds and probes ran against copies in
`/tmp/ticket59-scratch/compiler` and `/tmp/59a*`.
