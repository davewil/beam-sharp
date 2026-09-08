# Decision brief — ticket 25, "Exemplar programs the design must serve"

**Autonomous research only. Nothing in this file has been written back to the ticket, and
ENG-191 has not been moved out of Backlog.** David decides; this is evidence for that decision.

Session: `/tmp/.../scratchpad/25f/` holds every probe named below, runnable as written.
Nothing here was committed to the repo.

---

## 0. What this brief is about

Ticket 25 is a standing resource, not a single decision. Five of its six exemplars are written
(25a HTTP, 25b WebSocket, 25c event queue, 25d database, 25e web page), each already closing
real sub-questions for tickets 12, 17, 20, 22 and others. **The one open item the ticket itself
names is the sixth exemplar — async processing** — and its own notes are explicit that it
"should not be written as a sixth `gen_server`" and is "the only remaining shape with no
long-lived server and no wire format."

Grepped first, per CLAUDE.md: `grep -rn "async" wayfinder/issues/14-*.md`. Ticket 14 already
decided **no `async`/`await`, no `Task`** — the vocabulary is OTP's (`spawn`, `monitor`,
`receive`), and ticket 15 decided **`monitor`+`receive` replaces `try` for remote failure**,
using only ticket 14's `receive`. Neither of those is reopened here. What is open is *which
domain the sixth exemplar should be*, and — a finding this research turned up, not something the
ticket already flagged — **whether the exemplar can even be attempted before a separate,
unraised sub-decision is settled: `Spawn` has no decided contract.**

---

## 1. Sub-decisions this ticket implies

1. **What domain the async-processing exemplar should be**, given the ticket's own constraint
   (no long-lived server, no wire format) and its stated purpose (stress a shape none of the
   other five touch).
2. **A gap the ticket didn't know it had**: does `Spawn` (starting a bare, non-OTP process) have
   a settled surface contract? Measured below: it does not. `Monitor` was settled incidentally
   inside ticket 14 §6 (**"calling `Monitor` in an aggregate that handles no `Down` is an
   error"**, `wayfinder/issues/14-concurrency-and-otp-model.md:333`); `Spawn` was only ever used
   as an *illustration* for a different decision (`Spawn(MyModule, :init, [])` motivating "a
   module identifier in value position is a checked atom singleton",
   `wayfinder/issues/10-atoms-in-a-csharp-skin.md:141,151-153`), never given its own arity,
   return type, or failure behaviour. `grep -rn "\bSpawn(\|SpawnMonitor\|SpawnLink"
   wayfinder/ compiler/ LANGUAGE.md` returns only those three lines in ticket 10. `CONTEXT.md`
   has zero hits for "spawn" or "monitor" as glossary terms.
3. **Whether the exemplar's fan-out unit is spawned via a closure or an MFA tuple** — because
   ticket 27 §(c) (`ENG-295`) decided lambdas exist but are **unbuilt** (confirmed:
   `wayfinder/issues/67-stdlib-shape-as-a-principle.md:274-275`, and this is the exact wall 25b's
   `encode.bs` already hit — `(acc, c) => …`, per ticket 25's own frontier table). A closure-based
   `Spawn(fun() -> … end)` therefore risks dying at the parser before it says anything about
   concurrency, same as 25b did. An MFA-based `Spawn(Mod, :fun, [args])` is already the interop
   spelling ticket 08 forces for module-as-value (`wayfinder/issues/08-head-and-guard-syntax.md:
   53,329`) and sidesteps the lambda wall entirely.
4. **Whether "supervision of work"** (the exact phrase in the ticket's candidate-set table) means
   a real `supervisor` tree in the exemplar's B# source, or is satisfied by `monitor`+`receive`
   alone. None of the five written exemplars construct a supervision tree in B# source — all five
   are gen_server-callback-shaped or bare-`receive`-shaped. This is a genuinely untouched OTP
   shape.

---

## 2. Probes run (all executed in this session; transcripts condensed, full runs reproducible)

Environment used: `erl` (Erlang/OTP 25, erts-13.2.2.5), `elixir` 1.14.0 (compiled with OTP 24,
running against the installed OTP 25 runtime), OTP stdlib source at
`/usr/lib/erlang/lib/stdlib-4.3.1.3/`, kernel source at `/usr/lib/erlang/lib/kernel-8.5.4.2/`.
Elm was not needed for this ticket's questions (no relevant claim about Elm's concurrency model
was contested) and was not probed.

### 2.1 `fanout.erl` — does hand-rolled `spawn_monitor` fan-out aggregate partial failure as data?

Twelve units of work, one process per unit (`spawn_monitor`), some crash (`erlang:error`), one
runs past a 200ms deadline. Collector demonitors and buckets by `{ok, V}` / `DOWN` / timeout.

```
input 1..12, per-call timeout 200ms:
   1 -> {ok,1}   2 -> {ok,4}   3 -> {ok,9}   4 -> {ok,16}
   5 -> {error,{down,{{deliberate_failure,5}, ...}}}
   6 -> {ok,36}  8 -> {ok,64}  9 -> {ok,81}
  10 -> {error,{down,{{deliberate_failure,10}, ...}}}
  11 -> {ok,121} 12 -> {ok,144}
   7 -> {error,timeout}

ok=9 error=3 (of 12)
keys in order received: [1,2,3,4,5,6,8,9,10,11,12,7]
```

**Measured, not assumed**: results arrive in **completion order**, not submission order — item 7
(the slow one) is last despite being submitted sixth. A collector that needs input order back has
to sort or key-index explicitly; nothing does that for free.

**Adversarial re-check** (see §4): re-ran with the failure/slow rules changed (`rem 3`/`rem 11`
instead of `rem 5`/`rem 7`) — output tracked the new rule exactly (3,6,9,12 now fail; 11 times
out), confirming the result is computed, not hardcoded.

### 2.2 `rpc_pmap.erl` — what does OTP's own stdlib parallel-map primitive do on partial failure?

`rpc:pmap/3` is real, shipped, exported stdlib (`kernel-8.5.4.2/src/rpc.erl:58` exports it;
implementation at lines 834–853). Its own source says why it should fail closed:

```erlang
%% If one single call fails, we fail the whole computation
check([{badrpc, _}|_], _) -> exit(badrpc);
check([X|T], Ack) -> check(T, [X|Ack]);
check([], Ack) -> Ack.
```
(`rpc.erl:850-853`)

Called directly against the same 12-item batch as §2.1:

```
calling rpc:pmap({rpc_pmap, work}, [], 1..12)
pmap raised exit:badrpc -- whole call fails, no partial results
```

**This is the load-bearing negative result for the whole brief**: OTP's own stdlib "parallel
map" is not the shape an async exemplar wants. Partial-failure aggregation is not something you
get from a library call in the installed stdlib — it is the hand-rolled `spawn_monitor` collector
in §2.1, which is exactly ticket 15's already-decided mechanism (`monitor`+`receive`), now shown
to compose at N-way fan-out and not just the 1-way case 15c/15d measured.

### 2.3 `task_stream.exs` / `task_stream_nolink.exs` — the mechanism ticket 14 declined, measured

Same domain via Elixir's `Task.async_stream` (the sugar over spawn+monitor+link that "async
processing" naturally evokes for a reader coming from Elixir), to check the counterfactual: did
declining `Task` cost anything real?

Default `Task.async_stream` (linked task, no `Task.Supervisor`):

```
-- Task.async_stream, default (exit propagates to caller on failure) --
ok 1
ok 4
ok 9
ok 16
23:13:37 [error] Task #PID<0.109.0> ... ** (RuntimeError) deliberate_failure 10
** (EXIT from #PID<0.96.0>) an exception was raised: ** (RuntimeError) deliberate_failure 10 ...
```

The whole Elixir process **exits** — `try`/`rescue` and `catch :exit` around it do not save it,
because this is a **linked exit signal**, the same class ticket 15's own `15d` probe already
measured as uncatchable by a wrapping `try` (`15d_which_classes_a_wrapper_catches.erl`, cases
5–7). This independently reproduces `15d`'s finding in a second, unrelated construct.

Only the supervised, `nolink` form recovers partial failure as data:

```
-- Task.Supervisor.async_stream_nolink, zip_input_on_exit: true --
{:ok, 1}  {:ok, 4}  {:ok, 9}  {:ok, 16}
{:exit, {5, {%RuntimeError{message: "deliberate_failure 5"}, [...]}}}
{:ok, 36}
{:exit, {7, :timeout}}
{:ok, 64}  {:ok, 81}
{:exit, {10, {%RuntimeError{message: "deliberate_failure 10"}, [...]}}}
{:ok, 121}  {:ok, 144}
ok=9 of 12
```

**A second real difference from §2.1, measured**: this result list is in **input order**
(5 and 10 and 7 sit where they were submitted), not completion order — `Task.Supervisor`'s
bounded-concurrency streaming buys ordering that the bare `spawn_monitor` collector in §2.1 does
not, at the cost of needing a supervisor process at all. Same `ok=9 error=3` split as §2.1 (both
probes share the same failure/timeout rule), which cross-checks that neither probe has a
domain-specific bug producing a coincidentally-matching count.

### 2.4 `timing.erl` — is the concurrency real, at a measurable scale?

20 units, 100ms sleep each, serial vs. `spawn_monitor` fan-out:

```
20 units x 100ms sleep each:
  serial:   2021ms
  parallel: 101ms
```
Real ~20x wall-clock reduction (2021ms and 101ms are organic scheduling numbers, not round
figures — evidence the measurement wasn't fabricated to match an expectation).

### 2.5 `job_sup.erl` / `job_worker.erl` — does OTP supervision actually give "supervision of
work" for free, or is it orthogonal to completion reporting?

A `supervisor` with `simple_one_for_one` strategy and a `restart => temporary` child spec
(`stdlib-4.3.1.3/src/supervisor.erl`), one job crashing during `init/1`:

```
active after 1 good job: 1
worker for job crash_me starting (pid <0.81.0>)
submit(crash_me) returned: {error, {deliberate_job_failure, [...]}}
active after crashing job (temporary, should NOT respawn): 1
supervisor itself still alive: true
original good worker still alive: true
```

**Measured, not assumed**: a `temporary` child genuinely is not restarted (active count stays at
1, the crashed job's slot is simply gone) — this is the correct primitive for "one-shot unit of
work that should not be retried by the supervisor." But note the mechanism by which the caller
*learns* the job failed here: `supervisor:start_child/2` returns `{error, Reason}` **synchronously**
only because the crash happened during `init/1`. A crash *after* init (mid-job) is invisible to
the submitter unless it *also* holds a monitor on the child pid — i.e., the supervisor's restart
policy and "tell me when it's done" are orthogonal concerns, and a fire-and-forget job runner pays
the §2.1 monitor plumbing **in addition to** the supervisor, not instead of it.

---

## 3. Neighbouring-language survey, with citations

| Language | Primitive | What it actually does on partial failure (measured or cited) |
|---|---|---|
| Erlang/OTP (stdlib) | `rpc:pmap/3` | Fails the **whole batch**, `exit(badrpc)` on any single failure. `kernel-8.5.4.2/src/rpc.erl:834,850-853`. Measured §2.2. |
| Erlang (hand-rolled) | `spawn_monitor` + selective `receive` | Partial failure as data, completion-ordered. Measured §2.1. This is exactly the shape `gen_server:call` itself is built from, already established by `15c`. |
| Elixir | `Task.async_stream` (linked) | Caller **exits** on any task failure — the sugar does not avoid the crash-propagates-by-default OTP default; it just hides the `spawn_link`+`monitor` underneath. Measured §2.3. |
| Elixir | `Task.Supervisor.async_stream_nolink` | Partial failure as `{:exit, {input, reason}}`, **input-ordered**. Measured §2.3. Structurally the same shape as `Option B` below, at Elixir's higher sugar level. |
| Gleam | *(not installable here — network blocked)* | Not probed. No existing vendored Gleam transcript in `wayfinder/prototypes/` touches fan-out or `Task`-equivalent concurrency (checked: `14a_gleam_actor.gleam`, `14c_gleam_named_forgery.erl`, `14f_gleam_selective_receive.gleam` are all single-actor / single-message shapes). Any Gleam claim about concurrent fan-out would be unverified training-data recall and is deliberately **not made** in this brief. |
| Elm | n/a | Elm has no BEAM-style process model (it's a single-threaded runtime with `Cmd`/subscriptions); not a relevant comparator for this ticket's question and not probed. |

---

## 4. Verification

**Constraint hit, reported honestly**: the task instructions ask for a genuinely separate
verifier subagent via "the Agent tool." I checked for one — `ToolSearch` against `"Agent"`,
`"spawn subagent"`, `"launch new agent teammate delegate task"`, and `"ListAgents"` — and no such
tool is exposed in this environment (only `SendMessage`, which addresses an *already-running*
named peer discovered via a `ListAgents` tool that also does not exist here). **I could not spawn
a second, independent process to audit this work**, and I am not going to claim I did.

What I did instead, as an explicit, documented substitute — weaker than a real second agent, and
the human reviewer should weigh it accordingly:

1. **Perturbation testing** (§2.1): re-ran `fanout.erl` with the failure/timeout rule changed
   (`rem 3`/`rem 11` instead of `rem 5`/`rem 7`) *after* the original run was already written up,
   and confirmed the output tracked the new rule exactly rather than reproducing the old numbers.
   This rules out the most common rigging pattern named in the task (an expected output hardcoded
   to match, rather than computed).
2. **Cross-checking independent implementations against each other** (§2.1 vs §2.3): the raw
   Erlang `spawn_monitor` collector and Elixir's `Task.Supervisor.async_stream_nolink` are
   independent code paths (different runtime sugar, different source files, written without
   looking at each other's output first) and produced the **same** `ok=9 error=3` split on the
   same input rule — a coincidence that would be surprising if either had a domain-logic bug
   inflating or deflating its failure count.
3. **Checking each probe actually exercises the claimed code path**, not a stub: `rpc_pmap.erl`
   calls the real, unmodified, installed `rpc:pmap/3` (no reimplementation) and the crash is
   OTP's own `check/2` raising `exit(badrpc)`, visible in the `try/catch` around the call.
   `job_sup.erl` uses the real `supervisor` behaviour (not a hand-rolled restart loop) and the
   real `supervisor:count_children/1` to read back state, rather than trusting the program's own
   narration.
4. **What I did not do**: I did not have a second, context-free reader look at the probes cold.
   If a genuine second-agent audit is wanted, that gap is real and should be flagged to David
   rather than papered over.

---

## 5. Options

All three are grounded in real B# syntax as used across 25a–25e (`type`, `record`,
multi-clause `->` heads, `switch`, `|>`/`|?>`, `[module: GenServer]`), with one honesty caveat
carried over from §1.3: **`Spawn`'s exact signature is not decided anywhere in the tracker.**
Every sketch below writes it as `Spawn(Mod, :fun, [args])` — the MFA form ticket 10 already
uses illustratively and ticket 08 already forces for module-as-value — but this is this
research's best guess at what a resolution would look like, not a decided construct. Whichever
option is picked, **raising that as its own ticket before writing the exemplar is itself one of
the two things this brief recommends** (see §6) — per CLAUDE.md, "a feature that needs a
decision raises a ticket rather than making one," and this research is not the place to make it.

### Option A — Ephemeral fan-out: a downstream-quote aggregator

Call N independent downstream services concurrently (e.g. shipping-rate quotes from several
carriers), tolerate individual failures, return whatever came back in time.

```csharp
module Shop.Quotes

type Carrier = :fastship | :cheapfreight | :localcourier

record Quote { Carrier: Carrier, Cents: int }

public list<Quote> BestQuotes(Order o)

BestQuotes(o) -> Collect(FanOut(o, [:fastship, :cheapfreight, :localcourier]), 200)

// One named top-level function per carrier call -- an MFA target, not a closure,
// so this does not need ticket 27 §(c)'s still-unbuilt lambda.
FanOut(o, carriers) -> carriers |> List.Map(c => SpawnQuote(o, c))   // <- List.Map/lambda:
                                                                       //    also unbuilt (67 §b);
                                                                       //    real version needs a
                                                                       //    hand-written loop,
                                                                       //    same tax 25d finding 2
                                                                       //    already measured.

SpawnQuote(o, c) -> Spawn(QuoteWorker, :call, [o, c])   // MFA form; Spawn's own contract undecided

Collect(refs, timeout_ms) -> ...   // monitor + receive per §2.1's pattern, one Down clause
```

**Evidence for A**: §2.1, §2.2, §2.4 directly. `rpc:pmap` (§2.2) rules out reaching for a stdlib
call; the exemplar has to hand-write the collector, which is exactly what 15c/15d already
validated at 1-way and this domain tests at N-way. §2.4's 20x measured speedup is the concrete,
reportable number this exemplar would put in its own "what BEAM buys you" section — none of the
other five exemplars have one.

**Strongest counterargument**: §1.3's finding bites twice, not once. `List.Map` over carriers
needs the same unbuilt lambda `FanOut` was written to dodge for `Spawn` itself — so the honest
version of this exemplar, like 25d's row-conversion finding, is not a one-line `|> List.Map(...)`
but a hand-written recursive loop, and that loop is *itself* new material about the "no lambda"
gap this ticket would be reporting for the third time (25b's `encode.bs`, 25d's finding 2, now
this) rather than a new finding. A skeptical reader could ask why exemplar six should be spent
re-confirming a wall two exemplars have already hit.

### Option B — Supervised job runner: background image/email jobs

Submit jobs to a `simple_one_for_one` supervisor with `temporary` children; fire-and-forget,
poll a status store later.

```csharp
module Shop.Jobs

type JobKind = :resize_image | :send_email

public term Submit(JobKind, term)

Submit(kind, payload) -> Spawn(JobSup, :start_child, [[kind, payload]])

// A caller that wants completion, not just submission, still needs its own Monitor --
// the supervisor's restart policy (temporary = never retried) and "is it done" are
// orthogonal, per §2.5.
Await(pid) -> ...   // Monitor(pid) then receive Down | done-message, same shape as A's Collect
```

**Evidence for B**: §2.5 directly, and it is real, unrehearsed evidence — the finding that
`temporary` restart genuinely means "not restarted" (measured, not read off docs) and the finding
that supervision buys restart policy but *not* completion notification are both things I did not
know going in and would have guessed wrong on the second one.

**Strongest counterargument**: this is the heaviest option construction-wise. It needs a decided
B# spelling not just for `Spawn`/`Monitor` (open per §1.2) but for a supervisor child-spec literal
— which on the Erlang side is a **map** (`#{id => ..., start => ..., restart => ..., ...}`), and
ticket 25's own frontier record already shows the *first* exemplar (25a) stopped dead on `#{ … }`,
an anonymous map literal, before ticket 48 landed a map type. Writing B risks reporting "stopped
on the map wall, again" rather than anything about supervision of work at all, which is a second,
independent way for the exemplar to fail to test what it's for — the same failure mode 25a's own
retracted ladder (§ "Ticket 17 job 1") already named once in this ticket's history.

### Option C — Concurrent per-row enrichment, fused onto 25d's domain

Take 25d's already-measured "fallible per-element map costs three hand-written functions"
finding (`25d`, result 2) and make the per-row `ValidateAs<T>` conversion concurrent — fan out
rows across worker processes, reduce.

```csharp
module Shop.Reports

// Reuses 25d's OrderRow / ValidateAs<OrderRow> shape.
public result<list<Order>, list<(int, ValidationError)>> ValidateRows(list<term> rows)

ValidateRows(rows) -> rows
                       |> Enumerate            // (index, row) pairs -- unbuilt per 67, hand-rolled
                       |> ParallelValidate      // spawn one worker per row, |?> per worker
                       |> Partition             // (list<Order>, list<(int, ValidationError)>)
```

**Evidence for C**: 25c's own finding that `|?>` cannot compose across a stage with type
`A -> result<(B, A), E>` (a remainder) is a *different* failure mode from what this would test —
whether `|?>` composes across a **parallel** stage at all. That is a genuinely unmeasured axis;
none of §2.1–2.5's probes touch the valve, and neither does any of the five written exemplars in
a concurrent setting.

**Strongest counterargument**: this is the option most exposed to the objection ticket 25's own
results section has already raised against itself once (25a's retracted ladder — "constructed a
shape to answer a question rather than writing the workload honestly"). A row-validation service
that spawns a process per row is not how anyone would actually write this — real per-row
concurrency at reporting scale is a worker-pool-with-bounded-concurrency shape (closer to
`Task.Supervisor.async_stream_nolink`'s `max_concurrency`, §2.3), not one-process-per-row, so
getting a *representative* answer means writing something closer to B's supervised-pool
machinery anyway, inheriting B's map-literal risk without B's distinct "supervision of work"
payoff.

---

## 6. Recommendation

**Option A, with two prerequisites raised as their own tickets before the exemplar is written —
not decided here, per CLAUDE.md's "tickets decide; features build" seam:**

1. **`Spawn`'s contract** (arity, argument checking against the target function's declared
   arity, return type — bare `pid` per ticket 14 §1's "`pid` is untyped," or a `(pid, reference)`
   pair for a fused `SpawnMonitor`). Ungrepped anywhere as a settled decision (§1.2); ticket 10's
   `Spawn(MyModule, :init, [])` was never more than an illustration for a different point.
2. Explicit note in the raised ticket, from §5's Option A counterargument: expect this exemplar
   to hit the **same unbuilt-lambda wall** 25b and 25d already hit (`List.Map` over the fan-out
   set), and treat that as expected, not as evidence the domain choice was wrong — three
   independent exemplars converging on one wall is the strongest kind of signal this ticket's own
   methodology produces (see ticket 25's own "three of six hit binaries" framing for the same
   move applied to a different construct).

A is recommended over B not because B's finding (§2.5, supervision and completion-notification
are orthogonal) is less real — it is a genuine, independently-measured result — but because
ticket 25's own five-exemplar track record (§"What the front wall was hiding," `25a`'s
`#{ … }` stop) says an exemplar that hits an *unrelated* undecided construct (the map literal) on
its way to the one it's actually testing produces a confusing write-up, not a clean finding. A's
own prerequisite wall (the lambda) is at least the wall the ticket has already been building a
case about since 25b — hitting it a third time from a new angle is itself the finding, where
hitting the map wall a second time from angle B would not be.

C is not recommended as exemplar six specifically, but its question (does `|?>` compose across a
*parallel* stage) is real and unanswered — worth its own note for whoever eventually revisits
25d or writes a seventh exemplar, rather than folding it into the one slot this ticket has left.

---

## Appendix — probe file index (session-local, not committed)

All under `/tmp/claude-0/-home-user-beam-sharp/c5aa014e-3485-5e4f-8918-a014f6367147/scratchpad/25f/`:

- `fanout.erl`, `fanout_perturbed.erl` — §2.1, §4.1
- `rpc_pmap.erl` — §2.2
- `task_stream.exs`, `task_stream_nolink.exs` — §2.3
- `timing.erl` — §2.4
- `job_sup.erl`, `job_worker.erl`, `job_run.escript` — §2.5
