# Audit: ticket 25 — exemplar programs the design must serve

Research only. **No ticket status, no `Status:` line, and no Linear state were changed by this
audit** beyond posting one comment to ENG-191. `wayfinder/issues/25-exemplar-programs.md` is
unmodified; ENG-191 remains `Backlog`.

Ticket 25 is unusually mature: five of its original six exemplars are written, lowered to Erlang,
run, and have produced eleven dated `RESULTS` sections between 2026-08-13 and 2026-08-26. This
audit does not re-litigate any of that. It extracts the sub-decisions the ticket still leaves open,
writes concrete candidates for each in the required no-recommendation shape, and backs every claim
with something executed or fetched in this session.

## Environment actually used

- Local toolchain: **Erlang/OTP 25** (erts-13.2.2.5), **Elixir 1.14.0** (built with OTP 24), Mix
  1.14.0. The ticket's own lowerings were run and measured on **OTP 28.5 / OTP 28**. Every probe
  below is dated to OTP 25 explicitly; nothing from the ticket's OTP-28 results was re-asserted as
  re-verified unless it was actually re-run here.
- The `json` module (stdlib, OTP 27+) is **not present** on OTP 25, and neither Jason nor Poison is
  installed. Attempting to reproduce the ticket's `json:encode` tuple-refusal claim
  (`crashed, error, unsupported_type`) failed with `undef`, not with the claimed behaviour. **This
  session could not independently verify that specific claim** — it is reported here as untested,
  not re-confirmed.
- `api.github.com` is session-scoped to configured repositories only (`GitHub access to this
  repository is not enabled for this session`); `raw.githubusercontent.com` is not, and returned
  `200` for arbitrary public files. All GitHub citations below are raw-file fetches actually made
  in this session (shown as URL, HTTP 200, path/line). Blind guesses at specific `erlang/otp`
  example paths mostly returned `404` (`system/examples/gen_statem/code_lock.erl`,
  `system/doc/design_principles/code_lock.erl`); one guess hit (`lib/stdlib/examples/erl_id_trans.erl`,
  200) but it is a stdlib AST-transform template, not OTP-behaviour example material, so it is not
  used as evidence for anything below. No fabricated OTP citation is included.
- **No `Agent`/`Task` spawning tool is exposed in this session's toolset** (checked the top-level
  tool list and via `ToolSearch` for `Agent`, `Task`, `LaunchAgent`, `SpawnAgent`,
  `BackgroundAgent` — none matched). The independent re-verification pass (§5) was therefore done
  by me, in a second pass, in a clean directory, with every probe **deliberately rewritten** rather
  than re-run byte-for-byte, specifically to catch a probe tuned to its expected answer. This is a
  deviation from the letter of the instruction and is reported as one, not silently substituted.

---

## 1. Measured: what BEAM primitive each written exemplar actually exercises

Requested measurement, done by grepping the five real lowerings
(`wayfinder/prototypes/25{a,b,c,d,e}_*_lowering.erl`):

| Exemplar | `gen_server` | `gen_statem` | bare `spawn`/`receive` | supervisor tree | ETS | port/NIF |
|---|---|---|---|---|---|---|
| 25a HTTP API | 0 | 0 | 0 | 0 | 0 | 0 |
| 25b WebSocket | 1 | 0 | 2 spawn / 4 receive | 0 | 0 | 0 |
| 25c event queue | 0 | 0 | 1 spawn / 3 receive | 0 | 0 | 0 |
| 25d database | 0 | 0 | 0 | 0 | 0 | `epgsql` driver calls (abstracts its own port) |
| 25e web page | 0 | 0 | 0 | 0 | 0 | 0 |

Across all five: **`gen_server` appears once, bare `spawn`+`receive` twice, and `gen_statem`,
`supervisor`, `ets:`, and a raw `open_port`/NIF call appear in **zero** of them.** `gen_statem` does
not appear anywhere in `wayfinder/` or `compiler/` at all —
`grep -rli gen_statem wayfinder/ compiler/` returns no hits, versus `GenServer`/`Supervisor`
appearing throughout ticket 14, ticket 35, `compiler/src/bs_otp.erl`, and `F10-otp-callbacks.md`.
Ticket 25's own row for the one exemplar left, "async processing," lists what it stresses as
*"whether `async`/`await` survives, or `spawn`/`Task`; supervision of work"* — supervision is named
and, measured above, has never been built into anything that runs.

---

## 2. Sub-decision: what fills the sixth exemplar, "async processing"

The ticket's own closing note (2026-08-26) already narrows this: both its tickets (14, 15) are
resolved, so it *tests*, and it explicitly should not be "a sixth `gen_server`." Three candidates,
each a different BEAM primitive from §1's gap table.

### Candidate A — `Shop.Quotes`: fan-out quote aggregator over bare processes

```csharp
module Shop.Quotes
using Shop.Suppliers

record Quote { Supplier: string, Price: int }
type QuoteOutcome = Quote | (:timeout, string) | (:crashed, string, term)

list<QuoteOutcome> BestQuotes(string sku, int deadline_ms)
```

One process per supplier, `spawn_monitor`, no server, no wire format — matching the note precisely.

**Surface exercised:** bare `spawn`/`receive` (a third time in the set, after 25b/25c), the
compiler-known `Down`/`Timeout` message names ticket 14 §6 decided, an aggregation fold over a
three-way outcome union (ticket 15's error model applied to *N independent* failures rather than
one).

**Tickets stressed:** 14 (§2 "no async/await, no Task," §5 receive-as-filter, §6 compiler-known
message types), 15 (partial-failure aggregation).

**Evidence, executed this session** (`p3_scatter.erl`, OTP 25, and independently rewritten as
`scatter_check.erl` in a clean directory with different names, a different crash reason, and a
different task ordering — same result both times):

```
$ erl -noshell -eval 'p3_scatter:run().'
results: [{fast,{ok,100}},
          {slow,{error,timeout}},
          {crashy,{error,supplier_down}}]

$ erl -noshell -eval 'scatter_check:go().'
independent-reverify scatter: [{ok_fast,ok,42},
                               {dies,crashed,{kaboom,...}},
                               {too_slow,timeout}]
```

`spawn_monitor` + selective `receive` over `{'DOWN', Ref, process, Pid, Reason}` + an `after`
timeout produces exactly the three-way split (success / crash / timeout) both times, on real OTP
25, with two structurally different programs.

**Counterargument, as fact:** this exercises no primitive the set hasn't already touched.
`receive`+`after`+`Down` already appear in 25b's `handle_info` (finding: *"a process can time out
with a non-empty mailbox"*) and in 25c's back-pressure measurement. It tests depth (N-way
concurrent fan-out) rather than breadth — the §1 gap table's zero columns (supervisor, `gen_statem`,
ETS, ports) would still all read zero after this exemplar was written.

### Candidate B — `Shop.Jobs`: a supervised worker pool

```csharp
module Shop.Jobs
using Shop.Suppliers

type RestartPolicy = :permanent | :transient | :temporary

[module: Supervisor]
SupervisorSpec JobSup(list<JobSpec> jobs)
```

A `simple_one_for_one` supervisor starting one worker per submitted job, `transient` restart so a
worker that dies on bad input is retried once and one that finishes normally is not — the literal
reading of the exemplar row's "supervision of work."

**Surface exercised:** the supervisor tree — the one §1 zero-column that ticket 25's own table names
by name and nothing has built.

**Tickets stressed:** 14 (supervision, restart strategy — genuinely untested in this set), 15 (what
a crash reason becomes on the wire back to whoever submitted the job).

**Evidence, executed this session**, real `simple_one_for_one`/`transient` supervisor on OTP 25
(`p1b_supervisor.erl`, independently rewritten as `sup_check.erl` with different module/variable
names, a different worker id, and a different crash trigger — same result both times):

```
$ erl -noshell -eval 'p1b_supervisor:run().'
worker 3 (attempt 1) crashing on purpose
=SUPERVISOR REPORT====  reason: boom  ...
children after worker 3's crash+restart: [{specs,1},{active,4},{supervisors,0},{workers,4}]

$ erl -noshell -eval 'sup_check:go().'
=SUPERVISOR REPORT====  reason: deliberate_failure  ...
independent-reverify: before=4 after=4 tries_for_7=[{7,2}]
```

A worker that crashes once is restarted automatically and live child count is unchanged before and
after (`before=4 after=4`, `tries_for_7=[{7,2}]` — `wstart/1` really ran twice). Separately measured
(first pass, `p1_supervisor.erl`): a worker that crashes on *every* restart attempt escalates to
`reached_max_restart_intensity` and takes the whole supervisor down — real BEAM restart-storm
behaviour, and a failure mode none of the five written exemplars can currently exhibit because none
of them supervise anything.

Real prior art, fetched live from GitHub this session
(`https://raw.githubusercontent.com/gleam-lang/otp/main/src/gleam/otp/static_supervisor.gleam`,
HTTP 200, and `.../supervision.gleam`, HTTP 200 — both on the `main` branch): Gleam's own OTP
library, a neighbouring BEAM language with the same closed-union ambition, already models restart
strategy and restart policy as typed enums rather than atoms:

```gleam
// static_supervisor.gleam:43-56
pub type Strategy {
  OneForOne
  OneForAll
  RestForOne
}
// supervision.gleam:4-14
pub type Restart {
  Permanent
  Transient
  Temporary
}
```

That is exactly the shape beam-sharp's exhaustiveness checker exists to prove complete, in a
language that ships and is used in production.

**Counterargument, as fact:** ticket 14's own resolution (quoted in ticket 25 itself, "Constraints
from ticket 14") already settled that *"supervisors and applications need no separate answer... the
child spec is data."* Nothing about restart strategy is undecided at the design level — only
unbuilt at the exemplar level. And the ticket's own closing note says the remaining exemplar
"should not be written as a sixth `gen_server`"; a supervisor governing plain OTP workers is still
recognisably OTP-shaped, arguably closer to a sixth `gen_server` in spirit than the note intends,
even though the primitive itself (§1) is genuinely unexercised.

### Candidate C — `Shop.Session`: a lock/session flow on `gen_statem`

A login or checkout flow (`locked → unlocked → locked`, or `pending → paid → shipped`) written on
`gen_statem`'s `state_functions` callback mode, which dispatches on **(State, EventType,
EventContent)** — a two-axis multi-clause shape distinct from `gen_server`'s
`handle_call(Request, From, State)`.

**Surface exercised:** `gen_statem`, confirmed absent from the whole design (§1).

**Tickets stressed:** 14 (its own open question, *"How are OTP behaviours expressed? GenServer,
Supervisor, Application — as some declaration form"* — `gen_statem` was never in that list), 35
(behaviour-callback-names, which currently only names GenServer/Supervisor/Application callbacks).

**Evidence, executed this session**, real `gen_statem` with `state_functions` mode on OTP 25
(`p2_statem.erl`, independently rewritten as `statem_check.erl` with a lock/read model instead of a
coin-turnstile model — same shape, different program, same result):

```
$ erl -noshell -eval 'p2_statem:run().'
push while locked -> {denied,locked}; push after coin -> ok

$ erl -noshell -eval 'statem_check:go().'
independent-reverify statem: read-before-open={error,closed} read-after-open={ok,none}
```

Both confirm the same event, sent in the same two states, produces two different replies purely
from state-function dispatch — the callback shape ticket 14 called "the feature's best showcase" for
`gen_server`, reproduced one level up for a state machine.

**Counterargument, as fact:** ticket 14's own list of open OTP-surface questions names GenServer,
Supervisor and Application and stops there; `gen_statem` has never been raised in any ticket. Per
CLAUDE.md's own rule — *"a feature that needs a decision raises a ticket rather than making
one"* — this candidate cannot simply be **written** the way Candidates A and B can: whether
`gen_statem` is exposed to a beam-sharp author at all is an undecided design question this exemplar
would be inventing an answer to, not testing one, which is the exact failure mode ticket 25's own
2026-08-13 correction (the `admit.bs` ladder) already burned once and named explicitly: *"the
exemplar has… constructed a shape to answer [a] question rather than writing the workload honestly
and reporting what it demanded."*

---

## 3. Sub-decision: exemplar directory/module naming (the F15 gap ticket 25 explicitly left open)

`compiler/examples/exemplars/FRONTIER` records, measured, that **every** written exemplar's front
wall or a wall directly behind it is a naming problem, not a language gap: 25d stops on "this
directory holds `.bs` files and no `module` line"; 25e stops on `` `module Shop.Page` does not
match its directory `` (its directory is `25e-dynamic-web-page/`). Ticket 25's own 2026-08-17 note
says fixing this "is also choosing the exemplars' module names, which is a decision this note
deliberately does not make." It still hasn't been made.

### Candidate A — one shared `Shop.*` umbrella

`Shop/Api`, `Shop/Socket`, `Shop/Queue`, `Shop/Db`, `Shop/Page` — matches F15's own worked example
(`Shop/Orders/`) and the domain 25a–25d already `using Shop.Orders`.

**Evidence:** 25e already half-attempted exactly this — its `index.bs` literally declares
`module Shop.Page`, and `FRONTIER`'s recorded error is only the directory mismatch, not the module
name. This candidate is the smallest textual diff: rename five directories, change nothing else.

**Counterargument, as fact:** an HTTP gateway, a WebSocket protocol handler, an AMQP consumer and a
page renderer are not sub-modules of one aggregate in any real deployment, and ticket 22's own
resolution is that the DDD/aggregate shape must not be assumed to fit every exemplar — that
assumption is the premise ticket 25 was raised to break in the first place. Filing all five under
one `Shop` namespace re-imports it at zero build cost, which is exactly the kind of thing that goes
unnoticed for a week per this repo's own pattern (F15's suffix-match rejection, 25e's stale table).

### Candidate B — five independent top-level domains

`Api`, `Socket`, `Queue`, `Db`, `Page` — single-segment modules, no shared parent, matching each
exemplar's actual unrelated deployment.

**Evidence:** legal under F15 as written — its own worked example shows `Shop` itself holding no
`.bs` files and being a bare namespace, so a single-segment module with no parent at all is not a
new case, just an unused one.

**Counterargument, as fact:** F15/F11 built directory-as-namespace *nesting* — a parent directory
with no `.bs` files, children beneath it. Under this candidate every one of the five exemplars is
exactly one directory deep, so **zero of the five would ever demonstrate the nested case F15 was
built for.** The feature and its only real-world exercise would remain permanently disjoint.

### Candidate C — rename only the generated tree, leave the write-ups' filenames alone

Keep `wayfinder/prototypes/25a-http-api-server.md` exactly as named (readers and every
cross-reference in this ticket use "25a"); add a mapping table to `extract-exemplars.sh` and
`FRONTIER` from ticket-slug to real module path, and rename only
`compiler/examples/exemplars/<dir>`.

**Evidence:** `extract-exemplars.sh`'s own header comment already establishes the extracted tree as
"the compiler's target… not its test suite" — i.e., already licensed to diverge mechanically from
the prototypes' presentation.

**Counterargument, as fact:** this does not answer the question it looks like it answers. The
`index.bs` code block **inside the prototype's own prose** — what a reader copies — still needs a
real `module` line to compile as shown, and 25e already put one there directly
(`module Shop.Page`). A mapping-file-only fix leaves the prototype text and the mapping able to
disagree, which is the identical failure this ticket already measured and named once, in its own
words: *"the two artifacts silently disagreed until this was checked"* (result 3, the WebSocket
reserved-opcode finding).

---

## 4. What is *not* an open sub-decision, checked rather than assumed

Whether "standing resource" means versioned alongside tickets, or written once, reads like a fourth
sub-decision but is not one — it has already been settled **by conduct**, repeatedly, not by a
sentence: the ticket file carries eleven dated `RESULTS`/correction blocks between 2026-08-13 and
2026-08-26, two of them corrections made *in place* to earlier sections of the same ticket
(the ticket-12 residual claim, corrected 2026-08-24; the vacuous-clause-twin timeline, corrected
2026-09-02). That is the versioned-alongside-tickets behaviour, already in evidence, not a candidate
to choose between.

---

## 5. Independent re-verification

No `Agent`/`Task`-spawning tool was available in this session (checked the full top-level tool set
and `ToolSearch` for `Agent`, `Task`, `LaunchAgent`, `SpawnAgent`, `BackgroundAgent` — none exist
here). In its place: every probe above was rewritten from scratch in a clean directory
(`independent_reverify/`), with different module names, different variable names, different crash
triggers/ordering, and in Candidate C's case a different scenario (lock/read vs. coin/turnstile)
expressing the same claim. All three reproduced:

- `sup_check.erl`: `before=4 after=4`, `tries_for_7=[{7,2}]` — the crashing worker really was
  restarted once, not just reported as such.
- `statem_check.erl`: `{error,closed}` then `{ok,none}` for the same call in two different states.
- `scatter_check.erl`: `ok` / `crashed` / `timeout` for three genuinely different task bodies (a
  fast return, a real `error(kaboom)`, and a real 9999 ms sleep against a 250 ms deadline).

No probe was found to be circular — none of the three encoded its own expected answer as a literal
independent of the mechanism under test; each answer came from real OTP behaviour (a supervisor
callback firing, a `state_functions` dispatch, a `'DOWN'` message) that the rewritten version could
not have inherited from the original script.

---

*This audit changed no ticket status and no Linear state beyond one comment on ENG-191.*
