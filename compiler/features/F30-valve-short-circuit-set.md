# F30 — The valve stops on a fixed pair, and `:nothing` is the half it is missing

**Status**      **not started** — spec written 2026-08-30 ·
                [ENG-279](https://linear.app/davewil/issue/ENG-279). `ready-for-agent` is
                deliberately **off**: two of ticket 49's own statements moved under
                measurement while this was written, and one of them changes the price
                David accepted. He reads it before anyone builds it
**Implements**  [ticket 49](../../wayfinder/issues/49-what-the-valve-keys-on.md)
                ([ENG-231](https://linear.app/davewil/issue/ENG-231)), resolved
                2026-08-28 — the valve keys on the fixed pair `(:error, _) | :nothing`.
                It **decides nothing**: 49 settled the set, refused shape B on the
                measurement, and overruled 17 §4 on David's answer
**Unblocks**    the `option<T>` chain, which is refused today and is the shape C#'s `?.`
                and TypeScript's optional chaining were borrowed for
**Depends on**  F14 (which built `|?>` and the two-armed lowering), **F31** (whose
                refusal is this feature's precondition — measured met below), F2
                (subtraction computes the residual), F7 (the `switch` the valve lowers to)

## Why this one now

**Because the operator does not serve the construct it was borrowed from, and the fix is a
two-line change to a literal.**

Ticket 17 §4 justified `|?>` as a tier-1 borrow of C#'s `a?.B()` and TypeScript's optional
chaining. Both short-circuit on **null**. Ticket 49 measured that the valve refuses null's
analogue outright, put the question to David, and got a one-line answer: *"`:nothing` is null's
analogue, go with the fixed pair, how `(:error, E)` could replace null boggles the mind."*
17 §4's sentence — *"ticket 15's untagged `result` makes `(:error, E)` the exact analogue of
`null`"* — is **overruled and corrected in place**, on the grounds that a reason is the one thing
null never has.

What makes it now rather than later is that its one precondition landed. Shape C stops on a bare
`:nothing`, so a declaration whose `:nothing` had been absorbed — `option<atom>` normalises to bare
`atom` — would have had every atom short-circuited. 15 §1 refuses that at the declaration, and
**F31 built it on 2026-08-28**. Measured below: the declaration this hazard needed can no longer be
written.

## Where it starts

Measured 2026-08-30 at `4a550cf`. Every quotation below is captured from a run, not from the
ticket.

**The headline case is refused, with the text ticket 49 quoted, still current:**

```csharp
private option<User>    Fetch(int id)
private option<Account> For(User u)

public option<Account> Load(int id)
Load(id) -> Fetch(id) |?> For()
```

> `error: this |?> in Load is over a value that cannot fail`
> `  :nothing | { Kind: :'V1.User' } has no (:error, _) member, so the valve would never stop.`
> `  Write |> instead.`

**The error chain works and must not move.** `Check(id) |?> Use()` over
`result<Valid, :bad>` returns `1`.

**A subject carrying BOTH members is the sharpest before-picture**, because it runs:

```csharp
type Step3 = (:error, :bad) | :nothing | Ok
type Rest3 = :nothing | Ok
type Out3  = int | (:error, :bad)

private Step3 Step(int id)
private int   Use(Rest3 v)          // :nothing reaches the stage, so it is in the parameter

public Out3 Go(int id)
Go(id) -> Step(id) |?> Use()
```

`Go(1) = 1`, `Go(2) = 0`, `Go(3) = (:error, :bad)`. **`:nothing` flows *into* the stage today** —
`Use(:nothing) -> 0` is what answers, and only the error short-circuits.

**F31's refusal — this feature's precondition — fires:**

```csharp
public option<atom> Lookup(int id)
```

> `error: `:nothing` is absorbed by `atom``
> `  the failure channel does not survive normalisation, so the type declared here IS `atom`.`

**Shape B's hazard is refused honestly, and must stay refused.** `Bytes(raw) |?> Decode()` where
`Decode` narrows `binary` to `string` reports *"binary has no (:error, _) member"*. F30 cannot
reach this case by construction — the short-circuit set is a constant, so the valve tests
`subject ∩ {(:error, _), :nothing}` and never `subject \ param` — but the refusal is a control,
because a build that reached for a signature would make it compile and then fail to lower.

## The delta, and why it is small

**Both new arms are literals.** That is the whole reason the fixed pair is cheap where shape B is
not: no signature reaches `bs_lower`, and `bs_emit` needs nothing new. A future session tempted by
a check-time side table should stop here — that table is shape B's cost, and shape B was refused.

1. **`bs_lower:lower/2` emits three arms, not two.** `(:error, e) => (:error, e)` unchanged,
   `:nothing => :nothing` unchanged, and the value arm. The `:nothing` arm is built exactly as the
   error arm is, and for the same reason its comment already gives: the arm's job is to *be* the
   value, so it is rebuilt rather than aliased.

2. **`bs_check`'s infallibility test reads every arm but the last.** It currently takes `ErrTy`
   from **the first arm's pattern** — `[{arm, _, ErrPat, _, _} | _] = Arms` — and asks whether
   `ErrTy ∩ SubjTy` is empty. With three arms the form is the union of every arm except the value
   arm. This keeps the property that clause's own comment prizes: *"the question the compiler
   answers is exactly the question `bs_lower` wrote down."* Deriving the set from a literal in
   `bs_check` instead would put the same constant in two files.

3. **`valve_on_infallible` changes meaning and must change wording.** It fires when the meet with
   **both** members is empty. Its message names `(:error, _)` alone today and would otherwise tell
   an author their type has no error member while the compiler was looking for two things.

4. **The residual is the subject minus both members** — `switch_over` already computes it from the
   arms, so this falls out rather than being written.

5. **The declared return type of existing correct programs widens, and ticket 49 does not say so.**
   This is a finding of the spec, not of the ticket. A short-circuited `:nothing` is returned
   *unchanged*, so the valve's type gains it: `Out3` above must become
   `int | (:error, :bad) | :nothing`, and `Use` narrows to `Ok` alone. **A program that compiles
   today stops compiling until its signature is widened.** F25's corrected-signature diagnostic
   already prints the repair, so the migration is a readable error rather than a silent change of
   meaning — but it is a migration, and it belongs in front of the build rather than behind it.

## Scenarios

**F30.1 — the `option<T>` chain compiles and runs.** The headline, refused today with the text
above. `Load(1)` returns the account; `Load(2)` returns `:nothing`, short-circuited.

**F30.2 — the error chain is unchanged.** `result<Valid, :bad>` through `|?>` still returns `1` and
still propagates `(:error, :bad)`. F14's 319 tests were green on this and none of them may move.

**F30.3 — a subject carrying both members stops on either.** The `Step3` program above, after:
`Go(1) = 1`, `Go(2) = :nothing`, `Go(3) = (:error, :bad)`, with `Use` declared over `Ok` alone.
The residual reaching the stage is the subject minus **both**.

**F30.4 — the widened return type is reported, not silently accepted.** `Out3` left as
`int | (:error, :bad)` must fail with F25's corrected signature naming `:nothing`. This is the
migration scenario and it asserts the error, because a build that widened the type silently would
change what a caller must handle without telling anyone.

**F30.5 — `valve_on_infallible` fires on the meet with both members, and says so.** A subject with
neither member is still refused; a subject with *only* `:nothing` is now **accepted**, which is
F30.1 one level down. The message must name both members — a control on the wording, since the
prose is the whole of the diagnostic's usefulness.

**F30.6 — shape B's hazard stays refused, byte for byte.** `Bytes(raw) |?> Decode()` keeps
*"binary has no (:error, _) member"*. **This is the control that says the build did not reach for a
signature.** Without it, an implementation that keyed on the parameter type would pass every
positive scenario here and fail to lower a program it had accepted.

**F30.7 — the accepted exposure is asserted, so its price is in a test rather than only in prose.**
See below. `:nothing`-as-value is skipped, and the assertion records that this is intended.

**F30.8 — nested valves still number correctly.** `a |?> F(b |?> G())` — F14 synthesises two names
per stage and the counter must stay monotonic with a third arm in play.

**F30.9 — `bs_emit` is untouched.** No signature reaches `bs_lower`; the emitted forms for F30.2's
program are identical before and after. Asserted because it is the claim that distinguishes this
shape from the one that was refused.

## The gate

<!-- dead-path: planned - F30 is not started; this names the gate the build owes. -->
`compiler/bin/check-valve.sh`. **A rejection test, not a stopwatch** — every failure this feature
can produce is visible, which is the opposite of F28 and worth saying so the next author does not
copy the wrong template.

Its `--self-test` needs at least these defects, each an implementation somebody would ship:

- **`error_only`** — nothing built; F30.1 still refused. Today's tree.
- **`nothing_only`** — the error arm dropped while adding the `:nothing` one. Passes F30.1 and
  fails F30.2, which is why the old chain is a scenario rather than an assumption.
- **`param_keyed`** — the build reached for the stage's declared parameter type. Passes F30.1,
  F30.3 and F30.5, and fails **only** F30.6. This is shape B arriving by the back door and it is
  the defect the control exists for.
- **`silent_widen`** — the return type widens without F25's diagnostic. Every positive scenario
  passes; F30.4 is the only thing that sees it.
- **`stale_message`** — the meet changes but `valve_on_infallible` still says *"has no (:error, _)
  member"*. Every behavioural scenario passes and the author is told the wrong thing.

and a green on the correct form beside them, per `spec-check.sh`'s rule from ticket 15.

## Accepted exposure — and it is worse than ticket 49 recorded

Ticket 49 accepted one exposure with the decision: a stage that means `:nothing` as a **value**
rather than as absence is short-circuited, and `valve_on_infallible` stays quiet because the meet
is non-empty.

```csharp
type Answer = :yes | :no | :nothing    // :nothing is a VALUE here, not absence
Ask(q) |?> Record()
```

49 describes the result as *"skipped **silently**, with no diagnostic"*. **Measured 2026-08-30,
that is the state after F30, not the state now.** Today this program is refused, loudly and
correctly:

> `error: this |?> in Go is over a value that cannot fail`
> `  :no | :nothing | :yes has no (:error, _) member, so the valve would never stop.`

So F30 does not leave a gap where a gap was. **It replaces a working diagnostic with a silent
skip** for this shape. That is a materially different price from the one on the record, and it is
recorded here before the build rather than discovered after it. The decision may still be right —
the shape is rare, `:nothing`-as-value is arguably a naming mistake, and the alternative costs a
refusal nobody has designed — but it is David's to reaffirm knowing this, not the build's to assume.

**The deferred remedy, unchanged:** refuse `:nothing`-as-value where a valve can reach it, which is
15 §1's argument one step further out. It needs the reachability question answered first — every
declaration, or only a valve subject? — which is why 49 did not decide it and why this file does
not either.

## Out of scope

- **Deciding anything.** Ticket 49 settled the set on 2026-08-28 and overruled 17 §4 on David's
  answer. Q1 is closed: `:nothing` is null's analogue. If the build turns up a case 49 did not
  cover, that is a ticket.
- **Shape B, in any disguise.** Keying on the stage's declared parameter type was refused on the
  measurement, not on taste: a residual can span N members, and `binary \ string` is a non-empty
  residual with no head and no BEAM guard — `erlc` rejects the only stdlib test as `illegal guard
  expression`, in either polarity. F30.6 is the control that catches it arriving anyway.
- **A surface change.** `|?>` parses today and its precedence is settled. A diff touching
  `bs_lexer.xrl` or `bs_parser.yrl` means something has gone wrong.
- **`CONTEXT.md:129` and `LANGUAGE.md` §5.** Both define the valve by the error member alone and
  are **deliberately stale** until this lands — ticket 49 §4's own instruction, so that no shipping
  document asserts behaviour the compiler does not have. They are paid **by this feature, on the
  day it lands**, and `LANGUAGE.md` §5 feeds `PACKET.md`, so `build-packet.py` must be re-run in
  the same commit.
- **The `:nothing`-as-value refusal.** The deferred remedy above. It needs a reachability decision
  first.

## Done when

`Fetch(id) |?> For()` over `option<T>` compiles and runs; the `result` chain is byte-identical in
its emitted forms; a subject carrying both members stops on either and hands the stage the subject
minus both; a program whose return type has not been widened is refused by F25's corrected
signature naming `:nothing`; `binary |?> Decode()` still says *"binary has no (:error, _) member"*;
`valve_on_infallible` names both members it looked for; `CONTEXT.md` and `LANGUAGE.md` §5 are
updated with `PACKET.md` rebuilt in the same commit; and `check-valve.sh --self-test` has been seen
red on all five defects above, including `param_keyed`, which fails on nothing but the control.
