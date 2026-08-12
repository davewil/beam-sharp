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

## Notes

HITL. Surfaced by ticket 06. Blocked by 11 (what the type system claims) and 12 (whether
partial functions are permitted at all) — this ticket decides how the claim is *defended*,
which only makes sense once the claim exists.
