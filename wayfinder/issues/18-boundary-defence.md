# 18 — Boundary defence: does the compiler emit runtime guards, and where?

Type: grilling
Status: open
Blocked by: 11, 12

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

This ticket also cannot be settled before [ticket 22](22-how-opinionated.md) says how much the
core claims. A language that merely offers types owes its boundary less than one that enforces
domain invariants — you can only defend a claim once you know what it is.

## Notes

HITL. Surfaced by ticket 06. Blocked by 11 (what the type system claims) and 12 (whether
partial functions are permitted at all) — this ticket decides how the claim is *defended*,
which only makes sense once the claim exists.
