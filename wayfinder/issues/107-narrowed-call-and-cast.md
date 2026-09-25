# 107 — May `HandleCall` and `HandleCast` narrow their request argument? Ticket 14 §1 against §4

Type: grilling
Status: resolved 2026-09-25 — [ENG-470](https://linear.app/davewil/issue/ENG-470). Raised 2026-09-25
out of [ENG-437](https://linear.app/davewil/issue/ENG-437)'s stop line; one round, the follow-up
answered with Q1
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

## Prior art, measured 2026-09-25 (asked for by David before answering Q1)

Both probes are kept: [`107a`](../prototypes/107a_elixir_genserver_strays.exs) (Elixir 1.20.4,
OTP 29) and [`107b`](../prototypes/107b_gleam_actor_strays.gleam) (Gleam 1.18.1, `gleam_otp`
1.3.0, `gleam_erlang` 1.3.0).

| | Narrowed request handler | A stray call or message | Missing case in the handler |
|---|---|---|---|
| **Elixir** `GenServer` | allowed; nothing checks it | `handle_call(:bogus, …)` → `FunctionClauseError`, **server dies**. The `handle_info` that `use GenServer` injects **logs** *"received unexpected message in handle_info/2"* **and survives**; a `handle_info` the author narrows dies like `handle_call` | not detected (no warning from 1.20's type checker) |
| **Gleam** `gleam/otp/actor` | the handler is typed over the `Subject`'s message type | never reaches the handler: the actor's selector puts `process.select_other(Unexpected)` under the user's, and the loop **logs** *"Actor discarding unexpected message"* **and continues**. Measured: raw `erlang:send(Pid, {"bogus", 1})`, actor alive, state intact | **refused at compile time**: `Inexhaustive patterns … Add(n:, reply:)` |
| **B#** today | allowed (F10 checks names and presence) | `function_clause`, **server dies** (above) | **refused**, naming the clause (above) |

What Gleam shows is that the two properties Q1 sets against each other are not in tension there:
the handler is exhaustive over a closed type **and** the server survives a stray, because the
filtering happens **before** the typed handler, in code the library writes, not in the user's
clauses. Gleam pays for it with the typed channel, `Subject(msg)`, which carries a reference the
selector matches on. Ticket 14 §1 declined that for B# (`Pid[τ]`, *"not expressible"* under
ticket 09's structural types), which is why B#'s narrowing lives on the handler instead.

A stray **call** to a Gleam actor is an `Unexpected` message too (read from `actor.gleam`, not
measured): discarded, so its caller waits out its timeout rather than killing the actor. Elixir's
default injected `handle_info` does the same for a stray info message.

## Answers

**A1 (David, 2026-09-25):** *"Yes, with Gleam's discard behaviour."* This answers Q1 (yes, narrowing
is allowed on `HandleCall` and `HandleCast`) and the follow-up Q1 named in the same answer: a
stray call or cast is discarded with a warning, as `gleam_otp`'s actor does, and the server lives.

So:

- `HandleCall` and `HandleCast` may declare their request argument as the module's own type, and
  the checker proves the clauses cover it, exactly as the shipped Counter does today.
- `HandleInfo`'s message argument stays `term`, as ticket 14 §4 has it: its messages come from
  monitors, timers and any `!`.
- The contract check ENG-437 builds still applies to everything else: every callback's return is
  covariant in its contract, and every other argument is contravariant.
- After the author's clauses of a narrowed `HandleCall` or `HandleCast`, the compiler emits one
  closing clause that logs the stray message and returns `{noreply, State}`. A stray cast is
  dropped; a stray call is never answered, so its caller waits out its own timeout (Gleam's
  measured behaviour for a stray message, and what its source says happens to a stray call).
  The closing clause is emitted code only: exhaustiveness is proved over the author's clauses and
  never credits it.

## The compiler delta

- **ENG-437's containment check**: the request argument of `HandleCall/3` and `HandleCast/2` is
  exempt from contravariance; `HandleInfo/2`'s is not. Returns and the remaining arguments are
  checked as ENG-437 describes.
- **`bs_emit`**: a module declaring `behaviour GenServer` whose `HandleCall` or `HandleCast` request
  argument is narrower than `term` gets a final clause per callback, `handle_call(Msg, _From, S) ->
  logger:warning(...), {noreply, S}` and `handle_cast(Msg, S) -> logger:warning(...), {noreply, S}`,
  the warning naming the module and the message, as `gleam_otp`'s *"Actor discarding unexpected
  message"* does. A callback whose argument is already `term` gets none, because its own clauses
  must already cover `term`.
- **Tests at the boundary**, reusing this ticket's probe: the shipped Counter answers
  `gen_server:call(P, get)` with `5`; `gen_server:call(P, bogus, 1000)` exits the *caller* with
  `timeout`; the server is still alive and `get` still answers `5`; a warning naming `bogus` is
  logged. Adding `:reset` to `Request` without a clause is still refused naming
  `HandleCall(:reset, x, n)`.
- **Ticket 14 §4** carries a dated amendment pointing here. LANGUAGE.md §13's Counter text stays
  true and gains a sentence on what a stray call does.

## Not decided here

- User-declared behaviours (ticket 91, ENG-460): whether their callbacks may narrow the same way.
  ENG-460 reuses ENG-437's containment check, and this ticket only rules on OTP's `GenServer`.
- `gen_statem` and other OTP behaviours, which are not yet compiler-known.

## Decisions entry

<!-- This ticket's entry. Read whole, here; the map (ENG-165) carries one line. -->

```decisions-entry
- [May `HandleCall` and `HandleCast` narrow their request argument?](issues/107-narrowed-call-and-cast.md)
  — **yes, and a stray call or cast is discarded with a logged warning, as Gleam's actor does, so
  the server lives; `HandleInfo` keeps `term`.** Raised and resolved 2026-09-25 in one round, out
  of [ENG-437](https://linear.app/davewil/issue/ENG-437), settling ticket
  [14](issues/14-concurrency-and-otp-model.md)'s §1 (*"the `Request` union `HandleCall` proves
  exhaustive over"*) against its §4 (*"the argument position must be `term`"*) in §1's favour for
  call and cast. Measured first: one `gen_server:call(P, bogus)` killed the shipped Counter;
  Elixir 1.20 behaves the same and checks nothing; Gleam 1.18's `gleam_otp` actor proves the
  handler exhaustive **and** survives, because its library filters strays before the typed
  handler (`select_other(Unexpected)`, logged and discarded). B# does the same in emitted code:
  one closing clause after the author's, logging and returning `{noreply, State}`, never credited
  to exhaustiveness, so a stray call's caller times out. ENG-437's contract check keeps returns
  covariant and every other argument contravariant. Probes 107a and 107b kept. Ticket 14 §4
  amended in place. Unbuilt — ENG-437.
```
