# 88 — How is `Down` written in a clause head, and what are its parts called?

Type: grilling
Status: claimed 2026-09-24 — [ENG-413](https://linear.app/davewil/issue/ENG-413). Raised by exemplar
[25g](../prototypes/25g-jev-server.md), whose only wall this is
Blocked by: —

## Why this is raised

[Ticket 14](14-concurrency-and-otp-model.md) §6 decided that OTP's system-message shapes, `Down`,
`Exit` and `Timeout`, are compiler-known types, so that a handler *names* the message rather than
spelling the tuple, and a mis-shaped clause ([`14g`](../prototypes/14g_handle_info_blind_spot.erl):
four elements where the BEAM sends five) becomes a compile error. It also made calling `Monitor`
with no `Down` handler in the unit an error. It never said how `Down` is written or what its parts
are called, and nothing builds it. Exemplar 25g stops on `no type named Down`, and guessed
`Down { Ref: ref, Reason: reason }`.

## What the platform sends

Measured from OTP 28.5's own documentation of `erlang:monitor/2`:

```
{'DOWN', MonitorRef, Type, Object, Info}
```

- `Type` is `process` or `port`.
- `Object` is the monitored pid or port, or `{RegisteredName, Node}` when it was monitored by name.
- `Info` is the exit reason: `normal`, `noproc`, `noconnection`, or whatever the process exited with.

A B# record erases to a map carrying `Kind` (26 §1), so a record pattern can never match this
tuple. Whatever `Down` is, it is not an ordinary record.

Neighbours: Gleam (`gleam_erlang`, `process.gleam`) has
`ProcessDown(monitor: Monitor, pid: Pid, reason: ExitReason)` and
`PortDown(monitor: Monitor, port: Port, reason: ExitReason)`. Elixir matches the tuple:
`{:DOWN, ref, :process, pid, reason}`. C# has no equivalent.

## Round 1 — 2026-09-24: does `Down` have named parts?

Asked alone, because the field names, what `Object` is typed as, whether `Type` is a field at all,
and how `Exit` and `Timeout` follow all depend on it. The program is 25g's `HandleInfo`: a request
process was monitored, and its death has to answer the caller.

**If `Down` has named parts:**

```csharp
public (:noreply, State) HandleInfo(Message m, State s)

HandleInfo((:jev, from, answer), s) ->
    var _ = :gen_server.reply(from, HandleAnswer(answer))
    (:noreply, s)
HandleInfo(Down { Ref: ref, Reason: :normal }, s) ->
    (:noreply, s with { Pending = :maps.remove(ref, s.Pending) })
HandleInfo(Down { Ref: ref, Reason: reason }, s) ->
    Crashed(ref, reason, s)
```

`Down { … }` is a pattern over the BEAM's 5-tuple, and `d.Reason` on a bound `Down d` reads the
fifth element. A clause names the parts it needs, in any order, and cannot get the arity wrong.
Compiler delta: a new compiler-known kind, a *named view of a tuple*. A stratum-2 entry maps each
name to a tuple position under the `'DOWN'` tag. The record-pattern walk lowers `Down { Ref: r }`
to `{'DOWN', R, _, _, _}`, projection lowers to `element/2`, and the printer and residuals write
`Down { … }` back. Users cannot construct one (ticket 15: stratum 2 is what a user cannot mint).

**If `Down` is the tuple behind a name:**

```csharp
HandleInfo((:'DOWN', ref, :process, _, :normal), s) ->
    (:noreply, s with { Pending = :maps.remove(ref, s.Pending) })
HandleInfo((:'DOWN', ref, :process, _, reason), s) ->
    Crashed(ref, reason, s)
```

`Down` is a declared alias for `(:'DOWN', ref, :process | :port, pid | port | (atom, atom), term)`,
which today's surface already compiles. A 4-element clause is refused wherever the argument is typed
as `Down` or a union holding it (a `vacuous_arm` or unreachable clause), so 14g's hole closes where
`HandleInfo` is narrowed, but not where it takes `term`. Compiler delta: `pid`, `port` and
`reference` as builtin types (25g friction 4); `Down` as a stratum-1 alias; nothing else.

**Q1. Does `Down` have named parts, a pattern `Down { Ref: r, Reason: why }` over the BEAM tuple, or
is it the tuple itself behind a name?**

Recommended: **named parts.** Ticket 14 §6's stated reason for the type is that a handler names the
message instead of spelling the tuple, and the positional form still spells it: five positions,
one of them an atom the reader has to know (`:process`), with the arity mistake 14g found one
missing `_` away. The cost is one new kind in the compiler, a named view of a tuple. It is also what
`Exit` (`{'EXIT', Pid, Reason}`) and `Timeout` would reuse.

**Answered 2026-09-24 (David): named parts.** `Down { Ref: r, Reason: why }` is a pattern over the
BEAM's 5-tuple, a compiler-known named view of a tuple; `d.Reason` reads its element; users cannot
construct one (ticket 15's stratum 2).

## Round 2 — 2026-09-24: one type or two, and what the parts are typed as

**Q2. Is a port's death the same `Down` as a process's, or its own type?**

The BEAM sends one shape for both, `{'DOWN', Ref, process | port, Object, Info}`, with `Object` a
pid, a port, or `{RegisteredName, Node}`. Gleam splits them: `ProcessDown(monitor, pid, reason)`
and `PortDown(monitor, port, reason)`.

One type, one name per tuple position (names are Q4's, not this round's):

```csharp
HandleInfo(Down { Ref: ref, Object: pid, Reason: reason }, s) -> Restart(pid, reason, s)
```

`Object` is `pid | port | (atom, atom)`, and a program that monitors only processes narrows it with
a pattern, `Down { Type: :process, Object: pid }`, when it needs the pid. Compiler delta: one view,
each name mapped to one position.

Two types:

```csharp
HandleInfo(ProcessDown { Ref: ref, Pid: pid, Reason: reason }, s) -> Restart(pid, reason, s)
```

`ProcessDown` fixes the third element to `process` and `PortDown` to `port`; each names its object
for what it is. Compiler delta: a view may fix a position to a literal, and two views share the
`'DOWN'` tag, told apart by that literal, which the algebra already subtracts exactly.

Recommended: **one `Down`.** Ports are rare in application code (a port monitor exists only since
OTP 19), the one-name-per-position view is the simplest thing to build and to explain, and a
process-only handler pays one pattern, `Type: :process`, only where it reads the object. A split
doubles the names for a distinction most handlers never draw.

**Q3. Are `pid` and `reference` builtin types?**

The parts need types. LANGUAGE.md §13 and ticket 14 §1 already say *"a process identifier is a
`pid`"*, and `bsc` answers `pid is not a builtin type` (25g friction 4), so every process in 25g is
`term`.

```csharp
public (:noreply, State) HandleInfo(Message m, State s)
HandleInfo(Down { Ref: ref, Reason: reason }, s) -> Crashed(ref, reason, s)

private (:noreply, State) Crashed(reference ref, term reason, State s)
```

Compiler delta: `pid`, `reference` (and `port`, for `Object`) as builtin names in `bs_check`, each a
new part of the type algebra decided by one guard (`is_pid/1`, `is_reference/1`, `is_port/1`), with
`-spec`s `pid()`, `reference()`, `port()`. Ticket 14 §1 keeps `pid` **untyped** (no `Pid<T>`), and
this does not change that.

Recommended: **yes, all three.** The shipping document already promises `pid`, a `Down` whose parts
are all `term` names nothing a reader can use, and each is one guard, the O(1) test ticket 11 asks
of a type at the boundary.

**Answered 2026-09-24 (David): Q2 one `Down`, Q3 yes.** One view names each of the tuple's four
positions, for process and port monitors alike. `pid`, `reference` and `port` become builtin types,
each decided by one guard (`is_pid/1`, `is_reference/1`, `is_port/1`); `pid` stays untyped (14 §1).

## Round 3 — 2026-09-24: the names, the siblings, and the pairing check

**Q4. What are the four parts called?**

Positions 2 to 5 of `{'DOWN', MonitorRef, Type, Object, Info}`, in the names Erlang's own
documentation gives them except the last:

```csharp
Down { Ref: reference, Type: :process | :port, Object: pid | port | (atom, atom), Reason: term }

HandleInfo(Down { Ref: ref, Reason: :normal }, s) -> Forget(ref, s)
HandleInfo(Down { Ref: ref, Type: :process, Object: pid, Reason: reason }, s) -> Restart(pid, reason, s)
```

`Ref`, not `MonitorRef`: the only reference a `Down` carries. `Type` and `Object` as Erlang writes
them; `Kind` is not available, since it is the one field name a record's tag owns (26 §1). `Reason`,
not `Info`: `Info` is always the exit reason, `'EXIT'` messages and `exit/2` call it `Reason`, and
Gleam does too.

Recommended: **`Ref`, `Type`, `Object`, `Reason`.**

**Q5. Does this ticket also settle `Exit` and `Timeout`?**

Ticket 14 §6 named three. They are not the same kind of thing:

```csharp
// `{'EXIT', Pid, Reason}`, delivered to a process that traps exits: a two-part view, like Down.
HandleInfo(Exit { Pid: pid, Reason: reason }, s) -> Restart(pid, reason, s)

// a gen_server timeout is the bare atom `timeout`: no parts, nothing to name.
HandleInfo(:timeout, s) -> Idle(s)
```

Recommended: **yes for `Exit`, as `Exit { Pid, Reason }`, built with `Down` since it is the same
mechanism; and `Timeout` is the atom `:timeout`, which needs no type and is dropped from the
compiler-known list.** Ticket 14 §6's *"and friends"* is not extended here (`nodedown`, `'ETS-TRANSFER'`
and the rest wait for a program that needs them).

**Q6. Where must the `Down` handler be for a monitoring call?**

Ticket 14 §6: *"calling `Monitor` in an aggregate that handles no `Down` is an error"*, the aggregate
being the module. 25g breaks that rule as written, and correctly:

```csharp
module Jev                                   // the library: monitors, handles nothing

public term Ask(Send send, string token, string spec, term owner, term tag, Json state, list<(string, Question)> qs)
Ask(send, token, spec, owner, tag, state, qs) ->
    var (_, ref) = :erlang.spawn_monitor(() => :erlang.send(owner, (:jev, tag, Evaluate(send, token, spec, state, qs))))
    ref
```

```csharp
module Triage                                // the caller: handles the Down
HandleInfo(Down { Ref: ref, Reason: reason }, s) -> Crashed(ref, reason, s)
```

`spawn_monitor` runs in `Jev`, but the monitor belongs to the calling process, `Triage`'s server,
which is where the `Down` arrives. The check as decided refuses `Jev`, a library that is right.
Keeping it and making it right would mean marking `Ask` as a monitoring function and carrying the
mark to every caller until one handles `Down`, which is the propagating constraint 14 §6 said this
was not. Without it, a missing handler goes unnoticed, and a mis-shaped one is still refused,
because `Down` is a type.

Is the pairing check dropped?

Recommended: **yes, dropped, recorded as deferred with what carrying the mark to callers would need.** The hole 14g found was a
mis-shaped clause, and naming `Down` closes it on its own. The pairing check refuses correct library
code, and making it correct turns it into the effect that 14 §6 argued it was not.

**Answered 2026-09-24 (David): Q4 yes, Q5 yes, Q6 drop it.**

- **Q4.** `Down { Ref: reference, Type: :process | :port, Object: pid | port | (atom, atom),
  Reason: term }`.
- **Q5.** `Exit { Pid: pid, Reason: term }` is built with `Down`, the same mechanism over
  `{'EXIT', Pid, Reason}`. `Timeout` is the atom `:timeout` and leaves the compiler-known list.
  Ticket 14 §6's *"and friends"* are not extended here.
- **Q6.** The pairing check (*"calling `Monitor` in an aggregate that handles no `Down` is an
  error"*) is **dropped**. A mis-shaped handler is still refused, since `Down` is a type; a missing
  one goes unnoticed. **What the deferred check would need**: a mark on every function whose body
  monitors and returns the reference, carried to its callers until a module handles `Down`, which
  is a constraint propagating across calls, the thing 14 §6 said this check was not; and a rule for
  a module that hands the reference on rather than handling it. The trigger to reopen: a program
  that loses a `Down` because no handler was written.

**What follows from Q1 without a question.** A bound `Down d` reads `d.Reason` with `element/2`; a
residual prints `Down { … }`; the emitted `-spec` is `{'DOWN', reference(), process | port,
pid() | port() | {atom(), atom()}, term()}`; `ToJson` refuses a `Down`, since it is a tuple (77);
`ValidateAs<Down>` checks the tuple. The view is not a user-declarable construct: it exists for the
compiler-known messages only.

The design tree has no open branch. The decisions entry is written once David confirms the whole.

