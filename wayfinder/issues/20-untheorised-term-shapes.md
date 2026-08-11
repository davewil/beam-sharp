# 20 — What must the type system model that set-theoretic theory doesn't yet cover?

Type: grilling
Status: open
Blocked by: 11

## Question

Ticket 04 established that the exhaustiveness mechanism is solved and shipped — but it also
listed what the theory **has not addressed at all**. These are *untheorised*, not merely
unimplemented, and this language inherits every one of them:

- **Binaries and bitstrings.** There is no `<<>>` typing anywhere in either Elixir type-system
  paper. For a BEAM language this is not an edge case: binaries are the string type, the wire
  format, and a first-class pattern-matching construct with size and unit specifiers. A
  multi-clause head matching on binary patterns is *idiomatic Erlang* and the theory is silent.
- **Improper lists.** Zero mentions in the literature.
- **Recursive and parametric types together.** Elixir's own signature milestone is explicitly
  gated on implementing both efficiently — the roadmap language is that failing to would "make
  the type system unfeasible".
- **Row polymorphism** — relevant if maps are to be typed structurally with extensibility.
- **OTP behaviours** — the callback contract as a typed object.

Decide, for each: does this language model it, approximate it, or exclude it — and if
excluded, what does a programmer write instead?

**Binaries deserve the most attention**, because excluding them quietly makes the headline
feature unusable in the domain the BEAM is most used for. Establish what a binary pattern in a
clause head would have to mean type-theoretically before deciding, rather than assuming it
falls out.

Also weigh a product risk named by Castagna himself as an open problem: **readable error
messages and type pretty-printing** — and note that under the map's standing constraint (written
by agents, read by humans) this is a *product* problem rather than a cosmetic one, since the
diagnostic is consumed by an agent in a loop. See [ticket 23](23-what-the-language-owes-an-agent.md). For a language whose entire pitch is "the compiler proves
your clauses cover the input", an unreadable proof failure is not a cosmetic defect — it is
the feature failing in the only place a user meets it.

## Notes

HITL. Surfaced by ticket 04's gap analysis. Blocked by 11, since what the type system *is*
determines what these questions even mean.
