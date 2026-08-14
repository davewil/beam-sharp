# 33 — Is a function body typed at all, and where does the check run?

Type: grilling
Status: open

Raised 2026-08-14 from building [F3](../../compiler/features/F3-records.md). **Two features have
now hit the same missing seam from opposite directions**, which is the bar this map sets for
raising a ticket rather than bolting a pass onto whichever feature notices it second.

## Question

`bs_check` **never visits a function body.** Measured in the source rather than assumed: it
gathers signatures, checks clause-head exhaustiveness against the parameter product, and
translates guards — and the only expression forms it reads are `e_op`, `e_var`, `e_int` and
`e_atom`, read **inside guards only**. `bs_emit` lowers a call straight to an Erlang call with
nothing checked in between.

**A function body is emitted, not typed.**

So: **is a body typed at all — and if so, where does the check run, and what does it do with a
call whose callee is foreign?**

## Why this is a ticket and not a feature

Because it is a decision with more than one defensible answer, and three closed decisions point
at it without settling it.

- [Ticket 04](04-crossclause-exhaustiveness.md) made signatures mandatory, so **every callee's
  type is already declared**. A body check has nothing to infer — it is containment, the same
  relation [ticket 14](14-concurrency-and-otp-model.md) already uses for behaviour callbacks.
- [Ticket 18](18-boundary-defence.md) §4 made the analysis **function-local**, decided by the
  standing constraint: whole-aggregate would let an edit to one file silently move another
  file's boundary. Whatever this ticket decides has to hold that line.
- [Ticket 11](11-type-system-shape.md) says external values arrive as `term` and **the clause
  head is the decoder** — which answers the *entry* direction and says nothing about a call in
  the middle of a body.

## What is waiting on it, concretely

Four items, none of which is speculative — three are scenarios already written down with their
ids reserved rather than deleted.

| Waiting | Which | What it needs |
|---|---|---|
| F3.3's call-site enforcement | ticket 26 §1 | reject `Update(Order o)` called with an `Invoice`. **This is how 26 §1 phrases the requirement David named**, and F3 could not deliver it — F3 establishes aggregate identity *in the algebra* and there is no call site to reject it at |
| F3.8's projection error | ticket 26 §3 | projecting a field only one union member carries should name the member that lacks it |
| F3.10 | ticket 26 §4 | construction must supply exactly the declared field set. **A body can build a map wearing an `Order` tag without `Order`'s fields and nothing rejects it** — the single largest hole F3 shipped with |
| F2's opaque refinements | ticket 20 §5, ticket 29 | barred from clause heads and foreign declarations, permitted elsewhere — and "elsewhere" is a body, which has no check site to hang the obligation on |

Note the shape of the F3 items: **all three are places where the language has already decided a
rule and the compiler cannot enforce it.** That is a different thing from an unimplemented
feature, and it is why F3's own file says a build claiming them "has stopped checking".

## What is already decided — do not re-raise

| Decided | By |
|---|---|
| Signatures are mandatory, so a callee's type is always declared | [04](04-crossclause-exhaustiveness.md) |
| The analysis is **function-local** | [18](18-boundary-defence.md) §4 |
| One relation — plain set-theoretic containment, coinductive | [11](11-type-system-shape.md), [09](09-union-representation.md) |
| A foreign call declared to return a `result` gets a compiler-emitted wrapper; there is **no `try`** in the surface | [15](15-error-model.md) |
| A foreign declaration may promise only what one BEAM guard decides in O(1) | [18](18-boundary-defence.md) §2 |
| Narrowing is **always written, never inferred** | [08](08-head-and-guard-syntax.md) |

So this ticket adds no checking *rule*. It decides whether the rules already agreed are checked
in a body, and where.

## The sub-questions

**1. Is a body typed, or only its calls?** The cheapest answer that discharges the table above is
**argument containment at call sites and nothing else** — every call's arguments checked against
the callee's declared parameter types, plus construction against its declared field set. That
reaches all four rows without a general expression type-checker, and it is worth asking whether
the general version buys anything the map has asked for.

**2. What happens at a foreign call?** [Ticket 32](32-ffi-surface.md) made a foreign declaration a
real emitted function with a signature, so a foreign callee has a declared type like any other
and this may simply not be a special case. Worth confirming rather than assuming — it would be
the second time 32's decision dissolved a question raised before it landed.

**3. Does the check produce a residual, or a yes/no?** Everything else in this compiler answers
with the *set that is left over*, because [ticket 04](04-crossclause-exhaustiveness.md) found the
residual **is** the missing case and [ticket 23](23-what-the-language-owes-an-agent.md) makes it
the thing an agent is handed to write. A call-site failure has no obvious residual, and if the
answer is a yes/no then this is the first diagnostic in the language that does not hand back
something to write — which 23 makes a real cost rather than an aesthetic one.

**4. Does anything change in the emitted code?** [Ticket 18](18-boundary-defence.md) emits a guard
where generated code consumes a value. If a call site is checked statically, that is an argument
for emitting *less*, not more — the inverse of every codegen obligation so far.

## Notes

Blocked by nothing. **Most valuable before F4**, since angle brackets bring `option<T>` fields and
therefore more construction sites, and F3.10 is already unpoliced.

**Do not re-derive the "no inference" position.** Ticket 04 settled mandatory signatures and
ticket 27 §1 turned instantiation into matching rather than solving. This ticket asks where a
check runs, not whether types are inferred.

**Linear**: ticket 33 is **ENG-200, not ENG-199** — the `NN → ENG-(166+NN)` mapping breaks here,
because ENG-199 was taken by F3's feature PRD, which is not a wayfinder ticket. The map's own
instruction is to verify the arithmetic when creating a ticket; this is the first time it has
not held.
