# 91 — A user-declared behaviour: may a library name the callbacks a user module supplies?

Type: grilling
Status: open — [ENG-432](https://linear.app/davewil/issue/ENG-432). Raised 2026-09-25 by the exemplar review (ENG-191)
Blocked by: —

## Why this is raised

Two exemplars want a library to own callbacks, and B# knows five behaviours only (`GenServer`,
`Supervisor`, `Application`, `GenStatem`, `GenEvent`). Tickets 21 and 31 named the mechanism
(Roc's `requires`, a typed `-callback`) and 31 found middleware did not need it; nothing decided
it. Measured on `a0f9cbf`: `behaviour Provider` → `error: no behaviour named Provider`.

- **25g friction 1.** Jev's Elixir server is `use Jev.Server`: the library is the GenServer and
  calls the user's `handle_answer/3`. In B# the library is a function, `Jev.Ask`, and every user
  writes the `HandleInfo` clause the library would have written. Forgetting it gives a server
  that ignores its answers, silently.
- **25f friction 7.** ReqLLM adds a provider as a module implementing its `Provider` behaviour. In
  B# a provider is a member of a closed union and a clause at each dispatch site; a third party
  cannot add one without editing the union.

## Round 1

**Q1. May a module declare a behaviour, and another satisfy it, checked the way F10 checks OTP's?**

```csharp
module Jev

behaviour Answering {
    (:noreply, term) HandleAnswer(term tag, Evaluation answer, term state)
}

// module Triage
behaviour Jev.Answering

HandleAnswer(:triage, answer, s) -> (:noreply, Route(answer, s))
```

(The declaration's spelling is a placeholder for the question. Whether a behaviour's signatures
may be polymorphic in the user's state is a second question, not asked here.)

Under yes this compiles, a `Triage` missing `HandleAnswer` is refused as `behaviour Jev.Answering
is declared and not satisfied`, and `Jev` calls it through the module it was handed. Under no the
two lines are the error above, and the exemplars stay as they are.

Compiler delta: a `behaviour Name { signatures }` declaration in `index.bs`; the table F10 reads
(`bs_check`'s compiler-known callback contract) gains the user's entries, keyed by module; the
presence check F10 runs reads it; the module emits `-callback` attributes so Erlang and Elixir
users of it are checked by their own compilers. A call from the library to the user module is a
call through a module value, which is the second question this raises and is not asked here.
