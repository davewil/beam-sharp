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
