# 98 — `Task` and `Agent`: does ticket 14 §2's "no `Task`" reach Elixir's?

Type: grilling
Status: open — [ENG-450](https://linear.app/davewil/issue/ENG-450). Raised 2026-09-25 by David
Blocked by: —

## Why this is raised

David, 2026-09-25: *"GenServer, Task, Agent etc and other OTP stuff should be in there."*
`GenServer`'s client calls ride on ticket 96. `Task` and `Agent` do not, because a decision stands in
the way. LANGUAGE.md §13: *"**No `async`, `await` or `Task`.** `async` colours functions, which is
a second effect system."* That line is ticket 14 §2, and the `Task` it declines is **C#'s**: *"a
future over a thread pool with implicit continuation capture"*, with `async` colouring every
function up the call graph.

Elixir's `Task` is neither. `Task.async(fn)` is `spawn_link` plus `monitor`, and `Task.await(t)` is
a blocking `receive` on the reply or the `DOWN`. Nothing is coloured, and blocking a process is the
idiom 14 §2 itself defends. 25g wrote exactly that by hand, because the `Task` name was taken:

```csharp
// 25g jev_ask.bs, measured compiling and running on a0f9cbf
using :erlang { (pid, reference) spawn_monitor(fn() -> term f) }

Ask(send, token, spec, owner, tag, state, qs) ->
    var (_, ref) = :erlang.spawn_monitor(() =>
        :erlang.send(owner, (:jev, tag, Evaluate(send, token, spec, state, qs))))
    ref
```

## Round 1

**Q1. Does 14 §2 decline Elixir's `Task` too, or only C#'s future and `async` colouring?**

```csharp
public list<Evaluation> AskAll(list<Question> qs)
AskAll(qs) -> qs |> List.Map(q => Task.Async(() => Evaluate(q)))
                 |> List.Map(t => Task.Await(t, 5000))
```

Under "only C#'s", this compiles. `Task.Async(fn() -> T) -> task` spawns and monitors, and
`Task.Await(task, int) -> term` receives the reply, which crosses a process boundary as `term`
(18 §2), so `AskAll`'s `list<Evaluation>` is `ValidateAs` at the await. Under "Elixir's too",
LANGUAGE.md §13's line gains the reason and 25g's `spawn_monitor` stays the idiom.

Compiler delta, under "only C#'s": `Task` is a reserved qualifier (ticket 65). `Async` lowers to
`spawn_monitor` over the lambda (F46 already carries a fun across). `Await` needs a `receive` with a
timeout, and **`receive` has no production in the grammar today** (LANGUAGE.md §13 decides it as a
filter; `bs_parser.yrl` has no rule for it). So either `receive` is built first, or `Await` is a
generated function the compiler writes in Erlang abstract format.

**Not asked here: `Agent`.** `Agent.update(agent, fn)` sends a closure through a mailbox, which is
the case ticket 14 §3 ruled inadmissible (*"a message carrying a closure through the mailbox is
exactly that rejected case"*). It is a separate question, and it follows Q1.

**Round 1 answered 2026-09-25 (David): Q1 "only C#'s".** Ticket 14 §2 declines C#'s `Task`, a
thread-pool future whose `async` colours the call graph, and nothing else. LANGUAGE.md §13 keeps
*"no `async`, no `await`"* with that reason stated, and Elixir's `Task`, spawn plus monitor plus a
blocking receive, joins the standard environment under ticket 96's table. It is not OTP's (Elixir
ships `Task`), so `Async` lowers to `erlang:spawn_monitor` over the lambda and `Await` is a function
the compiler writes. No beam ships.

## Round 2

**Q2. Is `Agent` in, typed by its state, with its loop generated so no beam ships?**

```csharp
public Agent<map<string, int>> Counts()
Counts() -> Agent.Start(() => { })

Bump(a, k) -> Agent.Update(a, m => Map.Update(m, k, 1, n => n + 1))
Read(a, k) -> Agent.Get(a, m => Map.Find(m, k))
```

Ticket 14 §3 ruled a closure through a mailbox inadmissible, because a *foreign* fun is holdable and
never callable: *"unknown code with unknown types has run"*. Here the fun is B#'s own, typed
`fn(S) -> S` at the call, and the loop that calls it is one the compiler generates, not foreign code.
Under yes, `Agent<S>` is a type, the state `S` is fixed at `Start`, and `Get`, `Update` and
`GetAndUpdate` take funs over `S`. Under no, the idiom is a `GenServer` with typed client functions
(14 §1), which is longer and is what `Agent` exists to shorten.

**Q3. Is `Task.Await` ticket 96 Q3's pair: the plain form crashes on a timeout or a crashed task,
and the other returns the reason?**

```csharp
Answer(t)    -> Task.Await(t, 5000)          // a timeout or a crash exits the caller, as Elixir's
Answer2(t)   -> Task.TryAwait(t, 5000)       // (:error, :timeout) | (:error, (:down, reason))
```

Under yes, the plain form is Elixir's `Task.await`, and the other is `Task.yield` given a reason. A
task is linked to its caller, as Elixir's `Task.async` is, so a crash propagates unless the caller
traps exits. Under no, `Await` is the only form, and a caller who wants to survive a timeout writes
the receive itself.

**Q4. Does `Task.Async` return a `Task<T>` typed by the lambda, so `Await` returns `T` and not `term`?**

```csharp
public int Longest(list<string> ws)
Longest(ws) -> Task.Await(Task.Async(() => List.Max(Enum.Map(ws, w => String.Length(w)))), 1000)
```

Round 1 said `Await` returns `term`, since a reply crossing a process is `term` under ticket 18 §2.
That rule is about a sender the compiler cannot see. Here both ends are this module's code: the
lambda is typed `fn() -> int`, and the reply is correlated by the monitor reference, which no other
process holds. Under yes, `Task<T>` is a type, `Await` returns `T`, and `Longest` compiles. Under no,
`Await` returns `term`, and every use is `ValidateAs<int>`.
