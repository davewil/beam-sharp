# 12 — Totality versus let-it-crash

Type: grilling
Status: open
Blocked by: 04, 11

## Question

Must every function be exhaustive?

The conflict is cultural as much as technical:

- **Enforced totality** is the guarantee that justifies the type system. If clauses must
  cover the input type, a whole class of `function_clause` crashes disappears at compile
  time — and that is the headline claim.
- **But BEAM culture says a badly-shaped message should crash the process.** Erlang's
  `function_clause` error is a *feature*: the process dies, the supervisor restarts it, the
  system stays up. Defensive exhaustive handling of impossible cases is an anti-pattern
  there, not a virtue.
- And the compiler cannot know everything: a message arriving from an untyped Erlang caller
  may have any shape at all, so total-in-theory functions still meet impossible input in
  practice.

Decide the stance. Candidates: total by default with an explicit partial opt-in; partial
permitted with a warning; total only where the input type is fully known and dynamic
elsewhere; or totality enforced at typed boundaries and abandoned at dynamic ones.

Then state how it interacts with **supervision** — if a clause is proven exhaustive but the
runtime value defies it, what happens, and does the process still die cleanly?

## Sharpening from ticket 06

The ticket's framing assumed the choice is between crashing and not crashing. Ticket 06 showed
there is a **third outcome that is worse than either**: silent unsoundness, where a badly-typed
value never crashes at all and the type system is simply wrong. `add(1.5, 2.5)` on a function
typed `Int, Int -> Int` returns `4.0`, quietly.

That reframes let-it-crash as an *ally* of the type system rather than its opponent — a crash
is the honest outcome, and the real enemy is the silent one. Weigh that before treating
totality and let-it-crash as opposed. Ticket 18 handles the emitted-guard question this raises.

## Prior art to consult first (from ticket 03)

**PureScript records partiality in the type and discharges it at a named site** — a
propagating `Partial` constraint. A partial function is not an error; it is a function whose
type says it is partial, and the obligation travels with it until someone explicitly accepts
it. That is a fourth option beyond the candidates above, and it maps unusually well onto
let-it-crash: the crash site becomes a declared, greppable place rather than an accident.

**Hamler removed exactly this mechanism and kept only a warning.** That is a natural
experiment in the option space — worth understanding why before repeating either choice.

## Notes

HITL. This is where the language's philosophy gets decided, not merely its semantics.
