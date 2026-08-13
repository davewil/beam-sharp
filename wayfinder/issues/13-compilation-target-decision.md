# 13 — Compilation target decision

Type: grilling
Status: resolved
Blocked by: 02, 11, 19 — all resolved

## Question

Given the survey in ticket 02 and the type system shape settled in ticket 11: which target
does the compiler emit — **Core Erlang**, the **Erlang Abstract Format**, or **BEAM
bytecode**?

State:

- The choice, and the decisive reason.
- What it costs in expressible semantics — particularly whether multi-clause dispatch is
  inherited from the target or must be synthesised by the frontend, and whether the
  frontend's clause-merging can be made to agree with the exhaustiveness checker.
- What it costs in tooling: stack traces, debugger, dialyzer, hot code loading, crash-report
  legibility.
- The exposure to OTP release churn, and the mitigation.
- Whether the choice is reversible later, and at what cost.

## What ticket 02 established

The survey is done; this ticket only has to choose. The decisive facts:

- **The Abstract Format expresses multi-clause heads natively** — a function form *is* a list
  of `{clause, ANNO, Patterns, Guards, Body}`, and the guard sequence keeps Erlang's full
  list-of-lists disjunction/conjunction structure. The frontend owes nothing.
- **Core Erlang costs a mechanical wrapper**, not a match compiler: one `fun` over fresh vars,
  one `case` over the value list, one clause each, order preserved, plus a synthesised failure
  clause. Perhaps fifty lines. Its `when` is also strictly *wider* than Erlang's.
- **BEAM bytecode costs a full match compiler.** That is the real cliff.
- **Choosing Core Erlang forfeits Erlang-side type publication.** A `-spec` survives the
  Abstract Format path by construction and is lost through `.core`; Dialyzer cannot read a
  `.core`-built beam at all, and fails *silently*. Ticket 06 recommends emitting `-spec`, so
  these two tickets must be decided together — or ticket 06's recommendation withdrawn.
- **Core Erlang is less stable than its reputation**: 2004 spec hosted outside OTP, OTP's own
  source saying the format can change between releases, spec-implementation drift (maps), and a
  wholesale backend replacement at OTP 27.
- **`from_abstr` allows an out-of-process frontend in any language** to emit `.abstr` text and
  shell out to `erlc` — which decouples this decision from the compiler's host language.

**A correction to an earlier note on this ticket.** It previously said "Gleam and LFE both
route through Core Erlang, so choosing the Abstract Format would be a departure from the
closest precedents." Ticket 02 contradicts both halves: **Gleam has never emitted Core Erlang**
(claim 15), and **LFE left Core Erlang for the Abstract Format in January 2018** (claim 19),
for `debug_info`. The Abstract Format is not the departure; it is where the neighbours went.

Ticket 02 could not establish a stated rationale for *any* project's target choice except
Gleam's, so precedent remains weak evidence either way.

## What ticket 19 established — the premise inverts

`purescript-backend-erl` was briefed as "the closest existing implementation of the codegen
beam-sharp needs". **It is the opposite: a counter-example.** It emits exactly one clause per
function, always, with no guard — and the cause is upstream and unreachable from any backend.
`purs` collapses N equations into a single CoreFn `ExprCase` before `corefn.json` is written,
and the optimiser then compiles the pattern matrix into a chain of boolean tests whose IR has
**no pattern node at all**. Its target choice is therefore not what constrains it; it would
emit identical single-clause functions targeting the Abstract Format.

Combined with ticket 02's survey: **no BEAM backend fed by a curried functional frontend emits
clause heads.** Gleam refuses them in the surface; Hamler and Alpaca flatten to one `c_fun`
plus `c_case`; purerl emits one clause plus `case`; its successor one clause plus an `if` chain.
**The only two that keep heads are LFE and Elixir — whose surface syntax has multi-clause heads
natively.**

Be careful with the causation: LFE and Elixir do not keep heads *because* they target the
Abstract Format. LFE preserved heads for years on Core Erlang and switched in 2018 for
`debug_info`. **The target enables preservation; the frontend decides whether there is anything
to preserve.** beam-sharp is in LFE's position — a native multi-clause surface with no
pattern-matrix flattening upstream — which is exactly why the backend-erl audit is a
counter-example rather than a template. Net: **no evidence against the Abstract Format.**

## Notes

## A codegen obligation from ticket 10 — resolved 2026-08-12

**Every atom appearing in a type position must be emitted into the module's atom chunk.** This
is an obligation Erlang does not have, and whichever target is chosen must be able to discharge it.

Verified ([`prototypes/10b_atom_interning.erl`](../prototypes/10b_atom_interning.erl), OTP 28):
an atom appearing **only** in a `-type`/`-spec` is absent from the compiled atom chunk, and
`binary_to_existing_atom` rejects it. Erlang tolerates this because its specs are documentation.
Ticket 09 made beam-sharp's types **erased aliases** while keeping them load-bearing, so a
`type Outcome = :ok | :error;` whose `:error` never reaches a pattern or expression would leave
that atom uninterned — and ticket 10 §4's `ToExistingAtom` would then reject a value the type
system says is legal. Type says yes, runtime says no: ticket 06's third outcome through an
unwatched door.

The exposure is narrow (atoms in clause heads are already value-position literals) and the cost
is bounded by source size. **But note how it compounds with ticket 02's sharpest finding**:
compiling from `.core` emits an empty abstract chunk *with no warning*. Both are silent failures
in the same layer, and a target chosen without checking either will fail quietly.

## Notes

HITL, but heavily fact-led — most of the work is in ticket 02. Blocked by ticket 11 because
a type system that erases entirely has different target needs than one wanting to emit
type-derived runtime checks at boundaries.

## Constraints from ticket 11 — resolved 2026-08-12

- **A second type-directed codegen obligation lands here.** Ticket 10 established `ParseAtom<T>`;
  ticket 11 adds **`ValidateAs<T>`**, which must synthesise an O(n) structural traversal from a
  type. Both require full type information *at codegen time*, which is an argument about the tier
  chosen — and it compounds ticket 02's finding that compiling from `.core` emits an empty
  abstract chunk **with no warning**, losing `-spec` silently.
- **Patterns over a `term` lower to guards.** Where a typed parameter needs no runtime test
  (the checker proved it), a `term` pattern does: `{:tick, int n}` needs `is_integer(N)`. So the
  backend must emit guards from pattern type annotations, and only for `term`-typed positions.
- **Arrow types are rejected by `ValidateAs<T>` at compile time**, so no fun-wrapping codegen is
  needed. If ticket 11's deferred option (a runtime type registry keyed by module, to validate an
  external fun against its declared `-spec`) is ever taken up, that lands here.

## Constraints from ticket 12 — resolved 2026-08-12

**A new discriminator between the two live targets, and it favours the Abstract Format.**

Ticket 12 §6 decided the compiler-generated failure arm is **always emitted** — never omitted for
functions proved exhaustive. Measured on OTP 28: omission saves 40 bytes (4.8%) and destroys the
crash report, replacing `error:function_clause` carrying `{partial, [c], [{file,…},{line,…}]}` with
`error:if_clause` carrying `{partial, 1, []}`. Evidence:
[`prototypes/12a_failure_arm.erl`](../prototypes/12a_failure_arm.erl).

**The interaction with this ticket**: omission is only a *choice* on the Core Erlang path.

- **Abstract Format** — `erlc` inserts the `match_fail` arm itself and there is no way to suppress
  it from the Abstract Format. The safe answer is free, and unavailable to get wrong.
- **Core Erlang** — beam-sharp writes the `case` itself and chooses whether to include the
  `primop 'match_fail'` clause. The 40 bytes are available, and so is the mistake.

So the Core path's only extra capability here is one ticket 12 decided against using, on a target
that ticket 02 already found forfeits `-spec` publication and fails Dialyzer silently. That is a
third strike against Core Erlang rather than a point in its favour.

Should this ticket nonetheless choose Core Erlang, ticket 12 §6 binds: emit the arm anyway, unless
ticket 18 decides to emit boundary guards, which is the only sound route to omitting it.

## Answer — resolved 2026-08-12

**The compiler emits the Erlang Abstract Format.** Evidence for everything below is
[`prototypes/13a_target_measurements.md`](../prototypes/13a_target_measurements.md) and
[`prototypes/13b_aggregate_attribution.erl`](../prototypes/13b_aggregate_attribution.erl), both
observed on OTP 28.5 rather than cited.

### 1. The decisive reason is reversibility, not any of the five the ticket had stacked

The file arrived with five findings pointing the same way — ticket 02's silent `-spec` loss,
ticket 19's no-evidence-against, ticket 12's third strike, ticket 10's atom obligation, LFE
leaving Core in 2018. **None of them is the reason to record**, because a sixth fact subsumes
them and was not in the ticket:

| Direction | Result |
|---|---|
| `.abstr` → Core Erlang | ✅ `erlc +from_abstr +to_core` — OTP performs the translation itself |
| `.core` → abstract forms | ❌ `{raw_abstract_v1,[]}` — unrecoverable |

Ticket 02 framed the three targets as a **ladder of increasing cost**. They are better understood
as a **one-way door**. Choosing the Abstract Format forfeits nothing that a compiler flag cannot
recover; choosing Core Erlang forfeits the abstract chunk permanently. Every other advantage —
native clause heads, `-spec`, Dialyzer, `debug_info` — rides along behind that one.

State it this way in the spec, because it is the form of the argument that survives new evidence:
a future finding favouring Core Erlang would still have to explain why it is worth walking
through a door that does not open again.

**The one live argument for Core Erlang was already spent.** Ticket 02 found its `when` is
strictly *wider* than Erlang's guard grammar — but ticket 09 fixed the discriminability
vocabulary to the BEAM guard set and ticket 08 committed guards to the same set via the expansion
rule. The wider `when` has nothing left to express. Ticket 12's failure-arm saving is the only
other Core-only capability, and ticket 12 decided against using it (see §7).

### 2. The emission contract is *a sequence of abstract-format forms*

Not "the compiler calls `compile:forms/2`". The contract is the forms themselves, and it carries
a standing obligation: **the frontend must never depend on in-process compiler state**, so that
serialising the forms to `.abstr` and shelling out to `erlc +from_abstr` always works.

Verified: `erlc +from_abstr` builds a working module with **no `.erl` anywhere on disk**. The file
format is a *sequence of terms, one per form*, each terminated with `.` — feeding it a single list
crashes `erl_lint` (13a §1).

**Why the obligation and not just the observation**: without it a frontend drifts into parse
transforms, shared PLT state and incremental term reuse, and the text route quietly stops working
precisely when someone wants to rewrite the frontend in another language. Keeping the promise is
cheap now and unrecoverable later — the same reversibility logic ticket 11 used to reject
higher-order contract wrapping.

**What this buys**: the compiler's host language is genuinely open. This removes a constraint from
the walking skeleton, which need not be a BEAM program.

**What it costs, permanently**: `erl_syntax`/`merl` are foreclosed as a churn abstraction. They are
the standard answer to Abstract Format drift and they require a BEAM-hosted frontend. This is the
sharpest cost of the decision and §4 exists because of it.

### 3. Sub-modules are source-only — one `.beam` per aggregate

Ticket 01's prototype 01d recommended this on four grounds; it is adopted, and **per-function hot
code loading is rejected rather than deferred**. What would flip it is unchanged from 01d: wanting
the *operation* to be the unit of deployment. Observability was the other candidate trigger and is
now closed (below).

**01d's sharpest objection against source-only is largely false on this target.** It held that the
sub-module structure is "a source fiction the runtime does not know about", so a crash would name
the aggregate. Measured (13b): `{attribute, ANNO, file, {Name, Line}}` may appear **repeatedly
mid-module** and re-points every form after it — the mechanism Elixir and LFE use to attribute
generated code to original source. Two functions in one BEAM module reporting against two source
files:

```erlang
total/1 crash: {'Shop.Orders.Order',total,[99],[{file,"Order/Total.bs"},{line,42}]}
apply/1 crash: {'Shop.Orders.Order',apply,[99],[{file,"Order/Apply.bs"},{line,7}]}
```

So source-only keeps per-sub-module crash reports, `dbg` locations and debugger positions. Its
remaining cost is only that the compiler owns a module abstraction the BEAM does not share, and
every tool integration must translate.

**Note the repair is target-specific**, which couples §1 and §3 more tightly than the ticket
assumed: it depends on annotations surviving into the beam, which is exactly what the Core Erlang
path discards. Had this ticket chosen Core, source-only would have cost its observability after all.

### 4. OTP churn: a pinned range, proved in CI

The exposure is real and visible in the beam itself — the chunk tag is `raw_abstract_v1`, an
explicit version marker on the committed format. Ticket 02 found OTP's own source saying the
representation can change between releases.

**Mitigation: declare a supported OTP range and keep a corpus of beam-sharp modules compiled on
every release in it, in CI.** A format change then surfaces as a build break at a time of our
choosing rather than a user's runtime surprise.

The `erl_syntax`/`merl` mitigation is **unavailable** — it requires a BEAM-hosted frontend, which
§2 gave up. That is a deliberate trade, recorded here so it is not rediscovered as a surprise:
§2 bought host-language freedom and paid for it with the standard churn abstraction, and §4 is the
replacement.

Rejected: emitting **Erlang source text** instead of forms. It is the most churn-resistant
interface OTP offers and produces output a human reviewer can read, which the standing constraint
makes attractive. It loses on precision — `-file("X", 42)` occupies the line it names, so the
following line reports as 43 and every line number becomes arithmetic the compiler must get right,
where an annotation is simply exact (13b). Also rejected: absorbing churn with no mitigation.

### 5. Supported range: current and previous two majors

Two columns is the minimum that can detect a diff; three matches the BEAM ecosystem norm for
libraries and puts real pressure on the emitter to stay on the format's stable core.

**Open verification this ticket does not close**: `+from_abstr` is confirmed on **OTP 28.5 only**,
because that is what is installed. §2's guarantee assumes it exists across the whole supported
range. Confirming it on the oldest supported release is work the walking skeleton owes, and the
range is provisional until then.

### 6. The compiler emits a `-spec` for every function whose beam-sharp type is known

**The 13/18 coupling is discharged, not deferred.** This ticket said twice that it and ticket 18
"must be decided together, or ticket 06's spec recommendation withdrawn". That coupling was
**conditional on the Core Erlang branch**: `-spec` is lost through `.core` and survives the
Abstract Format path by construction (13a §2, measured both ways). Choosing the Abstract Format
discharges it. Ticket 06's recommendation stands, unwithdrawn, and 18 — blocked behind the
deferred ticket 22 — is not on the critical path for it.

**Where a beam-sharp type has no Erlang spec spelling, widen to the nearest expressible
supertype**, ultimately `term()`. Erlang's spec grammar has no negation, and only expresses
intersection as an overloaded spec, so a set-theoretic type is not always publishable exactly.
A widened spec is *sound* — never a false claim, only a weak one — and it is **silent**:
`-Wunderspecs` and `-Wspecdiffs` both turn warnings *on* and are off by default (13a §5). So
widening costs precision, not noise, and every function still publishes a type.

**One caveat on that silence.** "Off by default" is weakest evidence for exactly the audience this
decision serves: the point of emitting `-spec` at all (ticket 06) is Dialyzer consumers, and a
consumer who has gone to the trouble of running Dialyzer is more likely than average to have
turned those flags on. The decision stands — a widened spec is still sound, and the alternatives
are worse — but the spec should say plainly that a beam-sharp module analysed with `-Wunderspecs`
will report underspecified functions **by design**, so it reads as a known consequence rather than
a defect.

Rejected: omitting the spec where the type does not fit (leaves functions publishing nothing, and
the boundary between "precise" and "absent" is invisible to a consumer), and refusing to compile
(bans legitimate set-theoretic types from the exported surface to satisfy a weaker language's
grammar).

**FFI declarations remain ticket 18's**, unchanged. There the spec is an *unverified claim*
asserted to the ecosystem, which is a boundary-defence question, not a target question.

### 7. What the choice costs, in semantics and in tooling

Closing the ticket's remaining `State:` items explicitly.

**Expressible semantics — the frontend owes nothing.** A function form *is* a list of
`{clause, ANNO, Patterns, Guards, Body}`, so multi-clause dispatch is **inherited from the target,
not synthesised**. The question of whether frontend clause-merging can be made to agree with the
exhaustiveness checker **does not arise**: beam-sharp does no merging. Ticket 19 established that
this is exactly what breaks every curried functional frontend — `purs` collapses equations into a
single `ExprCase` upstream, and no backend can recover them. beam-sharp is in LFE's position, with
a native multi-clause surface and nothing flattening it, so heads written are heads emitted
(ticket 01's showcase: five clauses in, five native clause heads out).

**Tooling — everything is retained.** `-spec` and Dialyzer (§6), `debug_info` and therefore the
debugger, stack traces and crash reports naming the correct sub-module source file and line (§3).
Hot code loading works at aggregate granularity, which §3 chose deliberately: the consistency unit
and the deployment unit coincide, so `relup` is simple and torn upgrades are impossible by
construction rather than by discipline.

**One capability is given up, permanently.** Ticket 12 §6's 40-byte (4.8%) failure-arm omission is
**not available on this target at all** — `erlc` inserts the `match_fail` arm itself and there is
no way to suppress it from the Abstract Format. This is visible in the generated Core (13a §3).
Ticket 12 had already decided against taking the saving; the target now removes the choice. The
safe answer is free, and unavailable to get wrong.

### Consequences propagated

- **Ticket 18 loses an argument rather than gaining one.** It was told that emitted boundary
  guards are "the only sound route to the codegen saving" of ticket 12 §6. **That saving no longer
  exists** — it was only ever available on the Core Erlang path (§7). So 18's remaining motivation
  for emitting guards is **silent unsoundness alone** (ticket 06's third outcome), which is a
  narrower and cleaner question than it was charted with. Also: the 13/18 joint-decision
  requirement is discharged (§6), and the ordinary `-spec` case is settled, leaving 18 the FFI
  sub-decision only.
- **Ticket 06's recommendation to emit `-spec` is confirmed, not withdrawn** (§6).
- **Ticket 14 inherits a settled shape**: source-only sub-modules mean OTP callbacks land in the
  aggregate module where `gen_server` already looks for them. **There is no facade to design** —
  prototype 01c's problem does not get solved, it stops existing.
- **Ticket 12 §6 is now enforced by the target rather than by policy.** The failure arm is always
  emitted because it cannot be suppressed.
- **Ticket 10's atom-interning obligation has a defined home.** Atoms appearing only in type
  positions must still be emitted into the module's atom chunk; the Abstract Format path gives the
  compiler a place to add the forms that do it, and the `.core` route's empty abstract chunk —
  the other silent failure in the same layer — is no longer in play.
- **Ticket 27** should note that `-spec` widening (§6) is the publication half of the
  codegen-obligation story: `ParseAtom<T>` and `ValidateAs<T>` are monomorphic at every use, and
  what gets published for them is a widened spec, not a generic one.


## Obligations added by ticket 14 — resolved 2026-08-12

Ticket 13 §4 pinned a supported OTP range (current plus the previous two majors), proved by a CI
corpus owned by the walking skeleton. Ticket 14 adds two things that corpus must prove, because
the language now ships a **model of OTP** rather than only emitting for it:

- **Behaviour contracts** (§4). `[module: GenServer]` names a contract the compiler knows as a
  type, against which user-narrowed callback signatures are checked for containment. Whether those
  contracts differ across the pinned range is **unmeasured** — only OTP 28.5 was installed when
  ticket 14 was resolved.
- **System-message shapes** (§6). `Down`, `Exit`, `Timeout` and friends are compiler-known prelude
  types, so their shapes must hold across the same range.

Both failure modes are *being out of date* rather than *being wrong*, and both live in a data file
rather than in language semantics — but they are new reasons the corpus exists, alongside proving
`+from_abstr` on the oldest supported release.

## Amended by the OTP range corpus — 2026-08-13

Measured once the walking skeleton existed to generate real forms:
[`research/13-otp-range-corpus.md`](../research/13-otp-range-corpus.md),
[`prototypes/13c_otp_range_corpus.sh`](../prototypes/13c_otp_range_corpus.sh).

**§5's "provisional" is discharged.** `erlc +from_abstr` exists on **OTP 24, 25, 26, 27 and 28**,
the forms `bs_emit` produces build unchanged on all five, the modules are callable and return
correct values, and **the emitted `-spec` survives byte-identically** — equal `phash2` per module
across the range, which closes the *backwards* half of §6 that nobody had checked. Nothing found is
version-sensitive at all.

**The range holds and is conservative by two majors.** 24 and 25 pass the identical corpus, so the
floor is not a cliff. The pin stays at three, because §5's reason was never "older ones fail" — it
was matching the ecosystem norm and keeping pressure on the emitter to stay on the format's stable
core, and that reasoning survives 24/25 passing. Recorded rather than acted on.

**§4 gains a sentence it needed and did not have: the range is a property of the *target runtime*,
not the build host.** A 28-built beam-sharp `.beam` is `{error,badfile}` on 26 and 27 — and so is
this compiler's own `.beam`. **The portable artefact is the `.abstr`, not the `.beam`.** §2 already
implies the host is unconstrained; §4 never said it, and §4's own artefact is the one that does not
travel. That raises a question neither this ticket nor the compiler's README answers: **distributing
a beam-sharp library across the range means shipping `.abstr` or building per target.** Left as an
open consequence rather than decided here — it is a packaging question, and packaging is out of
scope on the map.

**§4's CI corpus should be grown from the emitter's vocabulary, not from the examples.** The two
committed examples exercise only **6 of `bs_emit`'s 11 type forms and 7 of its 11 operators** — a
corpus that grows only when someone writes a new `.bs` will drift behind the emitter silently. A
synthetic `Coverage` module, hand-derived from `bs_emit.erl`, covers the rest and builds everywhere
too. **This is the durable form of the obligation**, and it is a stricter rule than "run the
examples on every release".

**One methodological warning worth keeping.** `erlc -h` does **not** list `from_abstr` on any
release, 28.5 included, where it demonstrably works — it is a `+`-passed compile option rather than
a documented flag, so the only honest test is to build with it. The corpus nearly reported it
*absent* on 26 and 27 off the help output. Anything else this ticket asserts about `erlc`'s option
surface should be tested the same way.

**Five gaps recorded rather than papered over**: Linux/arm64 only; three modules is not a corpus;
OTP 29 is unreleased; only `+debug_info` was exercised; and Dialyzer was not run on the older
releases — which matters, because §6's `-spec` emission is the thing Dialyzer consumes.

## §6 verified, and one of its claims corrected — 2026-08-13

Measured: [`research/13-dialyzer-on-emitted-specs.md`](../research/13-dialyzer-on-emitted-specs.md),
[`prototypes/13d_dialyzer_on_emitted_specs.sh`](../prototypes/13d_dialyzer_on_emitted_specs.sh),
and the standing check at [`compiler/bin/spec-check.sh`](../../compiler/bin/spec-check.sh).

**§6 does what it promised.** Dialyzer reads the specs `bs_emit` emits — the `.beam` carries
`raw_abstract_v1` — and passes clean on the default warning set on OTP 26, 27 and 28. Under
`-Wspecdiffs` every function reports *"is a subtype of the success typing"*: **our specs are
strictly more precise than anything Dialyzer infers.** Verified independently here.

Three readings, each answering something §6 asserted without evidence:

- **`Fib` is where a declaration beats inference outright.** Success typing is `(_) -> any()`,
  because the recursion defeats it; Dialyzer accepts our `(integer()) -> integer()` without
  complaint. That is §6's entire case, measured rather than argued.
- **Ticket 12's retained failure arm does not widen the inferred domain.** Dialyzer infers
  `{'error', _} | {'ok', _}` — the union of the clause-head shapes. `match_fail` contributes
  nothing, which was the live worry.
- **The Core contrast is worse than §1 records.** That path yields an abstract chunk that is
  *present but empty* (0 forms, 0 specs) and Dialyzer **refuses the file outright** — *"Could not
  get Core Erlang code"* — rather than analysing a spec-less module. **The Core branch would have
  put modules out of Dialyzer's reach entirely**, not merely cost precision. §1's "fails silently"
  understates it.

**CORRECTION — §6's claim that the widening is observable through `-Wunderspecs` is false**, and
false *by construction* rather than by corpus artefact. Measured: a module whose declared return is
the atom top and whose body only returns `:ok` is a textbook underspec, and `-Wunderspecs` stays
silent; only `-Wspecdiffs` reports it, as *"not equal"*. A hand-written control isolates why —
`same_dom(any()) -> atom()` (domain identical, range wider) **fires** `-Wunderspecs`;
`narrow_dom(integer()) -> atom()` (domain narrower, range wider) does **not**. Dialyzer classifies a
spec **as a whole**, and narrower-somewhere-wider-elsewhere is neither supertype nor subtype.

**beam-sharp is always the second shape**, because ticket 04 made signatures mandatory, so every
emitted spec has a domain narrower than the `_` success typing infers. So the accurate sentence is:
**the widening is observable through `-Wspecdiffs` only.** Corrected here and in `bs_emit.erl`'s
header, which carried the same wrong sentence.

**§4's CI corpus gains a cheap and strict member.** A default-warning-set Dialyzer run over the
emitted `.beam` costs 0.05 s against a 9 s PLT and catches a wrong spec outright. It is now
`compiler/bin/spec-check.sh`, and it carries **two negative controls built by corrupting a real
emitted `.abstr` in exactly one respect** — because a clean Dialyzer run is worthless as evidence
unless a wrong spec would fail it. (Ticket 15 lost a session to a harness that supplied the
protection it was measuring; this is that lesson applied rather than re-learnt.) If widening is ever
to be *monitored* rather than merely checked, classify `-Wspecdiffs` by message phrase and not by
count: it reports every function, so a count means nothing — *"is a subtype"* is healthy,
*"is a supertype"* or *"is not equal"* is the one to look at.

**Ticket 18's tag/payload asymmetry, sighted a fourth time and the first inside beam-sharp's own
output.** Dialyzer recovers `{'ok', _}` where we declared `{'ok', integer()}`: it sees the **tag**,
because a clause head matches it, and cannot see the **payload**, because nothing checks it. That is
precisely the shape ticket 18 measured three times in one session, and it marks exactly where 18's
boundary guards earn their keep.

**One gap worth naming**: no function in the corpus emits a `range` spec, because those `int_part`
branches are unreachable from the current surface. `range` is the branch most likely to behave
differently, since Dialyzer quantises integer ranges onto a fixed ladder (ticket 20). **When the
next slice makes intervals reachable, re-run this first.**
