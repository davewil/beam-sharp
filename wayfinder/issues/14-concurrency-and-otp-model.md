# 14 — Concurrency and the OTP model

Type: grilling
Status: open
Blocked by: 05, 06

## Question

What concurrency vocabulary does the language expose?

Decide:

- **Does `async`/`await` survive?** C# developers arrive fluent in `Task` and `await`, but
  the two models are genuinely different: `Task` is a future over a thread pool with
  implicit continuation capture; a BEAM process is an isolated, supervised, addressable
  entity with a mailbox. Mapping `await` onto a process wrapper is possible and may be a
  trap — it would make the most important thing about the platform look like the least
  important thing about C#. The alternative is dropping it for explicit
  `spawn`/`send`/`receive`.
- **How are OTP behaviours expressed?** GenServer, Supervisor, Application — as some
  declaration form, or as plain modules plus attributes?
- **How do multi-clause heads meet OTP callbacks?** This is the feature's best showcase:
  one clause per message shape in `handle_call`/`handle_cast`/`handle_info`. Make the
  ergonomics here excellent; it is the demo.
- **How are message types declared** so that `handle_info` clauses can be checked
  exhaustive over the set of messages a process can receive? Gleam invented typed
  `Subject`s for this. What is the equivalent here, given messages can also arrive from
  untyped Erlang code, from monitors, from timers, and from `:EXIT` signals?
- Links, monitors, and process identity in the type system, if at all.

## Constraint from ticket 06 — the easy route is closed

**Gleam's answer to typed OTP was to not implement the behaviour contract at all.** It emits
no `-behaviour` attribute and builds its own typed abstractions instead. That option is
unavailable here: ticket 00 makes `handle_call/3` and `handle_info/2` the headline feature's
showcase, so this language must actually inhabit the OTP callback contract — which makes
**mailbox defence unavoidable** rather than deferrable to a library.

Useful and cheap: `-behaviour` has **no runtime effect**, verified locally on OTP 28. A module
with no such attribute starts and answers calls under `gen_server:start_link/3`; one that
declares it but omits `handle_cast/2` still compiles. `gen_server` dispatches via
`fun Mod:handle_call/3` and gates optional callbacks with `erlang:function_exported/3` — it
never reads behaviour metadata. Only exports matter. Neither Gleam nor purerl/Pinto emits
`-behaviour` anywhere.

**The alternative shape, from purerl/Pinto**: closures-as-messages through one generic callback
module. Rather than the user's module implementing the callbacks, a single generic module does,
and messages carry the closure that handles them. Worth weighing against per-module callbacks
with multi-clause heads — it is the other end of the design space and it ships today.

**A free guarantee worth knowing about**: the violation channel runs both ways. OTP *validates
the shapes you return* from callbacks and kills the process if they are wrong. So return
positions are already runtime-checked by the platform, at no cost to this language.

## Prior art to consult first (from ticket 03)

- **Alpaca typed process messages by whole-call-graph inference** — it worked out the message
  type of a process from every send site, rather than requiring a declaration. That is a real,
  shipped answer to this ticket's hardest sub-question and should be understood before
  designing an alternative.
- **`Pid[τ]`** — a process identifier parameterised by the message type it accepts. Simple and
  probably necessary in some form.
- **The Uniform-Reply rule is recorded as a *rejection*, not a candidate.** It requires every
  reply from a process to have one type — the explicit opposite of the union-of-clause-types
  approach ticket 00 committed to. Useful precisely as the thing this language does not do.
- **Gleam's actor and message typing is a known gap in the evidence.** Ticket 03 could not
  establish it from primary sources and deferred it here rather than filling it from memory.
  Establish it properly as part of this ticket — Gleam's typed `Subject` machinery is the
  closest existing answer to exhaustive `handle_info` and must not be characterised second-hand.

## Notes

HITL. The layer where the headline feature best justifies itself, which is why OTP is inside
the destination rather than deferred.

## Constraints from ticket 12 — resolved 2026-08-12

**This ticket now carries the crash decision.** Ticket 12 settled that the boundary stance is
**signature-directed**: write the honest value your return type admits, `raise` only where it
admits none. That makes the callback return types decided here the thing that determines where
crashing is the only honest answer.

Worked, from ticket 12 §3:

- `(:reply, int, Account) HandleCall(term, From, Account);` admits **no honest value** for an
  unrecognised request — fabricating an `int` is a lie the type system accepts — so the boundary
  clause must `raise`.
- `(:noreply, Account) HandleInfo(term, Account);` makes `(:noreply, a)` completely honest: the
  message was not addressed to you. No crash needed, and this is *not* silence.
- Widening to `(:reply, int | :bad_request, Account)` makes the value channel appear and the crash
  disappear. **The decision moves into the signature**, where a caller can see it.

So: when specifying `HandleCall`, `HandleCast`, `HandleInfo` and `Init` return types, decide
deliberately whether each admits a failure alternative. That choice *is* the crash policy, and
"crash in a call, ignore in a loop" is only the shadow it casts — ticket 12 rejected the positional
rule for exactly this reason.

Two further inheritances:

- **Every callback taking a `term` gets a mandatory catch-all**, per ticket 11, and it is legal
  because the residual is open (ticket 12 §2). Mailbox defence is unavoidable, as this ticket
  already noted — but the checker now *forces* the clause rather than merely recommending it.
- **`raise` exists** (ticket 12 §5) and produces the BEAM error class, so a callback that crashes
  dies with `function_clause`-shaped information intact and the supervisor sees a well-formed exit
  reason (ticket 12 §6).
