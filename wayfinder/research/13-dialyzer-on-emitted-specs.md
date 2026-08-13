# 13 — Dialyzer on beam-sharp-emitted specs

Research for [issue 13](../issues/13-compilation-target-decision.md) §6, which commits the
compiler to emitting a `-spec` for every function whose type is known and builds the **widening
rule** in `bs_emit:spec_type/1` around what Dialyzer would read. Closes gap [g5] of
[`research/13-otp-range-corpus.md`](13-otp-range-corpus.md).

**The tool the specs exist for had never consumed one.** This runs it.

No decision is taken here; amendments are recommended at the end for the map to make.

---

## The verdict, first

**Ticket 13 §6 does what it promised.** The compiler emits specs, they survive into the `.beam`,
**Dialyzer reads them, agrees with them, and would object if they were wrong** [L1–L4].

Nothing `bs_emit` produces is wrong. Every difference Dialyzer reports is in the *desirable*
direction — our spec is a **subtype** of the success typing, i.e. strictly more precise than
anything Dialyzer could infer for itself [L3].

**One assumption in §6 is false, and it is the one the ticket leans on.** §6 records the widening
as *"silent by design — `-Wunderspecs`/`-Wspecdiffs` turn warnings on rather than off"*, the same
sentence repeated in `bs_emit.erl`'s header [2][3]. Measured: **`-Wunderspecs` can never surface
beam-sharp's widening**, and the reason is structural rather than incidental — ticket 04 makes
signatures mandatory, so the emitted *domain* is always narrower than the success typing, and that
alone disqualifies the whole spec from being classed as an underspec [L5]. `-Wspecdiffs` does
surface it, and reports **every function in the corpus**, so it has no signal-to-noise as a
widening detector.

## Method and provenance

| Mark | Meaning |
|---|---|
| **doc** | Ticket text or official documentation |
| **src** | Source in this repo |
| **local** | Observed directly on this machine |

Probe: [`13d_dialyzer_on_emitted_specs.sh`](../prototypes/13d_dialyzer_on_emitted_specs.sh).
Host **OTP 28.5**, plus `erlang:26` and `erlang:27` arm64 images. Base PLT over erts/kernel/stdlib
built in **9 seconds** — the 30-minute box was never in play [L1].

**The method note that matters.** A clean Dialyzer run is worthless as evidence unless you know
Dialyzer would have failed on a wrong spec. So §4 of the probe builds two deliberately-broken
specs *from the real emitted `.abstr`* and runs them through the identical command. Both fail, on
the **default** warning set. This is ticket 15's methodological lesson applied deliberately rather
than learned again — its first `15c` run reported every case surviving because the harness
supplied the protection the probe existed to measure.

---

## 1. Does the spec survive into the beam? Yes — and the `.core` path fails harder than recorded

Ticket 13 found that compiling from `.core` "emits an empty abstract chunk with no warning" and a
`-spec` is lost through that path. Reproduced, and it is worse than "lost" [L1]:

| Path | abstract chunk | Dialyzer |
|---|---|---|
| **`.abstr` → `erlc +from_abstr`** (adopted) | `raw_abstract_v1`, **4 forms, 1 spec** | analyses it |
| `.abstr` → `+to_core` → `+from_core` | `raw_abstract_v1`, **0 forms, 0 specs** | **cannot scan the module at all** |

```
dialyzer: Analysis failed with error:
Could not scan the following file(s):
  Could not get Core Erlang code for: …/core/Readings.beam
```

So the chunk is *present but empty* — which is why nothing warns — and Dialyzer does not silently
analyse a spec-less module, it **refuses the file**. That is a sharper form of ticket 13's
finding and strengthens its decision: the Core path would not merely have cost precision, it
would have taken the module out of Dialyzer's reach entirely.

## 2 and 3. Does Dialyzer accept our specs, and agree with them?

**Accept: yes, clean, on the default warning set** — on OTP 26, 27 and 28 alike [L2][L6].

```
Proceeding with analysis... done in 0m0.05s
done (passed successfully)
```

**Agree: yes, and in the direction that flatters the compiler.** `-Woverspecs` and `-Wspecdiffs`
both report all three functions, every one as *"is a subtype of the success typing"* [L3]:

| Function | our emitted spec | Dialyzer's success typing |
|---|---|---|
| `Readings:'Classify'/1` | `({'ok', integer()} \| {'error', atom()}) -> 'negative' \| 'positive' \| 'unknown' \| 'zero'` | `({'error', _} \| {'ok', _}) -> 'negative' \| 'positive' \| 'unknown' \| 'zero'` |
| `Math:'Classify'/1` | `(integer()) -> 'high' \| 'low' \| 'mid'` | `(_) -> 'high' \| 'low' \| 'mid'` |
| `Math:'Fib'/1` | `(integer()) -> integer()` | `(_) -> any()` |

Three things worth reading off that table.

**The showcase's return type is independently confirmed.** Dialyzer infers exactly the four-atom
union `bs_emit` emitted — same members, same order-insensitive set — from the clause bodies alone.
The precise union in ticket 01's showcase is not something beam-sharp merely asserts; the
platform's own inference agrees with it.

**The retained failure arm does *not* widen the inferred domain.** Ticket 12 keeps the failure arm
and `erlc` inserts `match_fail` regardless, and the worry was that this would make Dialyzer think
the function accepts more than the spec says. It does not: the inferred domain is
`{'error', _} | {'ok', _}` — the union of the clause-head *shapes*, tags included. The failure arm
contributes nothing to the domain.

**`Fib` is where declaration beats inference outright.** Success typing gives `(_) -> any()`,
because the recursion defeats it. Our `(integer()) -> integer()` is strictly better information,
and Dialyzer accepts it without complaint. That is ticket 13 §6's whole case, measured.

## 4. Would a wrong spec fail? Yes, on the default warning set

Both controls are built from the real emitted `.abstr` with one type substituted [L4]:

```
-- RETURN wrong (claims integer() where the body returns atoms):
   Invalid type specification for function 'WrongRet':'Classify'/1.
   … The return types do not overlap

-- ARGUMENT wrong (claims atom() where the clauses match tuples):
   Invalid type specification for function 'WrongArg':'Classify'/1.
   … They do not overlap in the 1st argument
```

Neither needs an extra flag. **So §2's clean pass is a real result**, and a CI corpus can use the
default warning set as a genuine gate on emitted specs — the cheapest possible check on
`bs_emit`, and one nothing in the repo currently performs.

## 5. The widening rule cannot be surfaced the way §6 says it can

This is the finding.

`bs_emit:atom_parts({cofinite, _})` widens a cofinite atom set to `atom()`, dropping the exclusion
[src]. To exercise it in the direction that would flag it, the probe compiles a beam-sharp module
whose declared return is the atom top and whose body only ever returns `:ok` [L5]:

```
atom Always(int n);
Always(n) -> :ok;          →   -spec 'Always'(integer()) -> atom().
```

Dialyzer's success typing is `(_) -> 'ok'`. Our spec's *range* is therefore wider — a textbook
underspec. And yet:

```
-Wunderspecs  →  done (passed successfully)
-Wspecdiffs   →  (integer()) -> atom() is not equal to the success typing: (_) -> 'ok'
```

**Why**, isolated with a hand-written Erlang control so the mechanism is not inferred [L5]:

| Erlang spec | vs success typing | `-Wunderspecs` |
|---|---|---|
| `same_dom(any()) -> atom()` | domain identical, range wider | **fires** — *"is a supertype of the success typing"* |
| `narrow_dom(integer()) -> atom()` | domain narrower, range wider | **silent** — only `-Wspecdiffs`, as *"not equal"* |

Dialyzer classifies the spec **as a whole**, not per position. A spec that is narrower somewhere
and wider elsewhere is neither a supertype nor a subtype, so it is neither an over- nor an
under-spec — it is merely "not equal".

**And beam-sharp is always in that case.** Ticket 04 made signatures mandatory, so every emitted
spec has a declared domain, and a declared domain is essentially always narrower than the `_` that
success typing infers for an unconstrained parameter. **`-Wunderspecs` is therefore structurally
blind to beam-sharp's widening — not on this corpus, but by construction.**

`-Wspecdiffs` sees it, but §3 shows it also reports all three correctly-specified functions. It
does not distinguish "we widened and lost something" from "we are more precise than you" without
reading the message text.

## Verdict on ticket 13 §6

**It does what it promised.** Every clause of §6 holds:

- a `-spec` is emitted for every function whose type is known — 1 spec for `Readings`, 2 for
  `Math`, all present in the abstract chunk [L1];
- it survives into the `.beam` on the adopted path where the rejected one loses it [L1];
- Dialyzer reads and accepts it [L2], on every release in the pinned range [L6];
- and it is *more precise* than success typing everywhere, never less [L3].

**One sub-claim is corrected**: the widening is not observable through `-Wunderspecs`, and the
sentence saying it is appears in both the ticket and the compiler source.

**Nothing `bs_emit` emits is wrong.** That was the outcome most worth finding and it is not there.

### Recommended amendments

Recommended, not made; `write_scope` here is this file and `prototypes/13d*`.

**A. Correct §6's `-Wunderspecs` sentence**, and the same sentence in `bs_emit.erl`'s header
comment [2][3]. The accurate statement is: *the widening is observable through `-Wspecdiffs` only,
because a mandatory declared domain puts every emitted spec in Dialyzer's "not equal" class rather
than its "supertype" class.*

**B. If widening should be monitored, monitor the *shape* of the diff, not the warning count.**
`-Wspecdiffs` reports every function, so a count is meaningless. The distinction that carries
information is in the message: *"is a subtype of the success typing"* is the healthy case
(more precise than Dialyzer), *"is a supertype"* or *"is not equal"* is the one to look at. A CI
check that classifies `-Wspecdiffs` output by that phrase would be a real widening detector, where
the flag alone is not.

**C. Add a default-warning-set Dialyzer run to the CI corpus §4 asks for.** §4 above shows it
catches a wrong emitted spec with no extra flags and no configuration, in 0.05 s against a 9 s
PLT. It is the cheapest available regression test on `bs_emit`, and nothing currently runs it.

**D. Not ticket 13's, but it belongs in the record — ticket 18's premise, corroborated by the
platform.** Dialyzer recovers `{'ok', _}` where we declared `{'ok', integer()}`: it sees the tag
because a clause head matches it, and cannot see the payload type because nothing checks it. That
is exactly ticket 18's tag/payload asymmetry — *"a pattern match is not a check"* — which 18
called its strongest evidence after sighting it three times in one session. **This is a fourth
sighting, and the first inside beam-sharp's own emitted output.** It also marks precisely where
18's boundary guards do their work: the gap between our declared payload type and what the
platform can verify is the silent-unsoundness surface.

## Gaps

- **[g1] Three modules and four functions.** Same corpus limit as
  [`13-otp-range-corpus.md`](13-otp-range-corpus.md) [g2]. In particular no function here exercises
  `int_part/1`'s `range`/`neg_integer`/`non_neg_integer`/`pos_integer` branches, which
  [`13c` §3](13-otp-range-corpus.md) found unreachable from the current surface — so **how
  Dialyzer treats an emitted `range` spec is untested**, and it is the branch most likely to
  differ, since Dialyzer quantises integer ranges onto a fixed ladder (ticket 20).
- **[g2] Only a base PLT over erts/kernel/stdlib.** No dependency PLT, and beam-sharp code that
  calls into OTP would need one. Nothing here calls out of its own module.
- **[g3] No cross-module analysis.** Every module is analysed alone. Dialyzer's most valuable
  output is usually at call sites *between* modules, which this slice cannot produce — the
  language has no module or import system yet (still fog).
- **[g4] `-Wmissing_return` and `-Wextra_return` were not exercised**, and both are plausibly
  relevant to ticket 12's retained failure arm.
- **[g5] The `.core` reproduction used `+from_abstr +to_core` rather than a hypothetical
  Core-emitting compiler.** It confirms the chunk is empty on that path; it does not prove a
  purpose-built Core backend could not do better.

## Claim → source

| # | Source | Mark |
|---|---|---|
| L1 | [`13d`](../prototypes/13d_dialyzer_on_emitted_specs.sh) §1 — abstract-format path carries 4 forms / 1 spec; `.core` path carries 0 / 0 and Dialyzer cannot scan the file; PLT built in 9 s | **local** |
| L2 | [`13d`](../prototypes/13d_dialyzer_on_emitted_specs.sh) §2 — default warning set passes on the emitted beams | **local** |
| L3 | [`13d`](../prototypes/13d_dialyzer_on_emitted_specs.sh) §3 — `-Wunderspecs` silent; `-Woverspecs`/`-Wspecdiffs` report all three functions as a *subtype* of the success typing, with the inferred types quoted above | **local** |
| L4 | [`13d`](../prototypes/13d_dialyzer_on_emitted_specs.sh) §4 — wrong return and wrong argument each produce *"Invalid type specification"* on the default warning set | **local** |
| L5 | [`13d`](../prototypes/13d_dialyzer_on_emitted_specs.sh) §5 — the cofinite atom widening is invisible to `-Wunderspecs` and visible to `-Wspecdiffs`; the hand-written `same_dom`/`narrow_dom` control isolates the whole-spec classification as the cause | **local** |
| L6 | [`13d`](../prototypes/13d_dialyzer_on_emitted_specs.sh) §6 — identical results on OTP 26 and 27, rebuilt from the same `.abstr` | **local** |
| 1 | [Ticket 13](../issues/13-compilation-target-decision.md) §6 — a `-spec` for every function whose type is known; the widening rule; the `.core` path loses it | **doc** |
| 2 | [Ticket 13](../issues/13-compilation-target-decision.md) §6 — *"`-Wunderspecs`/`-Wspecdiffs` turn warnings on rather than off"* | **doc** |
| 3 | `compiler/src/bs_emit.erl` header comment, repeating the same sentence; `spec_type/1`, `parts/1`, `atom_parts/1`, `int_part/1` | **src** |
| 4 | [Ticket 18](../issues/18-boundary-defence.md) — the tag/payload asymmetry, *"a pattern match is not a check"* | **doc** |
| 5 | [Ticket 15](../issues/15-error-model.md) — the `15c` methodological note on a harness supplying the protection it was measuring | **doc** |
| g1–g5 | Gaps — see [Gaps](#gaps) | gap |
