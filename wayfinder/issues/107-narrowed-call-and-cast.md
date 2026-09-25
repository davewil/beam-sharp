# 107 — May `HandleCall` and `HandleCast` narrow their request argument? Ticket 14 §1 against §4

Type: grilling
Status: claimed 2026-09-25 — [ENG-470](https://linear.app/davewil/issue/ENG-470). Raised 2026-09-25
out of [ENG-437](https://linear.app/davewil/issue/ENG-437)'s stop line; round 1 below
Blocked by: —

## Why this is raised

[14](14-concurrency-and-otp-model.md) says two things that cannot both hold for `HandleCall`:

- **§1** (*"It is not needed"*): the message is built inside a client function whose signature is
  checked, *"and the `Request` union `HandleCall` proves exhaustive over is the same union the
  client API constructs"*.
- **§4** (*"The behaviour contract is a type, and the user narrows it"*): containment is function
  subtyping, contravariant in arguments, so narrowing an **argument** is the unsound move, *"The
  argument position must be `term`"*, correcting prototype 01e's `HandleCall(Request, …)`.

Under §4 a clause set over `Request`'s members leaves a `term` residual and needs a catch-all, so
nothing is proved about `Request`. ENG-437 builds §4's check; its first step reaches every
`HandleCall` and `HandleCast` in the corpus, and the shipped example LANGUAGE.md §13 advertises as
*"proved to cover `Request` with no catch-all"* is one of them.

## The program

`compiler/examples/Counter/counter.bs`, shipped:

```csharp
module Counter

behaviour GenServer

type Request = :get | (:add, int)
type Reply   = (:reply, int, int)

public (:ok, int) Init(int seed)
Init(seed) -> (:ok, seed)

public Reply HandleCall(Request request, term from, int state)
HandleCall(:get, from, state)      -> (:reply, state, state)
HandleCall((:add, n), from, state) -> (:reply, state + n, state + n)
```

Measured at `2f9b742`, OTP 28, by starting it with `gen_server:start_link('Counter', 5, [])` from
Erlang:

```
gen_server:call(P, get)          -> 5
gen_server:call(P, bogus, 1000)  -> {'EXIT', ...}
is_process_alive(P)              -> false
exit reason                      -> {function_clause, ...}
```

One call from any process, which no B# type can prevent (ticket 21: no foreign caller can be
ruled out), kills the server and its state with it.

## Round 1

### Q1 — May `HandleCall` and `HandleCast` narrow their request argument to the module's own type?

`HandleInfo` is not in question: its messages come from monitors, timers and any `!`, so §4's
`term` stands for it (ENG-437's own program).

**Under no (§4 as written),** Counter must widen:

```csharp
public Reply | (:reply, :unknown_call, int) HandleCall(term request, term from, int state)
HandleCall(:get, from, state)      -> (:reply, state, state)
HandleCall((:add, n), from, state) -> (:reply, state + n, state + n)
HandleCall(_, from, state)         -> (:reply, :unknown_call, state)

type NoReply = (:noreply, int)

public NoReply HandleCast(term msg, int state)
HandleCast((:add, n), state) -> (:noreply, state + n)
HandleCast(:reset, state)    -> (:noreply, 0)
HandleCast(_, state)         -> (:noreply, state)
```

Compiled at `2f9b742`, exit 0. (Observed, not investigated: `n` is bound out of a `term` here and
`state + n` is accepted.)

The server survives a stray call. The cost: a `Request` member added later and never handled
falls into `_` silently. This is the language's defining check, lost on the showcase callback,
and LANGUAGE.md §13's *"no catch-all"* sentence goes. Compiler delta: ENG-437 as filed, applied
to all three callbacks.

**Under yes (§1),** Counter compiles as it is today, and the checker proves `HandleCall` covers
`Request`: add `:reset` to `Request` and the missing clause is named. The cost is the measurement
above: a caller that does not go through the client functions kills the server. Measured at
`2f9b742`: with `:reset` added to `Request` and no clause for it, the compiler refuses
`HandleCall is not exhaustive … HandleCall(:reset, x, n) -> ...`. Compiler delta:
ENG-437's contract check exempts the request argument of `HandleCall` and `HandleCast` (it still
checks the return and the other arguments), and ticket 14 §4 is amended in place.

A yes opens one follow-up, asked only if yes is the answer: what a stray call does. The server
crashing is the default above; the alternative is a compiler-emitted closing clause.

## Decisions entry

<!-- Written when the ticket resolves. -->
