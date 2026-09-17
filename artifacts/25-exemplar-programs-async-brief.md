# Brief: ticket 25 — the sixth exemplar, async processing

Research brief, not a decision. Does not resolve
[ticket 25](../wayfinder/issues/25-exemplar-programs.md) / [ENG-191](https://linear.app/davewil/issue/ENG-191):
its `Status:` line is untouched, it gains no `## Decisions entry`, and the exemplar itself is not
written here — this is the standing resource's own next step, deciding what to write before
writing it. `git status` in `/home/user/beam-sharp` is clean at the end of this session, HEAD
`7065fa0d97822a5f3126d88ecab087fd0427cbc1`; nothing under `compiler/` or `wayfinder/` was edited.

## Sub-decisions extracted

1. **What concurrency primitive/shape.** Ticket 14 already closed off `async`/`await` and `Task`
   (§2) — the vocabulary is `spawn` plus OTP, nothing else. What is still open is which OTP shape:
   bare `spawn`/`monitor`, a decoupled task-supervisor pool, or a `[module: GenServer]` behaviour.
2. **What realistic workload.** The candidate table's own words: "whether spawn/Task survives;
   supervision of work." Needs a workload where the units of work are genuinely independent of
   each other (unlike 25c's ordered frame pipeline) and where the process is transient (unlike
   25a's router, 25b's socket, 25c's consumer, 25d's connection — all long-lived).
3. **Whether it needs a supervisor, and how that differs from a sixth `gen_server`.** The ticket's
   own worry, stated at line ~648: this must not become another long-lived, callback-shaped
   process. A supervisor and a `gen_server` are not the same thing (a `supervisor` behaviour has no
   `handle_call`/`handle_cast`/`handle_info` of its own), so "does it need a supervisor" and "is it
   a sixth gen_server" are two different questions that the ticket's own prose runs together —
   separated below, with a measured answer to the first.

## Methodology

Every claim below with a `$`, a `bsc`/`erl`/`elixir` transcript, or a `file:line` citation was
executed or read in this session against the toolchain
`RESEARCH_ENVIRONMENT.md` names: OTP 28.5 (erts-16.4), Elixir 1.19.5, Gleam 1.18.1, `bsc` built at
`compiler/_build/default/bin/bsc`, with

```
export PATH=/opt/otp-28.5/bin:/opt/elixir-1.19.5-otp28/bin:/usr/local/bin:$PATH
export LANG=C.UTF-8
```

first in every shell. All twelve probe scripts live under this session's scratchpad at
`async-probes/` (six `.bs` fragments under `async-probes/bsc-probes/`, two `.erl` drivers, three
`.exs` scripts) and are driven by one script,
`async-probes/run_all_probes.sh`, which reproduces every transcript quoted below from a clean
state in one pass — used for its own sake and reused as the verifier's harness (§ Verification).

**A real limitation, stated rather than argued around**: Gleam's concurrency library is not
reachable in this environment. `gleam_stdlib` is vendored at `/tmp/gleam-stdlib-src` (per the
briefing) but `gleam_otp` and `gleam_erlang` — where Gleam's actor/process API actually lives —
are not, confirmed by `find / -iname "*gleam_otp*" -o -iname "*gleam_erlang*"` returning nothing
outside `/tmp/gleam-src/hexpm/test/` (a stdlib-only test fixture, not the package). Pointing
`gleam.toml` at nonexistent local paths and running `gleam build` hangs rather than erroring —
consistent with the briefing's documented `repo.hex.pm` block, not further poked at once
confirmed, per the instruction not to retry or route around it. So no *fresh* Gleam concurrency
probe was run this session. What is used instead is [ticket 14](../wayfinder/issues/14-concurrency-and-otp-model.md)
§7's own real, dated (`local` provenance, 2026-08-12) measurements — `wayfinder/prototypes/14a`–`14g`,
already in the repo — cited as prior evidence, not re-verified live here. That is a real gap in
this brief's coverage and it is about the *receive-filter* question ticket 14 already closed, not
about the fan-out/collect question this ticket asks; gleam_stdlib alone (confirmed below) has no
concurrency surface to probe for that question regardless.

**No subagent-spawning tool was available in this tool environment** — `ToolSearch` for
`Agent`/`Task`/`SpawnAgent`/`TaskCreate` returned nothing matching, and the tool list carries no
`Agent` tool. § Verification is therefore a second, independent pass done in *this* session rather
than by a separate agent process: every probe re-run from a clean checkout of the same scripts into
a new directory, diffed byte-for-byte against the claimed transcripts, and checked explicitly for
the circularity failure mode the task named.

## Probes, with real captured output

### Probe 1 — is `pid` a usable type in beam-sharp today?

`async-probes/bsc-probes/01-pid-not-builtin/Async/Probe/probe.bs`:

```csharp
module Async.Probe

using :erlang {
    pid spawn(fn() -> term)
}

public pid Go()
Go() -> :erlang.spawn(() => 1 + 1)
```

```
$ bsc --src-root . Async/Probe/probe.bs
Async/Probe/probe.bs: error: pid is not a builtin type
  this slice has `int`, `float`, `atom`, `term`, `none`, `bool`, `binary`,
  `string` and `list<T>`.
```

Confirmed by reading `compiler/src/bs_check.erl:2072-2086` (`builtin/1`): the table has exactly
`int`, `float`, `atom`, `term`, `none`, `bool`, `binary`, `string` — no `pid`, no `reference`. This
is not a contested claim about a future feature; ticket 14 §1 already decided *"process identity
stays a bare `pid`"* and the compiler has no `pid` at all. `grep -rn "\bpid\b" compiler/src/*.erl`
outside diagnostics/comments returns nothing.

### Probe 2 — the workaround: type the handle `term`

`async-probes/bsc-probes/02-term-pid-works/Async/Probe/probe.bs`, `pid` replaced by `term`
throughout:

```
$ bsc --src-root . Async/Probe/probe.bs
(exit 0 — compiles clean)
```

So every probe below that needs a process handle types it `term`, exactly as 25d already had to
type a `gen_server` reply `term` (its finding 0) and 25a/b/c typed OTP state `term` throughout.

### Probe 3 — is `receive` implemented?

`grep -n "receive" compiler/src/bs_lexer.xrl compiler/src/bs_parser.yrl` returns **nothing** —
ticket 14 §5 decided `receive` is *"syntax, not a library function"* and a *filter*, but no grammar
production for it exists. `async-probes/bsc-probes/03-receive-unbound/Shop/Notify/bare.bs`:

```csharp
module Shop.Notify

public int Bare()
Bare() -> receive
```

```
$ bsc --src-root . Shop/Notify/bare.bs
Shop/Notify/bare.bs:4:1: error: Bare uses receive, which nothing binds
  a name comes from a clause head or a binding above it.
```

Precise and unambiguous: `receive` lexes as an ordinary lowercase identifier (a variable
reference), and the checker's `unbound_variable` diagnostic fires on it exactly as it would on any
misspelled name. A second, earlier probe (`Collect(n) -> receive { (Down, pid, reason) -> n }`,
not saved as a numbered probe but reproducible the same way) gets past the bare name and fails
inside the braces instead (`syntax error before: '('`), because `receive { ... }` has no
production either. Both confirmations agree: **`receive` does not exist in the compiler as it
stands, at all** — not partially, not for a restricted case. This is decided (ticket 14 §5) and
unbuilt (no F-ticket found; `grep -rn -i "receive" compiler/features/*.md` matches nothing that
builds it).

### Probe 4 — the map-literal wall, re-confirmed for this exemplar's own likely need

A fan-out collector's natural accumulator ("which of these N pids am I still waiting on") is a map.
`async-probes/bsc-probes/04-map-literal-illegal/Shop/Notify/empty.bs`:

```
$ bsc --src-root . Shop/Notify/empty.bs
Shop/Notify/empty.bs:4:12: error: illegal characters "#"
```

`#` is not a legal character to the lexer at all (`compiler/examples/exemplars/FRONTIER` already
records this as 25a's own front wall on `create_order.bs`). Not a new finding, but confirms the
accumulator this exemplar would reach for first — same wall.

### Probe 5 — does the "sixth gen_server" shape at least compile?

Five files under `async-probes/bsc-probes/05-gen_server-batch-coordinator/Shop/Batch/`: a
`[module: GenServer]` aggregate whose `Init` spawns one worker per input (state a
`list<(term, string)>`, not a map — dodging probe 4's wall the way 25d's `opts.bs` dodged it with a
proplist) and whose `HandleInfo` removes a pid from the pending list when it hears from it.

```
$ bsc --src-root . Shop/Batch/index.bs        # exit 0
$ bsc --src-root . Shop/Batch/init.bs         # exit 0
$ bsc --src-root . Shop/Batch/handle_call.bs  # exit 0
$ bsc --src-root . Shop/Batch/handle_cast.bs  # exit 0
$ bsc --src-root . Shop/Batch/handle_info.bs  # exit 0
$ bsc --src-root . -o out Shop/Batch/handle_info.bs   # exit 0, produces Shop.Batch.beam
```

**This is the sharpest and least expected finding in this brief.** The one OTP shape ticket 25's
own prose says this exemplar should *not* be — a `gen_server`-shaped, long-lived, callback-based
coordinator — is the *only* concurrency shape that compiles clean through `bsc` today. Confirmed
running: `gen_server:start_link` against the compiled beam, followed by `gen_server:call(batch,
:status)`, returns the real pending list of spawned pids. The compiler has real, working support
for OTP behaviour contracts (`compiler/src/bs_otp.erl`) and none at all for bare-process primitives
beyond `spawn` itself (probe 2) — `pid`, `receive`, and the `Down`/`Exit`/`Timeout` compiler-known
stratum ticket 14 §6 promises are all absent (`grep -rn "'Down'" compiler/src/*.erl` — nothing).
So today's compiler has a structural pull *toward* writing this exemplar as a sixth `gen_server`,
independent of whether that is the right design — it is currently the path of least resistance,
which is exactly the trap worth naming before anyone starts.

### Probe 6 — is the atomic primitive (`spawn_monitor`) expressible?

`async-probes/bsc-probes/06-spawn_monitor-works/Shop/Notify/`:

```csharp
using :erlang {
    (term, term) spawn_monitor(fn() -> term)
}
...
public (term, term) Go()
Go() -> :erlang.spawn_monitor(() => 1 + 1)
```

```
$ bsc --src-root . -o out Shop/Notify/go.bs   # exit 0
$ bsc --src-root . Shop/Notify/go.bs Go
(<0.90.0>, #Ref<0.3226258093.1916272643.210254>)
```

A real pid/ref pair, compiled and run through `bsc`'s own CLI runner. So the *atomic* spawn+monitor
primitive — one BIF, no race window — is already reachable through `using`, typed `term`, using
only what F46 (lambdas) and the foreign-declaration mechanism already ship. This matters directly
for probe 8 below.

### Probe 7 — bare `spawn_monitor` fan-out/collect, in Erlang (what a beam-sharp lowering would compile to, if `receive` existed)

`async-probes/erlang_fanout_probe.erl`: 5 inputs, one (`N =:= 3`) deliberately raises inside a
`try`/`catch` in the worker, so the failure becomes a value rather than a crash — the pattern
ticket 12/15 calls "the honest value your signature admits."

```
$ erlc erlang_fanout_probe.erl && erl -noshell -eval 'erlang_fanout_probe:main().'
results (sorted by input) -> [{1,{ok,1}},
                              {2,{ok,4}},
                              {3,{error,{error,{boom,3}}}},
                              {4,{ok,16}},
                              {5,{ok,25}}]
collect wall time -> 20 us
caller alive after batch -> true
```

Fault-isolated per unit, caller unaffected, ~20-30µs to collect 5 (re-measured across five runs,
20-30µs, dominated by scheduling noise at this N).

### Probe 8 — the same workload, routed through a `simple_one_for_one` supervisor instead of bare `spawn_monitor` — and a genuine race found, not assumed

`async-probes/erlang_pool_probe.erl`: same 5 inputs, but worker 3's `error({boom, 3})` is **not**
caught — it crashes the process for real, under a `supervisor:start_child` with `restart =>
temporary` (no automatic restart of a fire-once unit), and the caller separately calls `monitor/2`
on the pid `start_child` hands back.

```
$ erlc erlang_pool_probe.erl && erl -noshell -eval 'erlang_pool_probe:main().'
=SUPERVISOR REPORT====
    reason: {{boom,3}, [...]}
    offender: [{pid,<0.86.0>}, {id,worker}, {restart_type,temporary}, ...]
results (sorted by input) -> [{1,{ok,1}},
                              {2,{ok,4}},
                              {3,{down,noproc}},
                              {4,{ok,16}},
                              {5,{ok,25}}]
caller alive after batch -> true
supervisor alive after a child crash -> true
```

**`{3, {down, noproc}}`, not `{3, {down, {boom,3}}}` — reproduced 5/5 runs, not a rare
interleaving.** `supervisor:start_child/2` returns a bare pid; it is not an atomic spawn+monitor,
so the caller's own `monitor(process, Pid)` call happens *after* the child already exists — and
worker 3 crashes fast enough, every single time measured, that the monitor is established against
a pid that is already dead. `monitor/2` on a dead pid still delivers a `'DOWN'`, but with reason
`noproc`, because the real exit reason was never observable from outside — it was gone before
anything started watching. **The real crash reason survives in the supervisor's own log and is
lost to the code that asked for the result.** This is exactly the failure mode probe 6's atomic
`spawn_monitor` avoids by construction (spawn and monitor as one BIF, no gap for the child to die
in). Not a defect in this probe's code — it is what routing a one-shot unit of work through
`supervisor:start_child` costs when the caller still wants the crash reason, and it is a genuine,
reproducible hazard rather than a hypothetical one.

### Probe 9 — measured cost, bare vs. supervised

```
                              erlang_fanout_probe.erl   erlang_pool_probe.erl   delta
source lines                 53                         76                     +43%
BEAM instructions (all fns)  219                        278                    +27%
```

(Raw `.beam` byte size is *not* reported as a stable figure here — see § Verification, probe 9's
note — it embeds the absolute source path length and moved 144 bytes on a location-only rerun
while the instruction count did not move at all. Instruction count is the reproducible one.)

**No beam-sharp async lowering exists to measure a third figure against** — there is no `spawn`,
`monitor` or `receive` syntax in the language today (probes 1, 3), so ticket 39's cost machinery,
built for comparing candidate *language* lowerings, has nothing to compare here. What probes 7-9
measure is the two real OTP-level shapes any beam-sharp lowering would eventually compile *to*,
which is the same thing every other exemplar's lowering measured directly (25b/c's `error_info`
captures, 25d's `ValidateAs` timing) before any beam-sharp syntax existed for the surface form.

### Probe 10 — Elixir, `Task.async_stream` (linked, the default), one unit raises

`async-probes/elixir_task_probe_1_linked.exs`, wrapped in `try`/`rescue`:

```
$ elixir elixir_task_probe_1_linked.exs
--- Task.async_stream (linked, default), 5 independent units, one raises ---

23:32:20.407 [error] Task #PID<0.105.0> started from #PID<0.95.0> terminating
** (RuntimeError) boom at 3
    ...
** (EXIT from #PID<0.95.0>) an exception was raised:
    ** (RuntimeError) boom at 3
```

**Neither `"async_stream result"` nor `"CALLER CRASHED"` is ever printed.** The `try`/`rescue`
around the whole pipeline catches nothing, because a linked task's crash reaches the caller as an
**exit signal**, not a raised exception — `rescue` cannot catch a signal, only a raise. The whole
script's own process dies. This is Elixir's real default: `Task.async_stream/3,4` links, so one
unit failing takes the entire batch and its caller down, all-or-nothing.

### Probe 11 — Elixir, `Task.Supervisor` + `async_nolink` + `yield_many`, one unit raises

`async-probes/elixir_task_probe_2_supervised.exs`:

```
$ elixir elixir_task_probe_2_supervised.exs
--- Task.Supervisor + async_nolink + yield_many, one raises, batch survives ---
23:32:20.879 [error] Task ... terminating ** (RuntimeError) boom at 3 ...
per-task outcome (ok/exit, independent): [
  ok: 1,
  ok: 4,
  exit: {%RuntimeError{message: "boom at 3"}, [...]},
  ok: 16,
  ok: 25
]
```

Fault-isolated: the batch survives, each unit's outcome is independently observable, and the
process that logged the crash was the doomed task itself, not the caller. This is the real
`Task.Supervisor`-based idiom real Elixir code reaches for when it wants exactly probe 7's
guarantee at the library level rather than hand-rolled.

### Probe 12 — Gleam's concurrency surface, as far as it is reachable here

```
$ find / -iname "*gleam_otp*" -o -iname "*gleam_erlang*"
(nothing outside /tmp/gleam-src/hexpm/test/, a stdlib-only test fixture)
$ ls /tmp/gleam-stdlib-src/src/gleam/
bit_array.gleam bool.gleam bytes_tree.gleam dict.gleam dynamic(.gleam)
float.gleam function.gleam int.gleam io.gleam list.gleam option.gleam
order.gleam pair.gleam result.gleam set.gleam string.gleam string_tree.gleam uri.gleam
$ grep -rl "spawn\|process\|actor\|otp" /tmp/gleam-stdlib-src/src/gleam/*.gleam
/tmp/gleam-stdlib-src/src/gleam/float.gleam   # unrelated (float parsing helper named differently)
/tmp/gleam-stdlib-src/src/gleam/list.gleam    # unrelated (list helper)
```

**`gleam_stdlib` — the one Gleam package this environment can actually compile against — has no
process, actor or spawn surface at all**, confirmed by direct inspection of every file it ships,
not by absence of a grep hit alone. This is expected and correctly designed on Gleam's part:
`gleam_stdlib` targets both Erlang and JavaScript, and concurrency is Erlang-only, so it lives in
the separate `gleam_erlang` (raw process primitives) and `gleam_otp` (actor/supervision) packages
— neither reachable here (see Methodology). What ticket 14 §7 already measured about those two
packages (real, dated, `local`-provenance, not re-run this session) is quoted in the survey below.

## Neighbour-language survey

**Erlang.** No library idiom above the two BIFs — `spawn/1,3,4`, `spawn_monitor/1,3` (the atomic
pair probe 6 exercises) and `monitor/2`, plus `receive`. There is no `Task`-equivalent in the
standard library; OTP's own answer at this level *is* `gen_server`/`supervisor`, which is why
Elixir had to build `Task` on top rather than finding it already in `:erlang` or `:otp`. Probes
7-9 are exactly this bare shape, hand-written, because there is nothing else to call.

**Elixir — `Task`, cited exactly.** `/tmp/elixir-src/lib/elixir/lib/task.ex`:
- `async/1` (line 498) is `spawn_link` via `Task.Supervised.start_link/2`, monitored
  (`lib/elixir/lib/task/supervised.ex:17-30`), not spawn+monitor as two calls.
- `await/2`'s real work is `await_receive/3` (`task.ex:881-892`):
  ```erlang
  881  defp await_receive(ref, task, timeout) do
  882    receive do
  883      {^ref, reply} ->
  884        demonitor(ref)
  885        reply
  886      {:DOWN, ^ref, _, proc, reason} ->
  887        exit({reason(reason, proc), {__MODULE__, :await, [task, timeout]}})
  ```
  — the same two-clause `receive` shape as probe 7's `collect/2`, matching a tagged reply or a
  `:DOWN`.
- `await_many/2` (`task.ex:981`, recursion at `1006-1032`) generalises this to N tasks with an
  `awaiting` map shrinking exactly as probe 7's `Pending` map does — the same algorithm, in the
  language that has both a real `receive` and a real map literal to write it with.
- `Task.Supervised.reply/4` (`task/supervised.ex:34-45`) has the *worker* monitor its *owner* (not
  the direction probe 8 needed), so it does not by itself explain how `Task.Supervisor.async_nolink`
  avoids probe 8's race — and, checked rather than assumed: for plain, linked `Task.async/1`
  (`task.ex:511-519`), the owner-side monitor (`build_alias/1`) is *also* established after
  `start_link` returns, the same ordering as probe 8. It is not raced in practice only because that
  path is linked, so a crash in the gap still reaches the owner as an exit signal regardless of the
  monitor's timing (probe 10's finding). For the *unlinked* `async_nolink` path specifically, the
  defence traced back to `DynamicSupervisor.monitor_child/1`
  (`/tmp/elixir-src/lib/elixir/lib/dynamic_supervisor.ex:899-909`): the supervisor spawns the child
  **linked** (atomic with the spawn, unlike a separate `monitor` call), then
  `Process.monitor/1` **before** `Process.unlink/1`, then drains a zero-timeout `receive` for an
  `{:EXIT, pid, reason}` that may already be sitting in its own mailbox from the just-removed link —
  a monitor-plus-unlink dance built specifically to close probe 8's exact race, at the cost of extra
  machinery no hand-written `.bs` exemplar would have reason to reinvent. This was traced as far as
  confirming the mechanism exists and what it does; tracing the full path by which a crash *after*
  `start_child` already returned (probe 11's case) reaches the original caller with its reason
  intact was not completed to the same depth, so it is reported here as located, not as fully
  verified end to end — probe 6's `spawn_monitor` sidesteps needing to know any of this by making
  spawn-and-monitor one atomic call in the first place.
- The measured behavioural split (probes 10 vs 11) is real and load-bearing in Elixir's own design:
  `async_stream` (`task.ex:701,730`) links by default (probe 10's crash), and
  `Task.Supervisor.async_nolink` is the documented escape into probe 11's fault-isolated form.

**Gleam.** No package reachable in this environment supplies concurrency (probe 12).
[ticket 14](../wayfinder/issues/14-concurrency-and-otp-model.md) §7 already measured, in an earlier
session with the packages available (not reproduced here — see Methodology):
`gleam_erlang`'s `Subject(msg)` is a send-side handle whose type parameter is erased at
runtime (`14a`), `process.receive` is a filter exactly like ticket 14 §5's own decision (`14f`),
and there is no exhaustiveness over the mailbox — an actor's `select_other` is opt-in and
unmatched messages are logged and dropped (`14b`). None of that is about fan-out/collect
specifically; Gleam's actor model is single-process-at-a-time request/response (an `Actor`
answers one message at a time from its own mailbox), and neither `14a`-`14g` nor anything
findable in this session's environment shows a `Task`-equivalent fan-out combinator in Gleam. The
honest reading is that Gleam's concurrency story, as documented in this repo, has nothing to say
about this specific question — it was never measured, not because it was measured absent.

## Measured costs, summarised

| | bare `spawn_monitor` + collect (probe 7) | supervisor-mediated pool (probe 8) |
|---|---|---|
| Source lines | 53 | 76 (+43%) |
| BEAM instructions | 219 | 278 (+27%) |
| Correctness | fault-isolated, real reason preserved | fault-isolated, **real reason lost to `noproc` on a fast crash, every run** |

No beam-sharp-level cost exists to measure (no async syntax built — probes 1, 3, 5). The
comparison above is at the level every other exemplar's *lowering* was measured at before its
`.bs` form compiled (25b/c's `error_info` captures, 25d's live-capture timings), which is the
closest honest analogue available.

## Options for what the sixth exemplar should be

**Option A — bare `spawn_monitor` fan-out over an honest batch workload, written to its real wall.**
Workload: when an order ships (continuing the `Shop` domain 25a-25e already built), notify each of
its distinct suppliers independently — one unit of work per supplier, no ordering between them,
caller collects a per-supplier outcome and does not fail the whole batch when one supplier's
notification fails. Primitive: `spawn_monitor` (probe 6, real, compiles) per unit; collection via
a private recursive function that needs `receive` (probe 3: does not exist). No supervisor.

- *Evidence for it*: matches the candidate table's "whether spawn/Task survives" literally — probe
  7 shows the shape is cheap and correct at the Erlang level, and probe 6 shows its atomic
  primitive already compiles in beam-sharp. It gives the compiler a concrete, small, honest delta
  to point at — `receive` as syntax — which is exactly what CLAUDE.md's working rule asks a design
  question to produce ("a symbol-table entry, an emitted function, a pass"), and it is a delta no
  other exemplar has asked for yet (25b/c both dodged `receive` via OTP callback dispatch instead).
  It is also the one shape that is *not* a sixth `gen_server` by construction — no persistent named
  process, no callback set.
- *Strongest counterargument*: probe 3 means this exemplar's write-up hits its front wall almost
  immediately — on `receive` itself, before the workload's own logic is exercised at all — which
  is a thinner result than 25a-25e each got (every one of those got past several lines of real
  logic first, several past the whole module). Ticket 25's own standing method says that is fine
  ("write it honestly, report what it demanded"), but it is a real cost in what this exemplar
  *teaches* versus what it *demands of the compiler*, and it means this exemplar's write-up will
  read shorter and less exploratory than its five predecessors.

**Option B — the same workload, escalated to a decoupled task-supervisor pool for durability.**
Same notify-suppliers workload, but workers run under a `simple_one_for_one` supervisor
independent of the caller's own lifetime (Elixir's `Task.Supervisor`, real precedent at
`task/supervisor.ex`), so an in-flight batch survives the caller crashing.

- *Evidence for it*: directly answers "supervision of work" from the candidate table with an
  actual supervisor in the picture, and Elixir ships exactly this as a first-class module — real
  precedent, not invented.
- *Strongest counterargument*: probe 8, measured, not assumed — this shape costs 43% more source
  and 27% more instructions than Option A for the identical workload, and it introduced a genuine,
  reproducible (5/5) race that silently discards the failure reason a caller most needs, because
  `supervisor:start_child` cannot hand back an atomic monitor the way `spawn_monitor` does.
  Fixing that race (a synchronous ready-handshake, matching what `Task.Supervised.reply/4` does)
  adds a fourth real cost on top of the measured three. The honest workload chosen for Option A
  does not need the caller's crash to be survivable — a caller that wanted its order-ship
  notification fan-out to keep running after it died is not the ordinary case — so this option's
  own justification is thinner than its cost.

**Option C — the `[module: GenServer]` batch coordinator (probe 5) — named because it is what the
compiler currently pulls toward, not because it is recommended.**

- *Evidence for it*: the only shape, measured, that compiles clean through `bsc` today (probe 5) —
  writing the exemplar this way would be the only way to get a *running* beam-sharp lowering this
  session's toolchain could actually produce, matching 25a-25e's own "compiles and runs" bar
  immediately rather than waiting on `receive`.
- *Strongest counterargument*: it is a sixth `gen_server` in every way ticket 25's own prose warns
  against — a persistent, named, callback-shaped process is not what "fire N independent units and
  collect" is, and choosing it *because the compiler currently supports nothing else* is precisely
  "constructing a shape to answer a question" rather than writing the workload honestly, the
  failure mode this ticket's own post-mortem on 25a (the retracted five-condition ladder) exists to
  prevent. Naming it here is a warning against a trap, not a candidate.

## Recommendation

**Option A.** The workload (fan out one independent notification per supplier when an order ships,
collect per-supplier outcomes, no ordering between units) is the honest reading of "async
processing" that none of the five written exemplars cover, and it is provably not a disguised
sixth `gen_server` — probe 5 shows what that alternative actually looks like, and it is a different
shape in every dimension the ticket cares about (persistent vs. transient, named vs. anonymous,
callback-dispatched vs. plain-function-triggered). Write it to its real wall, per the standing
method: expect the front wall to be `receive` itself (probe 3), record that as the finding — it is
a small, concrete, previously-unmeasured compiler delta, exactly the shape CLAUDE.md's working
rule wants a design question to produce — and record probe 8's race as the reason *not* to reach
for a supervisor-mediated pool once `receive` exists, so the next person who tries Option B does
not have to rediscover it. Do not build `receive` as part of writing this exemplar; per CLAUDE.md,
a feature that needs building is F-ticket territory once someone picks it up, not something this
decision should quietly resolve by writing code.

## Verification

No subagent-spawning tool was available (see Methodology) — `ToolSearch` for
`Agent`/`Task`/`SpawnAgent`/`TaskCreate` matched nothing, and no `Agent` tool is in this session's
tool list. This section is a second, independent pass done in this same session: every probe
script copied — source only, no compiled `.beam`/`.out` artifacts — into a fresh directory
(`/tmp/verify-fresh`, never touched during the first pass) and re-run from there with the same
driver script, then diffed against the first pass's captured transcript.

**Circularity check, per probe** — was any "expected" result computed by anything other than the
real interpreter/compiler:

| Probe | Real component exercised | Circularity check |
|---|---|---|
| 1, 2, 3, 4, 5, 6 | `bsc` (the actual compiler binary) | The script contains no hardcoded expected string compared against; it runs `bsc` and prints raw stdout/exit code. The `# expect:` comments in `run_all_probes.sh` were written *after* the real result was first observed (this session, interactively, before the script existed) and are documentation, not assertions the script checks — nothing in the script can silently substitute a canned answer. **PASS.** |
| 7, 8 | `erl` running compiled `.beam` from real `.erl` source | `work/1`'s crash on `N =:= 3` is a genuine conditional inside the probe, not a mock of an external system — the collector does not know in advance which unit fails; it learns it from a real message or a real `'DOWN'` that the BEAM runtime actually delivers. Re-run 5 times during the first pass with unanimous `noproc` (not cherry-picked — all 5 are in `run_all_probes.out`'s predecessor transcript). **PASS.** |
| 9 | `beam_disasm` on the real compiled beams | Instruction counts come from `beam_disasm:file/1` reading the actual compiled `.beam`, not a hand count. **PASS**, with the byte-size caveat below. |
| 10, 11 | `elixir` running real `Task`/`Task.Supervisor` | Same `work/1` design as probes 7/8, real OTP `Task` machinery, not stubbed — the `[error]` log lines come from Elixir's own `Logger`, not from this script. **PASS.** |
| 12 | `find`, `ls`, `grep` against the real filesystem | Directly inspects what is actually present; no claim here depends on anything computed rather than observed. **PASS.** |

**Fresh re-run result**: `bash /tmp/verify-fresh/run_verify.sh` (the same script, `SP` repointed)
against the untouched copy completed exit 0. Diffed against the original transcript after
normalising four classes of expected non-determinism (pids `<0.N.N>`, refs `#Ref<...>`, wall-clock
microseconds, log timestamps): **identical, line for line, with one exception** — the two `.beam`
files' raw byte sizes (`2240`/`2728` first pass vs. `2096`/`2584` on the fresh copy, both exactly
144 bytes smaller). Investigated rather than waved away: the compiled path in the fresh copy
(`/tmp/verify-fresh/erlang_fanout_probe.erl`, 41 characters) is 79 characters shorter than the
original scratchpad path (120 characters) — `erlc` embeds the absolute source path in the beam's
compile-info/debug chunks, so a shorter path compiles to a smaller file. The **instruction count**
`beam_disasm` reports (219, 278) did not move at all between the two runs, which is why § Measured
costs cites instruction count rather than byte size as the reproducible figure — corrected in this
pass rather than left as a loose end. Everything else — every `bsc` exit code and diagnostic text,
every `erl`/`elixir` result list, the `noproc` race (5/5 on the original pass, reproduced again on
the fresh one), and the `find`/`grep` results for Gleam — reproduced byte-for-byte.

**Conclusion: all twelve probes PASS** — independently reproduced, no hardcoded or mocked results
found, the one discrepancy (raw beam byte size) traced to a real and well-understood cause (embedded
source path length) and corrected to a stable metric rather than asserted away.
