# 49 — What the valve keys on: the atom, or the declared type?

Type: grilling
Status: **RESOLVED 2026-08-28 — the valve keys on a fixed pair, `(:error, _) | :nothing`** —
[ENG-231](https://linear.app/davewil/issue/ENG-231). Shape B is **refused on the measurement**
([`49a`](../prototypes/49a-what-the-arm-must-be/)): a residual can be unguardable, so it needs a
refusal that does not exist. `:nothing` **is** null's analogue and **17 §4 is overruled** — see
*DECIDED* below. Not built; the build is F30.

Raised 2026-08-21 out of [ticket 31](31-composable-middleware.md), which measured two things that
bear on a remedy [`31c`](../prototypes/31c-middleware-on-the-page.md) had already drafted and
nobody had costed.

## Question

`|?>` short-circuits where its left operand is `(:error, _)`. 31c's **shape B** keys it on the
stage's **declared parameter type** instead:

| | |
|---|---|
| today | `|?>` short-circuits where its left operand is `(:error, _)` |
| shape B | `|?>` short-circuits where its left operand is **not in the stage's declared parameter type**; that member passes through unchanged |

A stage then spells its halt `(:halt, Response)`, or anything else it likes, and the pipeline is
**character-identical** either way — 31c checked that.

**Should it?**

## The two measurements ticket 31 added

**1. The valve does not serve the construct it was borrowed from.** Ticket 17 §4 justified `|?>` as
*"a tier-1 borrow for both halves of the audience simultaneously"* — C#'s `a?.B()` and TypeScript's
optional chaining. Both short-circuit on **null**, whose analogue here is
[ticket 15](15-error-model.md)'s `option<T> = T | :nothing`. Measured
([`Optional`](../prototypes/31d-middleware-measured/Optional/optional.bs)), the valve **refuses it**:

> `error: this |?> in Load is over a value that cannot fail` — *`:nothing | { Kind: :'Optional.User' }`
> has no `(:error, _)` member, so the valve would never stop. Write `|>` instead.*

Under shape B that chain works, because `:nothing` is not in `For`'s parameter type. **This is a
finding against 17's stated borrow rationale**, not a preference: the operator was justified by two
neighbours it does not currently imitate.

**2. Shape A is cheaper than ticket 31 first reported, which cuts the other way.** The two-clause
unwrap that looked like shape A's ergonomic cost was an artefact of a badly declared probe. With the
terminal stage declared `(:error, Response)` — it always halts — the pipeline has one member and the
unwrap is one clause
([`ShapeA`](../prototypes/31d-middleware-measured/ShapeA/shapea.bs), four paths). So the ergonomic
argument for shape B is **gone**, and what remains is the atom's honesty and the `option<T>` gap.

## What it would cost

**Compiler:** 31c argues *nothing it does not already have* — signatures are mandatory
([ticket 04](04-crossclause-exhaustiveness.md)) so the parameter type is known at the call site, and
union members are discriminable by one BEAM guard in O(1)
([ticket 09](09-union-representation.md)), which is the test every clause head already performs. The
emitted code does not change. **That claim is unverified** and is the first thing to measure: the
valve lowers to a two-armed `switch` via `bs_lower.erl`, and whether the arm can be generated from a
parameter type rather than a fixed atom is a question about `bs_check`, not about the algebra.

**Reader:** 31c names the cost honestly and it is the real argument against. Today you recognise
`(:error, _)` on the page. Under shape B you must know the stage's declared parameter type to know
what short-circuits. That is read cost, and read cost carries full weight under the standing
constraint — the same constraint that decided [ticket 32](32-ffi-surface.md) against Elixir's
zero-ceremony FFI.

## Notes

**This is a change to a shipped operator**, not a new one — F14 built `|?>` and 319 tests were green
on it. Reversibility is therefore the wrong frame: the question is whether the current spelling is
*wrong*, and one measurement says it is incomplete against its own justification.

**Do not re-raise** ticket 17's choice of `|?>` over `Result.Then`, or the refusal of an implicit
propagation rule. This asks what the operator keys on, not whether it should exist.

**Most valuable resolved alongside the 25a rewrite**, for the same reason ticket 48 is: that rewrite
is the first honest consumer of the pipeline, and it will write the halt cases out at length.

## Measured 2026-08-28 — [`49a`](../prototypes/49a-what-the-arm-must-be/)

Both of the ticket's own measurements **still hold**, re-run against today's compiler:

- The `Optional` probe is refused with the quoted text unchanged, including after ENG-269 split
  `unreachable_arm` three ways. The quote is current, not stale.
- `ShapeA` runs and returns `{Kind = :'ShapeA.Response', Body = :orders, Code = 200}`. The unwrap is
  one clause.

Three things the ticket did not have.

### 1. The framing premise is mis-sourced, and this changes the question

The ticket says the `option<T>` refusal is *"a finding against 17's stated borrow rationale"* — that
17 justified the valve by two neighbours and was then caught not imitating them. But 17 §4 addresses
this on the record, in terms:

> Ticket 15's untagged `result` makes `(:error, E)` **the exact analogue of `null`**.

So 17 did not leave the analogue open. It assigned it, and gave a reason: the success side is bare,
so a plain `Valid` flows through where a nullable `T?` would. 31c asserts the opposite — *"null's
beam-sharp analogue is `option<T>` … not `(:error, E)`"* — **without citing or answering that
sentence**, and this ticket inherited the assertion.

This is not a gap in 17. It is a **disagreement between two recorded decisions**, and that is the
question worth putting:

| | assigns null's role to | on the grounds that |
|---|---|---|
| 15 §2 | `:nothing` | *"absence carries nothing, failure carries a reason"* — and null is absence |
| 17 §4 | `(:error, E)` | 15's untagged `result` — the success side is bare, as with `T?` |

Both are defensible and they cannot both stand. 15's is the stronger reading of *null*; 17's is the
stronger reading of *the chain's shape*.

### 2. 31c's compiler claim is false in two of three parts

31c argues shape B needs *"nothing it does not already have"*. Measured:

**Survives — the side table.** `bs_lower:valves/1` runs inside `parse_string`, before types exist,
and `bs_emit`'s context carries `env` (types) but not `callees` (signatures). So the arm must be
computed at check time and carried to emit — which is exactly F18's `validators`, F19's `foreigns`
and 41 §2's `imports`. A fourth entry in an established channel, not a new pass. **Pass order is not
the obstacle**, and 31c is right here.

**Fails — the valve stops being two-armed.** A residual can span more than one member, so a chain's
type becomes a union of per-stage residuals. 17 §7's *"a `case` per stage"* survives; the case's
width becomes a function of the subject.

**Fails hard — the arm is not always emittable.** This is the finding:

```csharp
private binary Bytes(binary raw)
private atom   Decode(string s)     // narrows: string is binary's refinement (F10)

Run(raw) -> Bytes(raw) |?> Decode()
```

Shape B short-circuits on `binary \ string`. That residual is **non-empty**, F29's head channel
yields **zero** parts for it, and `erlc` rejects the only stdlib test as `illegal guard expression`
— UTF-8 validity over a whole binary is a linear scan, and no guard BIF performs it. Inverting the
polarity does not help; both arms fail on the same fact.

So ticket 09's *"discriminable by one BEAM guard in O(1)"*, which 31c leans on, **does not hold in
general**. Today that program is refused honestly (`binary has no (:error, _) member`). Under shape
B it would be *accepted* and then fail to lower.

**The compiler delta for shape B is therefore: one check-time side table (precedented), an N-armed
switch (new), and a refusal that does not exist** — *this stage narrows to a type the valve cannot
test*. Cost and read cost now agree, where the ticket had them pulling opposite ways.

### 3. There is a third shape, and nobody has costed it

The ticket presents a binary. A **fixed** short-circuit set is neither:

| | keys on |
|---|---|
| shape A (today) | the atom `(:error, _)` |
| shape B (31c) | the stage's declared parameter type |
| **shape C** | the fixed set `(:error, _) \| :nothing` |

Shape C closes the `option<T>` gap, keeps the arm a **literal** in `bs_lower`, needs no signature at
emit, and **cannot** reach the unguardable residual. That last is structural rather than lucky: the
short-circuit set is a constant, so what the valve tests is always `subject ∩ {(:error, _),
:nothing}` and never `subject \ param`. A meet with a fixed two-member set is a tuple test or an atom
equality, whatever the subject is; row 4 is unreachable by construction. It is also
**closer to the borrow 17 claimed** than shape B is: C#'s `?.` keys on a fixed sentinel, not on the
callee's parameter type.

Its cost is two preconditions, and the second is the serious one:

- `option<atom>` normalises to bare `atom`, so a fixed set would stop on a legitimate success.
  15 §1 refuses this *at the declaration* — **decided, and built as F31 on 2026-08-28**: an
  ordinary `public option<atom> Lookup(int id)` is now refused. Filed as
  [ENG-272](https://linear.app/davewil/issue/ENG-272) — a compiler gap, not a map question, so no
  ticket number and no map entry.
  <!-- corrected 2026-08-28: read "decided, and measured unbuilt: ... compiles clean, exit 0.
       F18 built the collapse check only at the ValidateAs<T> site." True when written; F31
       closed it the same evening. -->
  **This precondition is met.**
- `:found | :nothing` does **not** collapse, so 15 §1 passes it even once built — yet shape C still
  short-circuits on `:nothing`, and `valve_on_infallible` does not fire because the meet is
  non-empty. Shape A has no analogue: `(:error, _)` is a tuple with a tag nobody writes by accident,
  where `:nothing` is a bare atom in the ordinary namespace. **This has no decision behind it.**

## Round 1 to David — 2026-08-28

**Q1. Which member is null's analogue?** 15 §2 and 17 §4 answer differently and the valve implements
17's answer. Everything else here follows from this one.

**Q2. Given the delta above, is shape B still wanted?** It buys the `option<T>` chain and costs a
new refusal plus an N-armed valve:

```csharp
option<User>    Fetch(int id)
option<Account> For(User u)

Load(id) -> Fetch(id) |?> For()     // refused today; works under B and under C
```

**Q3. Does shape C answer Q2 more cheaply, and is its `:nothing` exposure acceptable?** The failure
is silent rather than loud — a stage that means `:nothing` as a value gets skipped with no
diagnostic, because the meet is non-empty and `valve_on_infallible` stays quiet:

```csharp
type Answer = :yes | :no | :nothing    // :nothing is a VALUE here, not absence
Ask(q) |?> Record()                    // shape C short-circuits it anyway
```

The available remedy is to refuse `:nothing`-as-value where a valve can reach it, which is 15 §1's
argument applied one step further out.

**Q4. Does 08 reach shape B?** 08 as amended reads *"narrowing is always written, and what it is
written **as** is a clause head"*. Under shape A the head is visible from the operator alone; under
shape B the marker is written but its pattern comes from a signature elsewhere. 17 §4 treated the
mandatory marker as satisfying 08 — so this is **not** foreclosed, but it is nearer the rule 17
closed than the ticket suggests.

## DECIDED 2026-08-28 — the fixed pair, and 17 §4 is overruled

**David, on Q1:** *"`:nothing` is null's analogue, go with the fixed pair, how `(:error, E)` could
replace null boggles the mind."*

### Q1 — `:nothing` is null's analogue

15 §2 wins, 17 §4 is **wrong and is corrected in place** at
[17 §4](17-pipeline-and-comprehension.md). Its sentence read:

> Ticket 15's untagged `result` makes `(:error, E)` the exact analogue of `null`.

The reasoning was about the *shape of the chain* — the success side is bare, so a plain `Valid`
flows where a nullable `T?` would — and that observation is true. It does not make `(:error, E)`
null. Null is **absence carrying no information**, which is 15 §2's own definition of `:nothing`; a
`(:error, E)` carries a reason, and a reason is the one thing null never has. 17 read the borrow off
the chain's silhouette and never checked it against 15's vocabulary one section down.

This does not disturb the rest of 17 §4. The valve beat `Result.Then` and `[Propagates]` on cost of
mechanism, and none of those comparisons turn on which member is null.

### Q2, Q3 — the valve keys on the fixed pair `(:error, _) | :nothing`

```csharp
option<User>    Fetch(int id)
option<Account> For(User u)

Load(id) -> Fetch(id) |?> For()     // refused before this decision; correct after it
```

**Shape B — keying on the stage's declared parameter type — is refused**, and on the measurement
rather than on taste. 31c argued it needs *"nothing the compiler does not already have"*. Measured
([`49a`](../prototypes/49a-what-the-arm-must-be/)):

- the check-time side table it needs is precedented (F18 `validators`, F19 `foreigns`, 41 §2
  `imports`), so **pass order is not the obstacle** and 31c is right on that point;
- but a residual can span N members, so the valve stops being two-armed; and
- `binary \ string` is a **non-empty residual with no head and no BEAM guard** — F29's head channel
  yields zero parts and `erlc` rejects the only stdlib test as `illegal guard expression`, in either
  polarity, because UTF-8 validity is a linear scan. So **ticket 09's *"discriminable by one BEAM
  guard in O(1)"* does not hold in general.**

Shape B would therefore *accept* a program the compiler refuses honestly today and then fail to
lower it, which needs a refusal nobody has designed. The fixed pair cannot reach that case **by
construction**: the set is a constant, so the valve tests `subject ∩ {(:error, _), :nothing}` and
never `subject \ param`, and a meet with two fixed members is a tuple test or an atom equality
whatever the subject is.

It is also the **closer borrow**, which is what 17 §4 was reaching for and mis-aimed: C#'s `?.` and
TS's optional chaining key on a fixed sentinel, not on the callee's signature.

### Q4 — 08 is not reached

Moot once shape B is refused. Recorded because it was asked: 08's *"what narrowing is written as is
a clause head"* is satisfied under the fixed pair, since the head is a literal the reader can
recognise from the operator alone, exactly as today.

## What the build owes — F30

Not built. The decision is recorded; the compiler still stops only on `(:error, _)`.

1. **`bs_lower` emits three arms, not two** — `(:error, e)`, `:nothing`, and the value arm. Both new
   arms stay **literals**, so no signature reaches `bs_lower` and `bs_emit` needs nothing new. This
   is the whole reason the fixed pair is cheap.
2. **`valve_on_infallible` changes meaning**: it fires when `subject ∩ {(:error, _), :nothing}` is
   empty, not when the subject has no `(:error, _)` member. Its message names the member it looked
   for, so the prose changes with it.
3. **The residual passed to the stage** is the subject minus *both* members, which F2's subtraction
   already computes.
4. **`CONTEXT.md:129` and `LANGUAGE.md` §5 owe an update** — both currently define the valve by the
   error member alone. Deliberately left stale until F30 lands, so no document asserts behaviour the
   compiler does not have.

## Accepted exposure, and what would remove it

Two cases where the fixed pair stops on a value the author meant as a success. David accepted both
with the decision; recorded so the price is not rediscovered as a defect.

**Measured, and now closed rather than accepted.** `option<atom>` normalises to bare `atom`, so a
valve over it would stop on any atom. 15 §1 refuses that *at the declaration* — **decided, and
built as F31 on 2026-08-28**, filed as [ENG-272](https://linear.app/davewil/issue/ENG-272). The
declaration this exposure needed can no longer be written, so **F30's precondition is met** and
this is one exposure, not two.
<!-- corrected 2026-08-28: read "decided and unbuilt ... F30 should not land before ENG-272, or the
     hazard is reachable". ENG-272 shipped; the sentence stood for about six hours. -->

**Measured, and covered by nothing.** `:found | :nothing` does **not** collapse, so 15 §1 passes it
even once built, and the valve still stops on `:nothing` while `valve_on_infallible` stays quiet —
the meet is non-empty. A stage meaning `:nothing` as a value is skipped **silently**:

```csharp
type Answer = :yes | :no | :nothing    // :nothing is a VALUE here, not absence
Ask(q) |?> Record()                    // stops anyway, with no diagnostic
```

Shape A had no analogue of this: `(:error, _)` is a tuple with a tag nobody writes by accident,
where `:nothing` is a bare atom in the ordinary namespace. **The deferred remedy**, if this ever
bites: refuse `:nothing`-as-value where a valve can reach it — 15 §1's argument applied one step
further out. It needs the reachability question answered first (is it every declaration, or only a
valve subject?), which is why it is not decided here.

## Answer

**`|?>` short-circuits on `(:error, _) | :nothing` — a fixed pair, a constant, not the stage's
declared parameter type — and 17 §4 is overruled.**

The per-question detail is in *DECIDED 2026-08-28 — the fixed pair, and 17 §4 is overruled* above;
this is the verdict that section reached.

**31c's shape B is refused on the measurement** ([`49a`](../prototypes/49a-what-the-arm-must-be/)).
Its claim of *"nothing the compiler does not already have"* holds only for the side table it needs,
which is precedented three times over (F18 `validators`, F19 `foreigns`, 41 §2 `imports`) — so
**pass order was never the obstacle**. It fails on two others: a residual can span N members, so the
valve stops being two-armed; and **the arm is not always emittable**. `binary \ string` is a
non-empty residual with **zero** F29 head parts and no BEAM guard — `erlc` rejects the only stdlib
test as `illegal guard expression`, in either polarity, UTF-8 validity being a linear scan. **So
ticket 09's *"discriminable by one BEAM guard in O(1)"* does not hold in general**, and anything
leaning on it inherits the correction. Shape B would accept a program today's compiler refuses
honestly and then fail to lower it. The fixed pair cannot reach that case **by construction**: the
valve tests `subject ∩ {(:error, _), :nothing}`, never `subject \ param`, and a meet with two fixed
members is a tuple test or an atom equality whatever the subject is.

**17 §4 is overruled, and corrected in place.** Its *"15's untagged `result` makes `(:error, E)` the
exact analogue of `null`"* read the borrow off the chain's silhouette and never checked it against
15 §2 one section down — null is **absence carrying no information**, which is `:nothing`, where
`(:error, E)` carries a reason (David: *"how `(:error, E)` could replace null boggles the mind"*).
The fixed pair is also the **closer borrow**: C#'s `?.` keys on a fixed sentinel, not on the
callee's signature. Ticket 08 is not reached — the head stays a literal, recognisable from the
operator alone. **Both of this ticket's own premises were re-measured and held**, including the
diagnostic text after ENG-269.

**Not built — F30**, which owes three arms from `bs_lower` (both new ones literals, so `bs_emit`
needs nothing), a `valve_on_infallible` that fires on the empty meet rather than on the absent
`(:error, _)`, and updates to `CONTEXT.md:129` and `LANGUAGE.md` §5, left deliberately stale until
it lands. **Two accepted exposures**, both measured: `option<atom>` collapses to bare `atom`, which
15 §1 refuses at the declaration — **decided, and built as F31 on 2026-08-28**
([ENG-272](https://linear.app/davewil/issue/ENG-272)), so the precondition F30 was waiting on is met
and that exposure is now closed rather than accepted; and `:found | :nothing` does *not* collapse,
so 15 §1 passes it and the valve stops on `:nothing` **silently**, the meet being non-empty. Shape A
had no analogue of the second — `(:error, _)` is a tuple nobody writes by accident, where `:nothing`
is a bare atom in the ordinary namespace. Deferred remedy recorded: refuse `:nothing`-as-value where
a valve can reach it, which needs the reachability question answered first.

## Decisions entry

<!-- This ticket's entry. wayfinder/decisions.md is GENERATED from blocks like this
     one and carries only the first sentence; the whole entry is read here. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- **What the valve keys on: the atom, or the declared type?** — [ticket 49](issues/49-what-the-valve-keys-on.md),
  raised 2026-08-21 out of 31, resolved 2026-08-28. **`|?>` short-circuits on `(:error, _) | :nothing`** —
  a constant, not the stage's declared parameter type. **31c's shape B is refused on the measurement**
  ([`49a`](prototypes/49a-what-the-arm-must-be/)): its claim of *"nothing the compiler does not
  already have"* holds only for the side table it needs, which is precedented three times over
  (F18 `validators`, F19 `foreigns`, 41 §2 `imports`) — `bs_lower` runs before types exist and
  `bs_emit` sees `env` but not `callees`, so **pass order was never the obstacle**. It fails on two
  others: a residual can span N members, so the valve stops being two-armed; and **the arm is not
  always emittable**. `binary \ string` is a non-empty residual with **zero** F29 head parts and no
  BEAM guard — `erlc` rejects the only stdlib test as `illegal guard expression`, in either polarity,
  UTF-8 validity being a linear scan. **So ticket 09's *"discriminable by one BEAM guard in O(1)"*
  does not hold in general**, and anything leaning on it inherits the correction. Shape B would
  accept a program today's compiler refuses honestly and then fail to lower it. The fixed pair cannot
  reach that case **by construction** — the valve tests `subject ∩ {(:error, _), :nothing}`, never
  `subject \ param`, and a meet with two fixed members is a tuple test or an atom equality whatever
  the subject is. **17 §4 is overruled, corrected in place**: its *"15's untagged `result` makes
  `(:error, E)` the exact analogue of `null`"* read the borrow off the chain's silhouette and never
  checked it against 15 §2 one section down — null is **absence carrying no information**, which is
  `:nothing`, where `(:error, E)` carries a reason (David: *"how `(:error, E)` could replace null
  boggles the mind"*). The fixed pair is also the **closer borrow**: C#'s `?.` keys on a fixed
  sentinel, not on the callee's signature. 08 is not reached — the head stays a literal, recognisable
  from the operator alone. **Both of ticket 49's own premises re-measured and held**, including the
  diagnostic text after ENG-269. **Not built — F30**, which owes three arms from `bs_lower` (both new
  ones literals, so `bs_emit` needs nothing), a `valve_on_infallible` that fires on the empty meet
  rather than the absent `(:error, _)`, and updates to `CONTEXT.md:129` and `LANGUAGE.md` §5, left
  deliberately stale until it lands. **Two accepted exposures**, both measured: `option<atom>`
  collapses to bare `atom`, which 15 §1 refuses at the declaration — **decided, and built as F31 on
  2026-08-28** (ENG-272), so the precondition F30 was waiting on is met and this exposure is now
  closed rather than accepted <!-- corrected 2026-08-28; read "decided and unbuilt, so F30 must not
  land before it" -->; and `:found | :nothing` does *not* collapse, so
  15 §1 passes it and the valve stops on `:nothing` **silently**, the meet being non-empty. Shape A
  had no analogue of the second — `(:error, _)` is a tuple nobody writes by accident where `:nothing`
  is a bare atom in the ordinary namespace. Deferred remedy recorded: refuse `:nothing`-as-value
  where a valve can reach it, which needs the reachability question answered first.
```
