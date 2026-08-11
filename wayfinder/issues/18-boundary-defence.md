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
- **What does the language then claim?** The answer determines the honest one-sentence
  statement of the guarantee that ticket 11 has to produce.

## Notes

HITL. Surfaced by ticket 06. Blocked by 11 (what the type system claims) and 12 (whether
partial functions are permitted at all) — this ticket decides how the claim is *defended*,
which only makes sense once the claim exists.
