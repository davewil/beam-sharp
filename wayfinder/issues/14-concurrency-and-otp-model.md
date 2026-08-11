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
