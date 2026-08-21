# 49 — What the valve keys on: the atom, or the declared type?

Type: grilling
Status: open — [ENG-231](https://linear.app/davewil/issue/ENG-231)

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
