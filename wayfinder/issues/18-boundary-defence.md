# 18 — Boundary defence: does the compiler emit runtime guards, and where?

Type: grilling
Status: open
Blocked by: 11, 12, 22

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

Blocking note: this ticket remains blocked by ticket 22, which is `deferred`.

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
