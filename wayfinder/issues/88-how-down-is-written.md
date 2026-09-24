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

