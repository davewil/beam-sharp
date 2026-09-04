# 18 — Boundary defence: does the compiler emit runtime guards, and where?

Type: grilling
Status: resolved 2026-08-13
Blocked by: 11 (done), 12 (done) — the 22 relation was dropped 2026-08-12 as stale, see below

## Question

Ticket 06 established that **an untyped caller does not always crash**, and that the three
possible outcomes are not equally bad:

1. **Immediate crash** — the value fails a match straight away. Fine; this is let-it-crash
   working as intended.
2. **Deferred crash** — the bad value propagates and fails somewhere else, with a stack trace
   pointing at the wrong place. Annoying, debuggable.
3. **Silent unsoundness** — no crash at all, ever. A function typed `Int, Int -> Int` called as
   `add(1.5, 2.5)` returns `4.0`. `hold(self())` puts a pid inside a `Box(Int)` and nothing
   objects. **This is the only outcome that makes the type system a lie.**

Only case 3 is an argument for the compiler emitting runtime guards — and ticket 06 found the
fix is cheap: a single `when is_integer(...)` clause converts silent unsoundness into a
`function_clause` error at the call site, which is case 1.

Decide:

- **Does the compiler emit guards at exported function boundaries?** Always, never, or only
  where a type erases to something the BEAM could silently confuse (the numeric tower, and
  anything typed as a specific term kind)?
- **Which of the eight violation channels are defended?** Direct calls, mailboxes,
  `EXIT`/`DOWN` signals, timers, ETS reads, decoded external terms, `code_change/3` state from
  a previous version of the module's own types, and ambient config. They have very different
  costs — a guard on an exported function is cheap, a check on every mailbox message is not.
- **What is the cost, and is it opt-out?** purerl's `--checked` parallel module is the only
  compiler-level precedent found, it is **off by default and incomplete by design**, and
  neither Gleam nor purerl defends at all — both document FFI types as trusted and push
  safety to a library. So doing anything here is a departure from BEAM precedent and needs a
  reason better than tidiness.
- **`-spec` emission may not be available at all.** Ticket 02 found a `-spec` survives the
  Abstract Format path by construction but is **lost through Core Erlang**, where Dialyzer
  cannot read the resulting beam and fails silently. So "emit `-spec`" is contingent on ticket
  13's target choice, not a free-standing decision.
- **Do FFI declarations get a `-spec`?** Ticket 06 recommends emitting `-spec` generally —
  cheap, and both Gleam and purerl do it — but left this sub-decision open: for a foreign
  declaration, the spec is an **unverified claim**, asserting to the ecosystem a type nothing
  checked. Emit it anyway, omit it, or mark it distinguishably?
- **What does the language then claim?** The answer determines the honest one-sentence
  statement of the guarantee that ticket 11 has to produce.

Note on the only precedent: purerl's `--checked` emits a **parallel `@checked` module** rather
than modifying the normal one, is off by default, and lets types it cannot check fall through
unchecked. The shape of that design — opt-in, parallel, admittedly partial — is itself a
candidate answer, not just evidence.

## Coupled to ticket 22

### One question inherited from ticket 21, which was descoped

**Does Elm validate values crossing a port at runtime?** If it does, Elm's guarantees survive its
escape hatch — where ticket 06 found Gleam and purerl validate nothing at all — making it the only
known precedent for a language that actually defends its boundary, and therefore the working model
for this ticket's central question.

This was ticket 21's, but Elm was descoped there after that ticket stalled on a bundled narrative
question. **The technical half is small and worth doing here**, scoped tightly: what types may
cross a port, what the generated JavaScript actually does to an incoming value, what happens when
it fails, and how the `Json.Decode.Value` convention differs from a simple typed port. That is a
docs-and-source question, not a community-history one. **Do not let it expand** into The Elm
Architecture or the 0.19 history — that expansion is what stalled ticket 21.

~~This ticket also cannot be settled before [ticket 22](22-how-opinionated.md) says how much the
core claims.~~ **Coupling weakened, and ticket 22 is now deferred pending a walking skeleton.**

Ticket 21 concluded that the only mechanism reaching all eight violation channels is **a check
emitted where an external term becomes a typed value** — codegen, at the points beam-sharp already
compiles (the `receive`, the `handle_info`, the ETS wrapper, the decode wrapper, `code_change`).
That is decidable without knowing how much *domain* opinion the core carries. **Do not treat this
ticket as blocked by ticket 22's deferral.**

What ticket 21 adds directly here: **no language it examined defends its boundary by checking
data.** Roc trusts the host; Unison's handler receives whatever the runtime hands it — consistent
with ticket 06 on Gleam and purerl. They defend by controlling *who may be on the other side*,
which is precisely the property the BEAM denies. So if beam-sharp emits checks, it is doing
something none of the precedents do, and the spec should say so rather than implying it is normal.

## The mechanism already exists — from ticket 09, resolved 2026-08-12

**Do not design the emitted check from scratch. Ticket 09 has already specified it, for a
different purpose, and given it a vocabulary.**

[Ticket 09](09-union-representation.md) §4 requires that the compiler be able to **synthesise a
BEAM guard expression deciding membership** for every member of a structural union, and rejects
at the declaration any union where it cannot. That synthesiser is precisely the check ticket 21
concluded was the only mechanism reaching all eight violation channels — "a check emitted where
an external term becomes a typed value". Same machinery, two uses.

What this hands the ticket:

- **A precise boundary on what is checkable**, which this ticket did not previously have. The
  vocabulary is the BEAM guard set — `is_integer`, `is_binary`, `is_atom`, `is_tuple` plus
  arity, `binary_to_existing_atom` for literal atoms — the same set ticket 08 committed to for
  guards. Anything outside it is not defensible by an emitted check, and that is now a stated
  limit rather than an open question.
- **A reason the numeric-tower case is cheap**: `is_integer/1` is exactly the discriminator the
  union machinery already emits for an `int` member, so defending ticket 06's outcome 3
  (`add(1.5, 2.5)` returning `4.0`) costs nothing new to build.
- **A partial answer to "is it opt-out?"** — the discriminator is *not* optional inside the
  language, since exhaustive matching on a union depends on it. What remains genuinely optional
  is emitting it at the **exported boundary**, which is this ticket's decision and unchanged.
- **A warning about scope.** purerl's `--checked` is incomplete by design: types it cannot check
  fall through unchecked. Under ticket 09's rule the beam-sharp compiler *refuses* the
  undecidable case at the declaration instead — so the incompleteness surfaces earlier and in a
  different place. That is a genuine difference from the only precedent, and the spec should say
  so.

Also relevant: ticket 09 §5 establishes that **nominal identity is unenforceable across the
Erlang boundary**, because the BEAM has no construction discipline. So whatever is defended here
is defended by checking *shape*, never by trusting provenance — which is the same conclusion
ticket 21 reached from the other direction (no precedent language defends by checking data;
they all control who may be on the other side, a property the BEAM denies).

## Sharpened by ticket 10 — resolved 2026-08-12

**Forging the tag is caught. Forging the payload is not.** That is a more precise statement of
this ticket's problem than the map previously held, and it is now *observed* in Gleam rather
than argued ([`prototypes/10c_gleam_forge.erl`](../prototypes/10c_gleam_forge.erl), Gleam 1.18.1
/ OTP 28):

```
describe(purple) forged        : {caught,error,case_clause}   % bad TAG   -> crashes
area({circle, <<"str">>})      : {ok,<<"str">>}               % bad PAYLOAD -> returns it
```

The second line is a function spec'd `shape() -> float()` returning a **binary**. Ticket 06's
third outcome — silent unsoundness — demonstrated in the BEAM's flagship statically typed
language. The asymmetry has a cause worth carrying into the design: a clause head tests the
tag because the tag is what pattern matching *is*, and the payload is bound, not checked. So
any defence has to be emitted **where a term becomes a typed value**, which is ticket 21's
conclusion arrived at from the other direction.

Two smaller inheritances:

- **`ToExistingAtom(string) -> atom | :nothing`** (ticket 10 §4) is a boundary operation and
  belongs in this ticket's inventory of places an external value enters.
- **`ParseAtom<T>(string)`** is *not* — it lowers to a binary match returning compile-time-known
  atom literals, touching neither the atom table nor `binary_to_existing_atom`. It is the same
  discriminator machinery ticket 09 §7 already assigned here, in its cheapest form: worth noting
  as the shape emitted checks should aim for.

## Notes

HITL. Surfaced by ticket 06. Blocked by 11 (what the type system claims) and 12 (whether
partial functions are permitted at all) — this ticket decides how the claim is *defended*,
which only makes sense once the claim exists.

## Constraints from ticket 11 — resolved 2026-08-12

- **Ticket 11 deliberately did not decide this**, and its guarantee sentence was chosen to be
  **stable either way** — it pins the guarantee to the *shape* of a term, never its provenance,
  because guards check shape too. So whichever way this goes, the sentence stands unchanged.
- **The language-level half of the answer is already built.** External values arrive as `term`;
  the clause head is the decoder; the exhaustiveness residual forces the boundary case. This
  ticket owns only the remaining question: whether a **typed** parameter gets defensive guards
  emitted against a foreign caller — ticket 06's `add(1.5, 2.5)` returning `4.0`.
- **`ValidateAs<T>` is a mechanism this ticket can reuse** rather than invent: a generated,
  type-directed structural check, already specified, already O(n) and already explicit.
- **One channel is closed by construction.** A foreign fun cannot be called from beam-sharp at
  all (arrows carry no runtime evidence of their signature; the top arrow `none() -> term()` is
  uncallable), so there is no fun-shaped violation to defend against — only MFA, which is data.
- **The rejected option is recorded as reversible**: higher-order contract wrapping is purely
  additive later. If this ticket wants defended arrows, nothing in ticket 11 blocks it.

## Constraints from ticket 12 — resolved 2026-08-12

**This ticket now has a concrete, measured reason to emit guards** — one that did not exist when it
was charted.

Ticket 12 §6 rejected omitting the compiler-generated failure arm for functions proved exhaustive.
Measured on OTP 28: omission saves **40 bytes (4.8%)** and costs the entire crash report — the
error class becomes `if_clause` (wrong, and there is no `if` involved), and the frame carries an
arity instead of the offending argument, with no file or line. Evidence:
[`prototypes/12a_failure_arm.erl`](../prototypes/12a_failure_arm.erl).

The reason the saving is *unsound* rather than merely unattractive is this ticket's subject.
`erlc` omits the arm only when coverage is proved over **all terms**, so nothing can defy it.
beam-sharp's exhaustiveness is over the **declared type**, a strictly smaller set, and ticket 06
found values outside it arrive through eight channels — while ticket 21 established there is no
link-time closure on the BEAM, so "no foreign caller exists" is unprovable.

**Therefore: emitted boundary guards are the only sound route to the codegen saving.** If this
ticket decides to emit guards at exported functions, defying values are rejected at the edge and
internal omission becomes sound rather than optimistic. If it decides not to, the arm stays
everywhere and the 40 bytes are simply forgone.

Restricting omission to non-exported functions is *not* an alternative — a foreign value entering
through an exported function reaches private ones unchallenged. It collapses into the guard
question.

Note also that ticket 12 §6 aligns with ticket 13: on the Abstract Format path `erlc` inserts the
arm and it cannot be suppressed, so the saving is only *available* on the Core Erlang path, which
already forfeits `-spec` and Dialyzer.

## Constraints from ticket 13 — resolved 2026-08-12

**This ticket loses an argument rather than gaining one, and the loss makes it narrower and
cleaner.**

Ticket 13 chose the **Erlang Abstract Format**. Three consequences land here.

1. **Ticket 12's codegen saving no longer exists.** The section above concludes that "emitted
   boundary guards are the only sound route to the codegen saving" of the omitted failure arm.
   That saving was only ever *available* on the Core Erlang path — and on the Abstract Format
   `erlc` inserts the `match_fail` arm itself, with no way to suppress it (visible in the
   generated Core: [`prototypes/13a_target_measurements.md`](../prototypes/13a_target_measurements.md) §3).
   **So there is nothing to buy.** This ticket's remaining motivation for emitting guards is
   **ticket 06's third outcome — silent unsoundness — alone.** Decide it on honesty, not on bytes.

2. **The `-spec` availability question is closed, and the ordinary case is decided.** This ticket
   listed "`-spec` emission may not be available at all" as contingent on ticket 13. It is
   available: a `-spec` survives the Abstract Format path by construction and is lost silently
   through `.core`, both measured (13a §2). Ticket 13 §6 rules that **the compiler emits a `-spec`
   for every function whose beam-sharp type is known**, widening to the nearest expressible
   supertype where a set-theoretic type has no Erlang spelling — sound, and silent by default since
   `-Wunderspecs`/`-Wspecdiffs` turn warnings *on*.

   **What remains this ticket's, unchanged, is the FFI sub-decision**: whether a foreign
   declaration gets a `-spec`, given that there the spec is an unverified claim asserted to the
   ecosystem. That is a boundary-defence question, not a target question.

3. **The 13/18 joint-decision requirement is discharged.** Ticket 13 said twice that the two
   "must be decided together, or ticket 06's recommendation withdrawn". That coupling was
   **conditional on the Core Erlang branch**, so choosing the Abstract Format dissolves it.
   Ticket 06's recommendation stands unwithdrawn, and this ticket is no longer on its critical
   path — which matters, since this ticket is blocked behind the deferred ticket 22.

## Constraints from ticket 14 — resolved 2026-08-12

**This ticket inherits one new instance of its own problem, and loses part of its scope to a
compile-time answer.**

- **The reply channel is 18's, not 14's.** Ticket 14 §1 measured five ways a client API function
  can be handed a pid that is not the server it expects
  ([`14d`](../prototypes/14d_wrong_pid_outcomes.erl)). Four are exits. The fifth — two servers
  accepting the **same request shape** and replying with **different types** — returns a wrongly
  typed value silently (`{ok,4200}` where a binary was declared). That is ticket 06's third
  outcome reappearing in the *reply* channel, and 14 explicitly assigned it here. Note a typed
  process handle would not have caught it either: the pid arrived from outside, and ticket 21 says
  the foreign caller cannot be ruled out.
- **Part of the mailbox case is answered at compile time.** Ticket 14 §4 established that
  narrowing a callback's *argument* is unsound and that beam-sharp rejects it by contravariance —
  a check Dialyzer does not perform. So the "typed function called from raw Erlang" case, in the
  specific shape of a callback that declares it accepts less than `term`, is a compile error here
  rather than something runtime guards must defend.
- **Gleam's mailbox is now measured, not inferred.** Unmatched messages are `logger:warning`-ed
  and discarded ([`14b`](../prototypes/14b_gleam_mailbox_probe.erl)); an ill-typed payload on a
  valid subject is not detected at all; and Gleam's *named* subjects are forgeable from raw Erlang
  by enumerating `registered()/0` ([`14c`](../prototypes/14c_gleam_named_forgery.erl)). Ticket 06's
  finding that neither Gleam nor purerl defends against any of this now has direct evidence at the
  mailbox, which is the channel this ticket cares most about.
- **A blind spot this ticket may want to own more of.** Ticket 14 §6 found that a *mis-shaped*
  clause for a system message never fires and the mandatory catch-all absorbs it in silence
  ([`14g`](../prototypes/14g_handle_info_blind_spot.erl)). 14 closes it via the compiler-known
  prelude stratum. If that proves insufficient, the residue is a boundary-defence question.

~~Blocking note: this ticket remains blocked by ticket 22, which is `deferred`.~~ **Stale — corrected
2026-08-13.** The relation was dropped on 2026-08-12 (see the ticket 16 section below); ticket 22's own
deferral note says the coupling is weaker than stated and this ticket is not blocked by it.

## Constraints from ticket 27 — resolved 2026-08-12

**Choosing generics made your problem strictly worse, and it was measured rather than argued.**

27 §6 probed whether an emitted polymorphic `-spec` — which ticket 13 §6 obliges the compiler to
emit for every function whose type is known — is enforced by anything downstream. Measured on OTP
28.5, `dialyzer` against a PLT of erts/kernel/stdlib
([`27b`](../prototypes/27b_polymorphic_spec_enforcement.erl), control
[`27c`](../prototypes/27c_polymorphic_spec_control.erl)):

```erlang
-spec map([A], fun((A) -> B)) -> [B].      %% Ys is [binary()]; hd(Ys) + 1  ->  SILENT
-spec map_mono([integer()], fun((integer()) -> binary())) -> [binary()].
                                           %% hd(Ys) + 1  ->  CAUGHT
```

The control fires, so the probe is sensitive. **Erlang's spec grammar accepts type variables;
Dialyzer does not enforce the relation across them**, reading `A` and `B` as `any()`.

**Three consequences for this ticket.**

1. **Do not count the emitted spec as a defence for polymorphic functions.** For a monomorphic
   beam-sharp function, a raw Erlang caller that runs Dialyzer at least gets a warning. For a
   polymorphic one it gets nothing. This is a **regression**, not a neutral gap — the defence
   inventory now has to be taken per-function-kind, not per-language.
2. **It is a ninth face of ticket 06's silent unsoundness**, and of a new sort: 06's eight channels
   are about a *value* arriving badly typed, while this is the *published contract* failing to
   check. Worth naming separately when this ticket tallies the surface.
3. **It is not an argument for emitting guards on polymorphic functions.** 27 §2 makes type
   variables opaque precisely so that nothing inspects a value of type `TSource` — a guard emitted
   at the boundary of a polymorphic function would have nothing to test, since the shape is chosen
   by the caller. Whatever this ticket decides about emitted guards applies to the **ground** parts
   of a signature only.

**Unchanged**: ticket 13 already removed 18's other motivation (ticket 12's 40-byte saving is
unavailable on the Abstract Format target), so **silent unsoundness remains 18's sole remaining
motivation** — and 27 has just widened it.

## Constraints from ticket 15 — resolved 2026-08-12

**One of the eight violation channels now has a declared defence, decided elsewhere.** Ticket 15
settled that a foreign function declared to return `result<T, E>` gets a compiler-emitted
`try`/`catch` wrapper, yielding a compiler-known
`type foreign_error = (:error, term) | (:throw, term) | (:exit, term);`.

Three things that bind this ticket:

- **This is ticket 21's mechanism, instantiated.** 21 concluded the only defence reaching all eight
  channels is a check emitted where beam-sharp already compiles. The foreign wrapper is one such
  point. This ticket decides the other seven, and should treat the wrapper as the worked precedent
  for shape rather than re-deriving it.
- **It defends the *outbound* direction only** — beam-sharp calling foreign code. The silent
  unsoundness this ticket exists for is *inbound*, an untyped caller entering a typed function, and
  nothing in 15 touches it.
- **Exit signals are not catchable** (measured, OTP 28,
  [`prototypes/15d_which_classes_a_wrapper_catches.erl`](../prototypes/15d_which_classes_a_wrapper_catches.erl)).
  A locally-raised `exit/1` and an exit *signal* are different mechanisms sharing a keyword. Any
  defence this ticket designs around process termination must not assume a wrapper can observe one.

**Also: ticket 15 recorded a correction relevant to this ticket's Elm question.** No Elm claim is
load-bearing anywhere in the error model; the narrow question this ticket owns — does Elm validate
values crossing a port at runtime — is untouched and still open. The standing instruction not to
let it expand stands.

## New case from ticket 16 — 2026-08-12

[Ticket 16](16-ad-hoc-polymorphism.md) §4 adds a fifth **codegen obligation**: a serialisation
encoder generated from the declared type, against a mapping the language publishes. It was adopted
on a measured argument — OTP's `json:encode/1` fails on **tuples at any depth, at runtime**, with
`{unsupported_type, Offender}`, and tuples are beam-sharp's workhorse (ticket 09's newtype remedy,
ticket 15's `(:error, E)`). Generating the encoder moves that failure to compile time.

**The consequence for this ticket: a generated encoder trusts its input.** It is emitted from the
*declared* type, so a term arriving through any of the eight violation channels that does not
actually inhabit `T` is either encoded against the wrong shape or crashes inside generated code
**the author never wrote and cannot read in a diff**. That is this ticket's silent-unsoundness
problem at a new site, and it is *worse* than the hand-written case for review purposes.

This stacks with what ticket 27 §6 already handed over — an emitted polymorphic `-spec` is inert,
so choosing generics made the boundary strictly weaker. Ticket 16 does not widen the eight
channels; it adds a consumer that assumes they were defended.

**Blocker removed 2026-08-12**: the Linear relation making this ticket blocked by ticket 22 was
stale. Ticket 22's own deferral note says in bold that the coupling is weaker than originally
stated and **this ticket is not blocked by it**. The relation has been dropped; this ticket is on
the frontier.

## Constraint from ticket 17 — resolved 2026-08-13

**A partial repair arrives, and it hands this ticket a two-tier boundary to argue over rather than
a uniform one.**

Ticket 27 §6 found that choosing generics made the emitted boundary strictly weaker — a polymorphic
`-spec` is documentation, Dialyzer reads the variables as `any()` — and handed that here.
[Ticket 17](17-pipeline-and-comprehension.md) §2 measured the repair
([`prototypes/17a`](../prototypes/17a_lowering_recovers_the_relation.erl), OTP 28):

```
-spec roundtrip_lowered_to_comprehension([integer()]) -> [binary()].   % inlined: exact
-spec roundtrip_lowered_to_generic_call([any()])      -> [any()].      % called: everything gone
```

Lowering a compiler-known prelude operation to an **inlined** form recovers the element relation
exactly. Emitting a **call** to the generic prelude function loses both sides — and loses *more*
than calling `lists:map/2` would, because beam-sharp's own declared spec overrides the success
typing of its body.

**Three consequences for this ticket.**

1. **The emitted boundary is two-tier, and the tiers are not a documentation distinction — they are
   observable in the `.beam`.** Compiler-known operations emit precise types; identical user-written
   generics emit `[any()]`. Whatever this ticket decides about emitted guards has to say which tier
   it applies to, and whether a user-written generic is defended *more* because its spec says less.
2. **Ticket 17 §3 extends this to fold**, so the rule is uniform across the collection surface: the
   mechanism is inlining a monomorphic body the analyser can see through, not comprehensions
   specifically.
3. **The valve is new surface.** `|?>` emits a `case` per stage matching `(:error, _)`. What a
   foreign caller can put into a valve chain — and whether a term that is neither the success type
   nor a well-formed `(:error, E)` is caught, crashes, or flows on — is this ticket's question, not
   17's. 17 §4 deliberately did not defend it.

**One argument this ticket had is now stronger.** Ticket 13 already removed the 40-byte saving as a
motivation, leaving silent unsoundness alone. Ticket 17 adds a second consumer of undefended data
alongside 16 §4's generated encoder: an **inlined** prelude operation is emitted against the declared
element type, so a foreign term that does not inhabit it is operated on inside code the author never
wrote — the same objection 16 raised for the encoder, now at every pipeline stage rather than at
serialisation boundaries only.

---

## Answer — resolved 2026-08-13

**The eight channels were never eight questions: guards are emitted only where the function's own
body would not already object, always where generated code consumes the value, and never on type
variables.**

[Ticket 11](11-type-system-shape.md) had already defended every `term → typed` transition *inside*
the language by making narrowing syntactic, so five of ticket 06's channels were closed on arrival
and what remained was every point where a **type is declared at an entry**. The guarantee, sitting
beside 11's, is **"a foreign term that breaks your types will crash — not always where it entered,
but never silently"** — ticket 06's outcome 1-or-2, never outcome 3, with one named limit.

**The census is why it is that and not more.** Measured across all of stdlib and kernel, **83.3% of
exported parameter positions are bare variables**: Erlang buys outcome 2 for free from its BIFs and
pays nothing at the boundary, so claim C tops up only where the free check is absent — which, after
[16](16-ad-hoc-polymorphism.md) and [17](17-pipeline-and-comprehension.md), is exactly where
*generated code has replaced a body you could read*.

**A foreign declaration may promise only what one BEAM guard decides in O(1)**; `list<Order>` is an
error at the declaration and crosses as `list<term>` plus `ValidateAs<T>`, whose `result` forces the
failure arm. That is **ticket 11 §2's rule applied verbatim at a second site**, and it closes
channels 5, 6, 8 and 10 together while **dissolving the FFI `-spec` sub-question rather than
answering it** — a checked claim needs no exception to ticket 13 §6. This is **Ecto's idiom made
uniform**: measured in a local Elixir application, 9 changeset pipelines beside 5 ETS reads that all
bind the payload bare — *the same shape the Gleam probe produced*, because "you filled that table
yourself" is precisely what [ticket 21](21-escape-hatch-precedents.md) says you cannot prove here.
**Gleam trusts its `@external` and publishes the false claim as a `-spec`** (measured: a declared
`-> Int` returned `41.5`), and **Erlang and Elixir are not precedents at all** — neither has a
construct that declares a foreign type, so they cannot break a claim they never made.

**The state channel is wider than charted and [ticket 14](14-concurrency-and-otp-model.md) left it
open**: `sys:replace_state/2` let any process substitute a state whose declared-`int` field then
returned a binary. Defence therefore sits at the *entrances* — `ValidateAs<State>` in
`code_change/3`, `init` trusted, nothing per-message — with `sys:replace_state` recorded as a
**named limit**, a point 21's mechanism cannot reach by construction because OTP applies the fun
inside a loop beam-sharp does not compile.

The analysis is **function-local**, decided by the standing constraint: whole-aggregate analysis
would let an edit to one file silently move another file's emitted boundary, reintroducing the blast
radius one-function-per-file removed. **There is no opt-out.** The cost was measured and is small
(+3–5 bytes per `is_integer`, call time below the ±0.09 ns/call resolution), and one structural
finding kills a design option: **elision is exported-vs-local, not local-call vs remote-call**, since
a BEAM function has one entry label — so a guarded-public/unguarded-internal pair is impossible, and
interior functions already pay nothing.

**Elm is the one language that genuinely defends its boundary, and it does not transplant** — it
synthesises a decoder per incoming value, but it owns *the one door*, where beam-sharp's callers
arrive by mailbox, ETS, timer, `DOWN` and `code_change`. **This partially retracts ticket 21**, whose
*"no language defends by checking data"* is false as a general claim; the sharpened version, and the
one this ticket used, is that **checking data is what you do at a door you own**. Two corroborations
are worth keeping: Elm's admissible port set is **exactly ticket 09 §4's rule reached independently
on a different runtime**, and **outcome 3 survives inside Elm's checking boundary** (`1e300` through
an `Int` port) — a leak beam-sharp does not inherit, because `is_integer` is exact. The tag/payload
asymmetry was sighted **three times in one session** — Gleam's FFI, a real Elixir ETS read, an OTP
callback head — which is this ticket's strongest evidence that a pattern match is not a check.

**The guarantee, in one sentence, to sit beside ticket 11's:**

> **A foreign term that breaks your types will crash — not always where it entered, but never
> silently.**

Ticket 11's sentence covers what happens inside the language; this one covers what arrives from
outside. Both hold unconditionally, with one named limit (§3).

## 0. The eight channels were never eight questions

Tallied against what the closed tickets already decided, ticket 06's eight channels sort into two
piles by a single test: **did the term arrive somewhere beam-sharp had to *match* it, or somewhere
beam-sharp *declared* a type for it?**

| # | Channel | Status entering this ticket | Why |
|---|---|---|---|
| 2 | Mailbox | **closed** | 14 §4 — a callback may not narrow its argument below `term`. It arrives as `term`, the clause head decodes it, and 11 §2 makes that a guard. |
| 3 | `EXIT`/`DOWN` | **closed** | Mailbox messages with compiler-known shapes (14 §6); `Reason` is honestly `term`. |
| 4 | Timers | **closed** | A timer message *is* a mailbox message. |
| 6 | Decoded external terms | **closed** | Arrive as `term`; `ValidateAs<T>` is the explicit decode (11 §2, 15). |
| 8 | Ambient config | **closed**, conditionally | Same as 6 — *if* the FFI declaration says `term`. §2 makes that unconditional. |
| 1 | Direct calls | **live** | `int Add(int a, int b)` — the type is declared, never matched. |
| 5 | ETS reads | **live** | Turns on what the wrapper's FFI declaration claims. → §2 |
| 7 | `code_change/3` | **live**, and wider than charted | → §3 |
| 10 | Reply channel (14 §1) | **live** | The client API function declares the reply type. → §2 |

**Ticket 11 had already defended every `term → typed` transition inside the language.** What was
undefended is every point where a *type is declared at an entry* — three real questions, not eight.

The reason is worth keeping: 11 made narrowing **syntactic**. You write the clause head, and 11 §2
restricts what you may write there to what a BEAM guard decides in O(1). The check is not a policy
the compiler applies; it is a consequence of the only spelling available. Channels that force a
match are self-defending. Channels that accept a declaration are not.

So this ticket is not about *how much* to check. It is about whether **a declaration is a claim or
a promise**.

## 1. Guards are emitted where the body would not already object

Three candidate claims were live. The chosen one is C.

| | The sentence | What is emitted |
|---|---|---|
| A | *"Your types are checked among beam-sharp code. At the Erlang boundary they are documentation."* | nothing — Gleam's position |
| B | *"Your types hold, whoever calls you."* | discriminator on every ground parameter |
| **C** | *"A wrong term from outside will crash — not always at the call site, but never silently."* | a guard **only** where the body's own operations would not object |

C is a **stated guarantee**, not a confusability heuristic: ticket 06's outcome 1-or-2, never
outcome 3. The four cases are the whole rule.

**(a) The body already objects — nothing emitted.**

```csharp
int LineCount(list<Line> ls);

([])       -> 0;
([_, ..t]) -> 1 + LineCount(t);
```

```erlang
line_count([])    -> 0;
line_count([_|T]) -> 1 + line_count(T).
%%   mymod:line_count(42)  =>  ** exception error: no function clause
```

**(b) The body is total over the wrong term — guard emitted.**

```csharp
int Add(int a, int b);
(a, b) -> a + b;
```

```erlang
add(A, B) -> A + B.                                          %% what C refuses to ship
%%   mymod:add(1.5, 2.5)  =>  4.0

add(A, B) when is_integer(A), is_integer(B) -> A + B.        %% what C emits
%%   mymod:add(1.5, 2.5)  =>  ** exception error: no function clause matching mymod:add(1.5,2.5)
```

**(c) Generated code consumes it — guard emitted unconditionally, no analysis.** 16 §4's encoder,
17 §2's inlined prelude operations, `ValidateAs<T>`. Undefended, the encoder produces *well-formed
JSON with the wrong type on the wire*, from code the author never wrote and cannot read in a diff:

```erlang
to_json(#{id => <<"7">>, customer => <<"acme">>, lines => []})
  =>  <<"{\"id\":\"7\",\"customer\":\"acme\",\"lines\":[]}">>
```

**(d) Not visible at this compile — guard emitted.** Conservative default. C's rule is *emit unless
the body demonstrably objects*; the burden is on omission, which is what keeps it an analysis rather
than a judgement call.

**Type variables are never guarded** — 27 §3, a variable has nothing to test, the shape is the
caller's. C applies to the ground parts of a signature only.

### Why this is a departure worth making, given that nothing on the platform does it

**Measured, not assumed** (`local`, OTP 28 — every exported function in stdlib and kernel, abstract
code from the shipped `.beam` files; a parameter counts as defended only if *every* clause
constrains it structurally or mentions it in a guard):

```
exported functions              : 4193
  every parameter defended      : 512 (12.2%)
exported parameter positions    : 7606
  bare variable, no guard       : 6333 (83.3%)
```

Five parameters in six arrive at an OTP exported function completely untested. That is not an
oversight in the platform's most battle-tested codebase — **it is what having no static claim buys
you.** Erlang gets ticket 06's outcome 2 for free from its BIFs: pass a float where a list was meant
and `length/1` badargs at first touch. Outcome 3 only happens when a wrong term traverses the
*entire* body without meeting an operation that objects, which is why the numeric tower is the
canonical case.

**So C is deliberately the smallest departure that closes outcome 3**, and it converges with the
platform rather than departing from it: Erlang already achieves "crash eventually" for free, and
beam-sharp tops it up only where the free check is absent — which, after 16 and 17, is precisely
where *generated code has replaced a body you could read*.

**Elm is the one counter-example, and it does not transplant** (`local`, Elm 0.19.1 —
[`research/18-elm-port-validation.md`](../research/18-elm-port-validation.md)). Elm **does** defend:
`Optimize/Port.hs toDecoder` synthesises a decoder from the declared port type and
`_Platform_setupIncomingPort` runs it on every incoming value, byte-identical under `--optimize`.
Elm code is unreachable unless it succeeded. But Elm owns **the one door** — `return { send: send }`
— where beam-sharp's callers arrive by mailbox, ETS, timer, `DOWN` and `code_change`, none of which
traverse compiler-emitted code. **The mechanism transfers; the coverage does not.**

Two further findings from that file bind here:

- **Elm's admissible port type set is exactly "types with a decidable structural test"** — a closed
  whitelist rejecting functions, type variables, `Dict`, `Set`, `Result` and *every* custom union
  including a payload-free enum. That is **ticket 09 §4's rule, reached independently on a different
  runtime**, and 11 §3's arrow exclusion with it. Real corroboration for the mechanism §2 relies on.
- **Outcome 3 survives inside Elm's checking boundary**: `_Json_decodeInt` accepts any finite whole
  number, so `1e300` passes an `Int` port and `n + 1 == n`. **beam-sharp does not inherit this** —
  `is_integer/1` is exact and BEAM integers are arbitrary precision. Elm's leak is JSON's number
  model, not a flaw in the idea, and it is the measured reason claim B is harder to keep than it
  sounds.

### What it costs

Measured (`local`, OTP 28.5, arm64 Darwin — [`prototypes/18a_guard_cost.md`](../prototypes/18a_guard_cost.md)):

- **Bytecode**: +3–5 bytes of `Code` per `is_integer`; **+13 bytes (+17.8%)** for the realistic
  tuple discriminator, the most expensive case in the set — which nonetheless *shrinks* the `.beam`
  file by 4 bytes, because the tag literal displaces import-table entries.
- **Call time**: at or below the method's ±0.09 ns/call resolution for one guard, two guards, **and
  the four-test tuple discriminator**. Only four `is_integer` on `add/4` resolves at +0.44–0.87
  ns/call, and that figure is confounded by body optimisation the guards themselves enabled.
- **Not established**: JIT-emitted native code size (§1b tried and failed); any release but 28.5;
  any architecture but arm64; cost at a cold or megamorphic call site.

**The qualitative half is the larger return.** A guard turns a silent `4.0` into a `function_clause`
naming the offending argument — and in the tuple case it moves the blame from a compiler-generated
literal inside `erlang:element/2` to *the caller's own term in the caller's own function*.

**And one structural finding kills a design option this ticket had floated.** The discriminator for
elision is **exported vs local-only, not local-call vs remote-call**: a BEAM function has one entry
label shared by both call kinds. An exported guarded function pays its guard on every call including
from inside its own module; the same code un-exported has the test elided entirely. So *"emit a
guarded public entry plus an unguarded internal one"* cannot be done with one function, and interior
functions already pay nothing — which is the shape C wanted anyway.

## 2. A foreign declaration may promise only what one guard checks — and structured types cross in two steps

**The rule**: a foreign function's declared return type may mention only what a BEAM guard decides
in **O(1)**. Anything deeper is a **compile error at the declaration**.

```csharp
// ALLOWED — checkable in one guard, so the compiler checks it
int                  Now()                        = [Erlang("erlang", "system_time")];
binary               Encode(term t)               = [Erlang("erlang", "term_to_binary")];
pid | port | :undefined Whereis(atom name)        = [Erlang("erlang", "whereis")];
list<term>           EtsLookup(atom tab, term key) = [Erlang("ets", "lookup")];

// REJECTED at the declaration
list<Order> EtsLookup(atom tab, term key) = [Erlang("ets", "lookup")];
//          ^ error: a foreign return type must be checkable in one guard.
//            `list<Order>` needs every element inspected. Use `list<term>` and validate.
```

Note `whereis` in that list: `erlang:whereis/1` really does return `pid() | port() | undefined`, and
**all three members are guard-decidable** (`is_pid`, `is_port`, `=:= undefined`), so the honest
signature is *also* the legal one. That is the rule working rather than biting — the union you were
going to have to write anyway is exactly what the compiler will check.

The crossing is one visible line, and its type forces the failure arm:

```csharp
result<list<Order>, ValidationError> Lookup(int id) =>
    EtsLookup(:orders, id) |> ValidateAs<list<Order>>();

binary Describe(int id);

(id) -> Lookup(id) switch {
    [o, ..rest]  => Format(o),
    []           => <<"no such order">>,
    (:error, e)  => Report(e)          // cannot be omitted: ticket 12, no opt-out
};
```

**This is ticket 11 §2's rule applied verbatim at a second site**, not a new rule. 11 made the clause
head the only way a `term` becomes typed and capped it at O(1); this refuses to let the FFI
declaration be a back door around it. It closes channels **5, 6, 8 and 10** together, since all four
are "what did a foreign declaration promise".

**It also dissolves the FFI `-spec` sub-question rather than answering it.** That sub-question existed
because an FFI spec asserts to the ecosystem a type nothing checked. Under this rule the declared type
is always O(1)-decidable and guarded on return, so the emitted `-spec` is a **checked claim like any
other**, and ticket 13 §6's blanket rule needs no exception.

### Why: the only platform precedent publishes a false spec, measured

`local`, Gleam 1.18.1 / OTP 28. Two `@external` declarations given deliberately wrong types:

```gleam
@external(erlang, "probe_ffi", "lookup")
pub fn lookup(id: Int) -> List(Order)      // Erlang side returns [{order, <<"7">>, <<"acme">>}]

@external(erlang, "probe_ffi", "count")
pub fn count() -> Int                      // Erlang side returns 41.5
```

It compiled without a warning. The generated Erlang:

```erlang
-spec lookup(integer()) -> list(order()).
lookup(Id) ->
    probe_ffi:lookup(Id).                  %% that is the entire body

-spec count() -> integer().
count() ->
    probe_ffi:count().
```

```
first_id(1)   : <<"7">>    is_integer -> false     % declared -> integer()
add_one()     : 42.5       is_integer -> false     % declared -> integer()
```

**Gleam trusts the declaration and publishes the false claim as a `-spec`.** A raw Erlang caller
running Dialyzer against that module is *actively misled*, not merely unhelped. Ticket 06's third
outcome, in the BEAM's flagship statically typed language, at the FFI site.

The sharper half is Gleam's generated consumer:

```erlang
case probe_ffi:lookup(Id) of
    [{order, Oid, _} | _] -> Oid;
```

**The clause head tested the tag and the arity and bound `Oid` bare.** The match *succeeded* and
handed the binary through. This is ticket 10's forge asymmetry — tag caught, payload not — and it is
why the "declare anything, check one level deep" option fails: that option **is** this behaviour with
one extra layer of tag.

**Erlang and Elixir are not precedents**, and the reason is precise: neither has a construct that
declares a foreign function's type. NIFs and ports return arbitrary terms; `-spec` and `@spec` are
Dialyzer-only, never runtime; Elixir 1.19's set-theoretic checker infers from code at compile time and
has no FFI declaration to enforce. **Having no static claim, they cannot break one.** Gleam is the only
language on the platform with the exact construct this section decides.

Erlang's one built-in boundary check confirms the shape of the gap (`local`, OTP 28):

```
binary_to_term/2 [safe]     : {order,<<"7">>}     % wrong-shaped term: passes straight through
unknown atom under [safe]   : {error,badarg}      % atom-table exhaustion: refused
```

**`safe` protects a resource, not a claim.** It has no opinion about whether the term is the shape
you expected.

### The idiom already exists — at one channel out of eight

**Elixir's Ecto changeset is structurally identical to step 2**: `cast/3` takes an untyped map (the
`list<term>` moment), `validate_*` narrows, `apply_action/2` yields `{:ok, %User{}} | {:error, _}` —
untrusted data in, a typed value or a failure out, with the failure in the return type so it cannot
be ignored. That is `ValidateAs<T>` returning `result<T, ValidationError>`, hand-written, and the
whole Phoenix world runs on it.

And it is used for **user input and nothing else**. Measured in a local Elixir application
(`predictex`): 9 `|> cast(` pipelines and 29 `validate_*` calls — beside 5 ETS reads, every one of
which does this:

```elixir
case :ets.lookup(@table, match_id) do
  [{^match_id, cached}] -> cached      # tag pinned, arity checked, payload taken on trust
  [] -> GenServer.call(__MODULE__, {:load, match_id})
end
```

**The same shape as the Gleam probe**, arrived at independently by a careful developer, because there
is no reason to distrust a table you filled yourself.

So this section is not new discipline. **It is the platform's own idiom made uniform, with the
compiler noticing which channel you skipped** — and the reason to make it uniform is that *"you
filled that table yourself"* is exactly what ticket 21 established you cannot prove here.

**The cost, stated honestly**: those five ETS reads would each grow a validate step. That is a real
change to how code reads, not a free win. Most FFI pays nothing — `erlang:system_time`,
`term_to_binary` and `erlang:whereis` are all declarable as-is, the last of them at its *true* return
type. The tax lands precisely where a *structured* type is being claimed from foreign data, which is
where the claim is expensive to keep and where Gleam's silently was not.

**Worth noting what the rule does to a sloppy declaration.** `ets:lookup/2` returns `[tuple()]` and
`file:read/2` returns `{ok, Data} | eof | {error, _}` — a author reaching for `binary Read(...)` is
already wrong about OTP, and the O(1) rule catches that at the declaration rather than at the first
`eof`. The check that exists for foreign *callers* turns out to also catch the author's own
misreading of the function they are importing.

## 3. The state channel is defended at its entrances, not on the message path

Channel 7 was charted as "`code_change/3` state". **It is wider than that, and ticket 14 left it
open**: 14 §4 narrowed the callback's *request* argument to `term` by contravariance, but its own
example still declares the **state**:

```csharp
(:reply, int, Account) HandleCall(term, From, Account);
```

That position is reachable from outside, measured (`local`, OTP 28):

```erlang
sys:replace_state(P, fun(_Old) -> {account, <<"one">>, <<"lots">>} end).
```

```
normal                     : 100
after sys:replace_state    : <<"lots">>
  is_integer(that balance) : false
```

`balance/1` is declared to return an integer and returned a binary — and the callback's clause head
`#account{balance = B} = S` matched tag and arity and bound `B` bare. **The third sighting of the
tag/payload asymmetry in this ticket**, after the Gleam FFI probe and the ETS idiom.

The state has three entrances, and the cost cliff decides where to stand:

| Entrance | Frequency | Who produces it | Defence |
|---|---|---|---|
| `init/1` | once per process | beam-sharp's own typed code | none needed |
| `code_change/3` | once per hot upgrade | a *previous version* of your own types | **`ValidateAs<State>`**, in the compiler-emitted callback |
| `sys:replace_state/2,3` | any time, any process | anyone with a shell | **none possible** — see below |

The state is structured and touched on **every message**, so checking it per callback is
`ValidateAs<State>` at message rates — the exact unbounded-work-per-message shape ticket 11 §2
refused. Checking at the entrances costs **one validate per hot upgrade**.

This is ticket 21's *check where a term becomes a typed value* applied a third time, and the first
time the principle has bought a large saving rather than cost one.

**The named limit.** `sys:replace_state` applies the supplied fun **inside OTP's own loop**, which
beam-sharp does not compile. It is therefore a point 21's mechanism cannot reach *by construction* —
not a decision, a limit, and the spec states it rather than papering over it. It has the right shape
for one: reaching it requires a shell and a deliberate act. **Rejected: an O(1) tag check per
callback** — roughly two instructions and it would catch gross substitution, but not the
same-shaped-wrong-payload case actually measured above, so it would claim a defence one level deep,
which is exactly what §2 refused for the FFI.

## 4. The analysis is function-local

C asks "would the body object?". **It looks at the exported function's own clause heads and body,
and no further.** A value handed to another function counts as unchecked, and is guarded.

```csharp
// describe.bs                     // format.bs — same aggregate, different file
binary Describe(int id);           binary Format(int n);
(id) -> Format(id);                (n) -> Integer.ToBinary(n);   // badargs on a non-integer
```

Whole-aggregate analysis would follow into `Format`, find the badarg, and emit no guard on
`Describe`. Then an edit to `format.bs` alone —

```csharp
(n) -> Cache.Put(n);               // stores it; nothing objects any more
```

— **silently changes the emitted boundary of `describe.bs`**, a file the author never opened and
which shows no diff.

**The standing constraint decides it.** One function per file exists so an agent's `write_scope` is a
file with bounded blast radius and a reviewable single-file diff; whole-aggregate analysis
reintroduces exactly the blast radius that rule removed. Ticket 12 made the structurally identical
call, keeping the failure arm everywhere rather than accepting a saving whose soundness depended on
something not locally visible.

Function-local makes C **nearly as stable as B** — a guard can only move when you edit the function
it sits on — at a fraction of B's cost, and keeps the analysis cheap and explainable, which ticket 23
will need. The cost is extra guards on pass-through functions specifically; the census bounds it,
since most exported functions constrain their arguments in their own clause heads, which
function-local analysis sees perfectly well.

**Rejected: whole-aggregate with an emitted manifest** of what was guarded. It recovers the
visibility, but adds a build artefact the spec must define, version and keep stable, and hands
ticket 23 a dependency it did not ask for.

## 5. No opt-out

Matching ticket 12's precedent that exhaustiveness is a hard error with no escape. C's guards are
already minimal — emitted only where the body would not object — so there is little left to switch
off, and under the standing constraint an opt-out is one more thing an agent must be prompted about.
**Rejected**: a per-module attribute (the one-sentence guarantee would need a clause, and a module
that opted out looks identical from the calling side) and a global flag (it moves the decision from
the code to a build script nobody reviews).

## 6. Two questions dissolved rather than answered

**The valve needs nothing new.** 17 §4 handed over what a foreign caller can put into a `|?>` chain.
The lowering's success arm binds bare —

```erlang
case validate(R) of
    {error, _} = E -> E;
    V              -> check_stock(V)
end
```

— which looks like the fourth sighting of the same hole, and is not, because of where the value comes
from. Every stage is either beam-sharp code (typed body, nothing foreign entered it) or an FFI
declaration whose `result<T, foreign_error>` is **entirely O(1)-checkable** (`is_integer`, or a
2-tuple tagged `:error`/`:throw`/`:exit`) and therefore guarded on return under §2. The discrimination
itself is sound by ticket 15's rule: a `result<T, E>` whose `T` could contain an `(:error, _)` is a
collapse the compiler already rejects at the declaration.

**17 §1's two-tier question resolves to a principle: defence follows who wrote the code, not who wrote
the spec.** 17 asked whether a user-written generic is defended *more* because its emitted spec says
less. No — spec precision governs what Dialyzer can tell a raw Erlang caller, a different mechanism
from an emitted guard. What actually differs is that an **inlined** compiler-known operation is code
the author never wrote, operating on the declared element type: that is §1's case (c), guarded
unconditionally, exactly like 16 §4's encoder. A user-written generic is ordinary code and gets the
ordinary analysis.

## 7. Consequences forced elsewhere

- **[Ticket 26](26-data-modelling.md) gains a constraint, not a decision.** Guards test *shape*, and a
  record's shape on the BEAM is 26's unresolved erasure choice. A **tagged tuple** makes the
  discriminator free — one tag test — where a **map** erasure needs key-presence plus value tests.
  18a measured the tuple discriminator at +13 bytes (+17.8% of the `Code` chunk), the most expensive
  case in the set, so the erasure choice now has a boundary-cost consequence 26 must weigh. This
  ticket does **not** settle erasure.
- **[Ticket 21](21-escape-hatch-precedents.md) takes a partial retraction.** Its *"no language in the
  file defends its boundary by checking data; they defend by controlling who may be on the other
  side"* is false as a general claim — Elm was descoped there and Elm does **both**. The sharpened
  version, which is the one this ticket used: **checking data is what you do at a door you own**, and
  the BEAM's problem was never that checking is unusual but that there is no door.
- **[Ticket 23](23-what-the-language-owes-an-agent.md) gets a worked anti-example.** Elm's port
  rejection is a synchronous JS `throw` Elm code never sees, and **under `--optimize` the entire
  message collapses to a bare URL** — no port name, no value (elm/core #1043, open since 2019-09-16).
  A language that defends its boundary correctly and then makes the rejection unreadable. 23 also
  inherits an open question this ticket declined to pay for: whether the emitted boundary should be
  **inspectable**, since under §1 and §4 it is invisible in the surface language.
- **[Ticket 20](20-untheorised-term-shapes.md) inherits one question.** §2 makes *"what one BEAM guard
  decides in O(1)"* a load-bearing set — it is now the admissible FFI return type set, not only the
  union-discriminability vocabulary. **Binaries and bitstrings are exactly where that set is
  unspecified**, and 20 already holds three sightings of binaries as where precision dies.
- **The walking skeleton (map fog) owes one measurement.** `ValidateAs<State>` in `code_change/3`
  (§3) is an O(n) traversal on a rare path — the first codegen obligation whose *frequency* is the
  argument for affording it. The skeleton should confirm a hot upgrade's cost at a realistic state
  size, since the reasoning here is "upgrades are rare", not "the traversal is cheap".

## 8. Not decided here

- **Record erasure** — ticket 26's, above.
- **Outbound defence.** Elm is inbound-only (its outbound encoder is `_Json_wrap`, identity), so it
  offers no precedent, and ticket 15 already settled the outbound direction with the compiler-emitted
  `try`/`catch` wrapper. Nothing in this ticket touches it.
- **Higher-order contract wrapping**, still rejected and still recorded as reversible (11 §3): it is
  purely additive later if defended arrows are ever wanted.
- **JIT-emitted native code size** of a guard — 18a §1b tried and failed; the `.beam` figures stand.

## Evidence

| Source | What it established | Provenance |
|---|---|---|
| [`prototypes/18b_otp_guard_census.erl`](../prototypes/18b_otp_guard_census.erl) | 83.3% of exported parameter positions are bare variables; 12.2% of functions defend every parameter | `local`, OTP 28 |
| [`prototypes/18a_guard_cost.md`](../prototypes/18a_guard_cost.md) | +3–5 bytes/`is_integer`, +13 bytes tuple discriminator; call cost below ±0.09 ns/call resolution; elision is exported-vs-local, one entry label per function | `local`, OTP 28.5 arm64 |
| [`prototypes/18c_gleam_ffi_trust.gleam`](../prototypes/18c_gleam_ffi_trust.gleam) | Gleam emits a `-spec` and no check; `-> Int` returned `41.5`, `-> List(Order)` yielded a binary id bound bare by the clause head | `local`, Gleam 1.18.1 |
| [`prototypes/18d_state_channel.erl`](../prototypes/18d_state_channel.erl) | `sys:replace_state/2` replaces a typed gen_server state from any process, declared-integer field returning a binary; and `binary_to_term/2 [safe]` defends the atom table, not the shape | `local`, OTP 28 |
| `predictex` (local Elixir app) | 9 changeset pipelines / 29 `validate_*` beside 5 ETS reads that bind the payload bare | `local` |
| [`research/18-elm-port-validation.md`](../research/18-elm-port-validation.md) | Elm synthesises and runs a decoder per incoming value; admissible set = decidable structural tests; `_Json_decodeInt` accepts `1e300`; `--optimize` collapses the error to a URL | `local` + `src`, Elm 0.19.1 |

## Decisions entry

<!-- The body of this ticket's entry in wayfinder/decisions.md, which is GENERATED
     from blocks like this one. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [Boundary defence](issues/18-boundary-defence.md) — **the eight channels were never eight
  questions.** Ticket 11 had already defended every `term → typed` transition *inside* the language
  by making narrowing syntactic, so five channels were closed on arrival and what remained was every
  point where a **type is declared at an entry**. The guarantee is **"a foreign term that breaks your
  types will crash — not always where it entered, but never silently"**: outcome 1-or-2, never
  outcome 3, with a guard emitted **only where the function's own body would not object** and
  **always** where generated code consumes the value (16's encoder, 17's inlined operations),
  **never** on type variables. **The census is why it is that and not more**: measured across all of
  stdlib and kernel, **83.3% of exported parameter positions are bare variables** — Erlang buys
  outcome 2 for free from its BIFs and pays nothing at the boundary, so C tops up only where the free
  check is absent, which after 16 and 17 is exactly where *generated code replaced a body you could
  read*. **Foreign declarations may promise only what one BEAM guard decides in O(1)**; `list<Order>`
  is an error at the declaration and crosses as `list<term>` + `ValidateAs<T>`, whose `result` forces
  the failure arm — **ticket 11 §2's rule at a second site, closing channels 5/6/8/10 together and
  dissolving the FFI `-spec` sub-question** (a checked claim needs no exception). This is **Ecto's
  idiom made uniform**: measured in a local app, 9 changeset pipelines beside 5 ETS reads that all
  bind the payload bare — *the same shape the Gleam probe produced*, because "you filled that table
  yourself" is what 21 says you cannot prove. **Gleam trusts its `@external` and publishes the false
  claim as a `-spec`** (measured: `-> Int` returned `41.5`), and **Erlang and Elixir are not
  precedents at all** — no construct declares a foreign type, so they cannot break a claim they never
  made. **The state channel is wider than charted and 14 left it open**: `sys:replace_state/2` let any
  process substitute a state whose declared-`int` field returned a binary, so defence sits at the
  *entrances* — `ValidateAs<State>` in `code_change/3`, `init` trusted, nothing per-message — with
  `sys:replace_state` a **named limit**, a point 21's mechanism cannot reach because OTP applies the
  fun inside a loop beam-sharp does not compile. The analysis is **function-local**, decided by the
  standing constraint: whole-aggregate would let an edit to one file silently move another file's
  boundary, reintroducing the blast radius one-function-per-file removed. **No opt-out.** Cost
  measured and small (+3–5 bytes per `is_integer`, call time below the ±0.09 ns/call resolution), and
  one structural finding kills a design option: **elision is exported-vs-local, not local-call vs
  remote-call**, since a BEAM function has one entry label — so a guarded-public/unguarded-internal
  pair is impossible, and interior functions already pay nothing. **Elm is the one language that
  genuinely defends its boundary and it does not transplant** — it synthesises a decoder per incoming
  value, but owns *the one door*; **this partially retracts ticket 21**, whose "no language defends by
  checking data" is false, sharpened to *checking data is what you do at a door you own*. Two
  corroborations worth keeping: Elm's admissible port set is **exactly ticket 09 §4's rule reached
  independently**, and **outcome 3 survives inside Elm's checking boundary** (`1e300` through an `Int`
  port) — a leak beam-sharp does not inherit, since `is_integer` is exact. The tag/payload asymmetry
  was sighted **three times in one session** — Gleam's FFI, a real Elixir ETS read, an OTP callback
  head — which is the ticket's strongest evidence that a pattern match is not a check.
```
