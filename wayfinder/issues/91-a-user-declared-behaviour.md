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

**Round 1 answered 2026-09-25 (David): Q1 yes.** A module may declare a behaviour, another satisfies
it, and F10's presence check reads the user's entries as it reads OTP's. The declaring module emits
`-callback` attributes. Asked beside ticket 99 (ENG-451), which made the protocol's spelling wait on
this one.

## Round 2

**Q2. Do a behaviour and a protocol share one declaration shape: a named block of signatures, each
satisfied by a line naming it?** (Ticket 99's last question too.)

```csharp
// module Jev (index.bs)
behaviour Answering {
    (:noreply, term) HandleAnswer(term tag, Evaluation answer, term state)
}

// module Shop.Geometry (index.bs)
protocol Shape {
    float Area(Self s)
}

// module Triage: satisfied by the module's own functions
behaviour Jev.Answering
HandleAnswer(:triage, answer, s) -> (:noreply, Route(answer, s))

// module Shop.Geometry.Circle: satisfied by a block for the type
record Circle { R: float }
implements Shape for Circle {
    Area(Circle c) -> 3.14159 * c.R * c.R
}
```

Under yes, the declarations are as above. A behaviour's callbacks are the module's own functions,
because a module satisfies it. A protocol's are in an `implements` block, because a type satisfies
it and one module may implement two protocols with an operation name in common. `Self` names the
implementing type. Both declarations live in `index.bs`, as `record` and `type` do (F15). Under no,
each is spelled on its own.

**Q3. How does a library call the module that satisfies its behaviour?**

```csharp
// module Jev
public term Deliver(Answering m, term tag, Evaluation a, term s)
Deliver(m, tag, a, s) -> Answering.HandleAnswer(m, tag, a, s)     // m:handle_answer(Tag, A, S)
```

Proposed: a behaviour's name is also a type, the modules that satisfy it, and its callbacks are
called under the behaviour's name with the module first: `Answering.HandleAnswer(m, …)`. That is the
shape of ticket 99's `Shape.Area(c)`, where the protocol's name qualifies and the dispatching value
comes first, so there is one call form for both. It is not `m.HandleAnswer(…)`, because the dot
projects a field and is never a call (LANGUAGE.md). A module value is its atom; a caller passes one
as `Triage` in value position, checked at the call to satisfy `Answering`.

**Round 2 answered 2026-09-25 (David): Q2 yes, Q3 yes** — *"more explicitly . syntax suggests oop
style semantics, not FP semantics."*

- **Q2.** A behaviour and a protocol are both a named block of signatures in `index.bs`. A module
  satisfies a behaviour with its own functions; a type satisfies a protocol with an `implements`
  block. `Self` names the implementing type.
- **Q3.** A behaviour's name is a type, the modules that satisfy it. A callback is called under the
  behaviour's name with the module first, `Answering.HandleAnswer(m, …)`. A module in value position
  is its atom, checked at the call to satisfy the behaviour. Never `m.HandleAnswer(…)`: the dot
  would suggest OOP semantics where the language's are FP's, and the dot projects a field.

## Round 3

**Q4. May a behaviour's signatures be generic in the satisfying module's own types?**

```csharp
behaviour Answering<S> {
    (:noreply, S) HandleAnswer(term tag, Evaluation answer, S state)
}

// module Triage
behaviour Jev.Answering<Triage.State>
HandleAnswer(:triage, answer, s) -> (:noreply, s with { Last = answer })
```

Under yes, `Triage`'s `HandleAnswer` is checked with `S` as `Triage.State`, so returning the wrong
state is refused, as ENG-437 will check a GenServer's callbacks against OTP's contract (F10 checks
names and presence only). Under no, the
library writes `term` for the user's state and the check stops at the tuple's shape. The type
variable is ground at the `behaviour` line, as ticket 27 §8 requires of any obligation.

**Q5. May a callback be optional?**

```csharp
behaviour Answering {
    (:noreply, term) HandleAnswer(term tag, Evaluation answer, term state)
    optional (:noreply, term) HandleTimeout(term tag, term state)
}
```

Under yes, a satisfying module may leave `HandleTimeout` out, the declaring module emits
`-optional_callbacks`, and a library calling it must first ask whether the module exports it,
`Answering.Implements(m, :HandleTimeout)`, because a call to a missing function crashes. Under no,
every declared callback is required, as F10 requires OTP's mandatory ones, and a library that wants
a default writes it and asks the user to delegate to it.
