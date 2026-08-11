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

## Notes

HITL. The layer where the headline feature best justifies itself, which is why OTP is inside
the destination rather than deferred.
