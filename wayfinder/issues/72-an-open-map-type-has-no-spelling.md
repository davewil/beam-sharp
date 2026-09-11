# 72 — An open map type has no spelling, and a foreign fixed-field return needs one

Type: grilling
Status: withdrawn 2026-09-11, the day it was raised — decided by
[ticket 26](26-data-modelling.md) §1 and [ticket 27](27-parametric-polymorphism.md) §7 —
[ENG-358](https://linear.app/davewil/issue/ENG-358). Raised by the ENG-351 grill, round 4 Q10
Blocked by: —

## Why this is raised, and why it is withdrawn

The ENG-351 grill decided (Q8) that a fixed field set is admissible as a foreign return under
[ticket 18](18-boundary-defence.md) §2, and found (Q9) that no guard runs on any foreign return
today (ENG-357). Round 4 then claimed that this program, which compiles and runs on `afdbde0`,
would fail on every call once ENG-357 lands, because a cowboy request carries a dozen keys beyond
the two declared and "a closed member's guard is `map_size(R) =:= 2`":

```csharp
module Web

using :cowboy_req {
    { Method: binary, Path: binary } req(term r)
}

public binary Route(term r)

Route(r) -> :cowboy_req.req(r) switch {
    { Method: "GET", Path: p } => p,
    { Method: m }              => m
}
```

The claim was wrong, and this file was written without grepping the tickets for the decision,
which CLAUDE.md names as the failure to avoid. The `map_size` guard is what `bs_emit` writes for a
closed member in a **pattern match**, so that a closed map pattern cannot match a wider map. It is
not the boundary guard. What a boundary guard on a fixed field set contains is decided:

- **Ticket 26 §1** (settled, David): *"tag test always, presence and value tests per 18 §1,
  exact-set test only where a codegen obligation consumes the record"*, and *"extra fields are
  harmless to projection and to exhaustiveness"*. A foreign wrapper returns the value; it does not
  consume it in 18 §1(c)'s sense (the encoder, `ValidateAs<T>`, an inlined prelude operation).
- **Ticket 27 §7**: no row variables. *"A function generic over any record containing at least
  these fields"* was declined on a measurement, and 26 refuses spread for the same reason: under
  exact field sets, "an `Order` plus whatever else" is a type no signature can be written against.

So `{ Method: binary, Path: binary }` is an exact field set by decision, and the guard ENG-357
emits for it at a foreign return is presence and value tests: `is_map(R)`, `is_binary(map_get('Method', R))`,
`is_binary(map_get('Path', R))`. `Web` compiles and keeps running against a real request. The
extra keys are not in the type and are not checked, which is what 26 chose and measured.

**What ENG-357 inherits from this**: the fixed-field case emits 26's boundary guard, never the
pattern guard. That is written into ENG-357.

## Decisions entry

*None. Nothing was decided here; the decision is 26 §1's and 27 §7's, and this file records
that the question had an answer before it was asked.*
