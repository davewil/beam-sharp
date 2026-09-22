# Decision brief — ticket 25, the sixth exemplar: async processing

Research only. Ticket 25 stays `open`; nothing in `wayfinder/issues/` was edited. This is evidence
for David to read before the exemplar is written, not the exemplar itself.

## 0. What is settled going in

Both prerequisite tickets are resolved and bind the async exemplar tightly:

- **Ticket 14** (concurrency/OTP): no `async`/`await`/`Task`; the vocabulary is bare `spawn`/
  `send`/`receive` plus OTP behaviours; `pid` is untyped; `receive` is a filter exempt from
  exhaustiveness; `monitor`+`receive` is how a caller observes a remote crash as a value.
- **Ticket 15** (error model): remote failure is converted to a value by `monitor`+`receive`
  (measured strictly better than `try`, [`15c`](../wayfinder/prototypes/15c_surviving_a_callee_crash.erl));
  local foreign throws get a compiler-emitted wrapper into `foreign_error`; there is **no `try`
  in the surface**.

Ticket 25's own closing note (2026-08-26) is explicit about shape: **not a sixth `gen_server`** —
it is the only remaining exemplar with *neither* a long-lived server *nor* a wire format, which
all five written exemplars had.

## 1. The headline finding: every concurrency primitive ticket 14 decided is unbuilt in `bsc`

This is the load-bearing fact for the whole brief, and it was not assumed — it was compiled.
Working `bsc` built clean from this session's OTP 28.5 (`rebar3 escriptize`,
`_build/default/bin/bsc`), against a scratch copy of `compiler/` at `/tmp/ticket25-scratch/`.
Every probe below is archived at `artifacts/_probes/25/` (`.txt` transcripts,
`sources/` the `.bs`/`.erl` tried).

| Primitive | Ticket 14's decision | `bsc` today | Probe |
|---|---|---|---|
| `pid` as a type | §1 — untyped, bare `pid` | **`error: pid is not a builtin type`** — the type slice lists `int, float, atom, term, none, bool, binary, string, list<T>` and stops | `probe2_spawn_keyword.txt` |
| `receive { … }` | §5 — a clause-headed filter expression, exempt from exhaustiveness | **`error: syntax error before: '('`** — not a grammar production at all | `probe3_receive_keyword.txt` |
| `spawn(...)` | §2/§3 — the explicit alternative to `async`/`Task` | **Lexes as an ordinary lowercase identifier**, rejected only as an unbound name (`Go uses spawn, which nothing binds`) — i.e. no special casing exists, it just isn't declared anywhere | `probe8_spawn_as_call.txt` |
| `target ! msg` (send) | Implied by "explicit `spawn`/`send`/`receive`" in ticket 14's own question, never re-affirmed as a spelling in the resolution | **`error: beam-sharp has no !`** — `!` is retired to negation/comparison vocabulary (`!=`), so the obvious Erlang/Gleam spelling for send is a different token's job in this grammar | `probe4_send.txt` |
| `Monitor(...)` | §6 — "calling `Monitor` in an aggregate that handles no `Down` is an error"; presented as a compiler-known call | **`error: Watch calls Monitor/1, which nothing declares`** — same as any undeclared function; no compiler-known binding exists | `probe5_monitor.txt` |
| `Down`/`Exit`/`Timeout` types | §6 — stratum-2 compiler-known types, alongside `foreign_error` | Not found anywhere in `compiler/src/*.erl` (`grep -i 'down\|exit\|timeout'` on `bs_otp.erl`: no matches) | (grep, not a compile probe) |

By contrast, `grep -rn "receive\|spawn\|monitor" compiler/src/bs_parser.yrl` turns up **zero**
grammar rules — the two hits are English words inside comments. `bs_process.erl`, the only
`*_process.erl` file in the tree, is compiler-internal plumbing for shelling out to `/bin/sh`
during `bsc`'s own test harness; it has nothing to do with the B# language surface.

**What *is* built, for contrast**, is the OTP-callback naming layer, F10 (`compiler/features/F10-otp-callbacks.md`,
`Status: done 2026-08-15`): `behaviour GenServer`/`Supervisor`/etc., the four-site renaming
(`Init`→`init`, `HandleCall`→`handle_call`, …), and mandatory-callback presence checking. Probe 6
confirms a `behaviour GenServer` coordinator shell — `Init`/`HandleCall`/`HandleCast` with the
mandatory catch-alls ticket 12 requires — compiles clean today (`probe6_genserver_pool.txt`, exit
0). LANGUAGE.md §13 itself marks this **"partly shipped"** (presence checked, containment-typing
not) and separately marks `pid`/`receive`/no-`async` as **"decided"** with no "shipped" tag —
the source I compiled agrees with the source I read.

**Consequence for the exemplar**: this is the first of the six where writing the `.bs` source
honestly and then hand-writing a lowering (the format all five prior exemplars used) will produce
a source file that `bsc` refuses on essentially its *first* construct, not several files in, as
25a–25c did. `check-exemplar-frontier.sh`'s wall for this exemplar will read close to
`<first file>:<first spawn/receive line>` — worth flagging to whoever writes it up, so it isn't
mistaken for a defect in the write-up the way 25c's own front wall was briefly misrecorded (25c
§"the residual does not scale").

**A second, sharper finding hiding inside the first one**: ticket 14 decided the *model*
(`spawn`/`send`/`receive` exist, `pid` is untyped) but never re-decided their *surface spelling*
at the point of resolution — its own §2 says "explicit `spawn`/`send`/`receive`" only in the
*question*, and the six numbered answers never commit to `spawn(...)` as a function call, `!` as
the send token, or `Monitor(pid)` as the call shape. Probe 4 shows `!` is actively unavailable
(claimed by negation), so **the async exemplar cannot merely "use" ticket 14's vocabulary — it has
to invent the missing spellings**, which is exactly the kind of decision CLAUDE.md says belongs in
a ticket rather than an exemplar's write-up. This is this brief's strongest single recommendation
to David: **either raise that as a new ticket before the exemplar is written, or accept that the
exemplar's write-up will itself be doing minor language design** (as 25b's opcode/`_` finding and
25e's `Iodata` wall both ended up doing) and flag it the same way those did.

## 2. Three candidate programs, grounded in what 14/15 actually decided

### Candidate A — fan-out/collect: N independent fetches, gathered by the caller

```
result<list<int>, term> FetchAll(list<int> ids)
FetchAll(ids) -> // spawn one worker per id, each Send()s (:result, id, Fetch(id))
                 // or monitor+receive (:down, ...) on a crash — ticket 15 §4 case 3
```

The C#-reflex program this replaces is `Task.WhenAll`. It has no long-lived process and no wire
format — the exact shape ticket 25's closing note asks for — and it is the most direct test of
ticket 14 §2's central claim (no `Task`, explicit primitives instead) and ticket 15 §4's case 3
(`monitor`+`receive` beats `try` for remote failure, measured strictly better in `15c`).

**What it exercises**: `spawn`, a send spelling, `receive`/`monitor` together, `pid`-as-untyped
(§1's client-API-carries-the-type claim), and the escalation function `Unwrap<T,E>` from ticket
15 §3 if any worker's result is folded through `result<T,E>`.

**What it risks**: per §1 above, *every one* of those primitives is unbuilt. This candidate is
100% design-and-hand-lower, same as 25a–25e were for their showcase constructs, but with a larger
fraction of the file unbuildable than any prior exemplar. It is also the candidate most exposed to
the spelling gap just found (§1, last paragraph) — a fan-out cannot be written without first
choosing how `Send` is spelled, and no ticket has chosen it.

**Strongest counterargument**: it invents surface syntax the way ticket 25's own framing says
exemplars should *not* — "most valuable written after the ticket it exercises has a candidate
answer, so it tests something rather than inventing it." Ticket 14 gives a *model*, not a surface
grammar for `spawn`/`send`/`monitor`; writing this exemplar means either inventing that grammar in
the write-up (as 25b did for the opcode-`_` question, and 25e did for `Iodata`) or leaving three
undecided blanks in the showcase file, which is worse than either of the prior two gaps because
those were single findings and this would be three compounding ones in the same 15-line function.

### Candidate B — a supervised worker pool processing a batch job

A `behaviour GenServer` (or `Supervisor` + workers) coordinator that starts children, tracks
`Pending`/`Done`, and replies to a status query — the "long-lived coordinator over ephemeral
workers" shape.

**What it exercises**: F10's OTP-callback machinery (proven, probe 6 compiles clean), ticket 14
§4's narrowed-callback containment check, ticket 14 §6's `Down` handling if the coordinator
monitors its children, and OTP child-spec-as-data (`{M,F,A}` in a map, blessed by ticket 11,
buildable per F33 `done 2026-09-04`).

**What it risks**: it is definitionally the shape ticket 25 says not to write. The coordinator is
a `gen_server` under a different name — probe 6's own file is, mechanically, a smaller cousin of
25a/25b/25c's `handle_call`/`handle_info` skeletons. **Strongest counterargument, and it is
decisive**: David's own framing in the ticket ("It should not be written as a sixth `gen_server`")
rules this out before any evidence is weighed. Recorded here only because the prompt asked for it
to be grounded and risk-assessed, not because it is live.

### Candidate C — a producer/consumer pipeline with backpressure, no persistent server

A `receive`-driven loop (ticket 14 §5's "non-OTP process" case, explicitly named as legitimate)
that pulls from an in-memory queue, processes with bounded concurrency, and exits when the batch
drains — structurally close to 25c's `HandleInfo` back-pressure finding but **without** the
`behaviour GenServer` wrapper or AMQP wire format that made 25c a long-lived server with a
protocol.

**What it exercises**: `receive` as a bare filter outside any OTP callback (the one case ticket 14
§5 names as testing something 25a–25e never did — every prior exemplar's `receive`/`handle_info`
sat inside a `behaviour`), plus the same undecided `spawn`/`send` spellings as Candidate A.

**What it risks**: it is the least distinct from what 25c already measured. 25c's own
`handle_info.bs` finding ("a process can time out with a non-empty mailbox... unmatched messages
accumulate invisibly") and its back-pressure section already cover mailbox-growth-under-load for
a `receive`-driven consumer; a bare-process version repeats that finding in a thinner program
rather than a new one. **Strongest counterargument**: lower marginal value than Candidate A —
25c already paid for the mailbox/back-pressure insight inside a wire-format exemplar, so a
wire-format-free rerun mostly re-derives §5's "receive is a filter, not dispatch" point that
LANGUAGE.md already states as decided, without exercising anything 14/15 left more open than
Candidate A does (send/monitor spelling, `Unwrap` escalation, the untyped-`pid` claim under an
actual fan-out).

## 3. Minimal fragment compiled against `bsc` — full results

Six fragments were written and run against the freshly built `bsc` (OTP 28.5, scratch copy of
`compiler/`, never the tracked tree):

1. `pid Go(int id) -> spawn(() => id * 2)` → `pid is not a builtin type`.
2. `receive { (:reply, n) -> n }` → `syntax error before: '('` (not a grammar production).
3. `target ! (:reply, n)` → `beam-sharp has no !`.
4. `Watch(target) -> Monitor(target)` → `calls Monitor/1, which nothing declares`.
5. `spawn(id)` alone (isolating the token from the `pid` type error) → lexes as a bare identifier,
   rejected only as unbound — confirming no special-casing exists anywhere in the grammar or
   checker.
6. A `behaviour GenServer` coordinator shell (`Init`/`HandleCall`/`HandleCast`, with the mandatory
   catch-alls ticket 12 requires) → **compiles clean, exit 0** — the one piece of OTP concurrency
   machinery that is actually built.

Full transcripts and every `.bs` source tried: `artifacts/_probes/25/*.txt` and
`artifacts/_probes/25/sources/`.

## 4. Measured: bare spawn vs gen_server-started process, OTP 28.5

Run via a plain-Erlang probe (`artifacts/_probes/25/sources/probe7_overhead.erl`) against this
session's freshly built OTP 28.5 `erl` — not `bsc`, since the question is BEAM process cost and
does not need the B# compiler. 1000 processes per trial, `erlang:process_info/2` averaged:

| Pattern | Per-process memory (bytes) | Avg heap_size (words) | Delta vs bare |
|---|---|---|---|
| Bare `spawn`, parked in `receive` | 2624.0 | 233.0 | — |
| `gen_server:start_link` (minimal callback module) | 2760.0 | 233.0 | **+136 bytes/process (+5.2%)** |

Fan-out/collect throughput (bare `spawn`, no supervision, 1000/10000 short-lived workers each
sending one message back to the parent and exiting):

| N | Wall time | Per-task | Notes |
|---|---|---|---|
| 1,000 | 9.81 ms | 9.81 µs/task | |
| 10,000 | 124.9 ms | 12.49 µs/task | roughly linear, mild scheduler overhead at 10x |

**Reading it for the supervised-pool-vs-bare-spawn question**: the memory delta between a
gen_server wrapper and a bare process is small (~5%, same heap_size — the extra bytes are the
`gen_server`/`proc_lib`/`sys` loop state, not extra heap) and is not the deciding factor either
way. It is dwarfed by the fact (§1) that **the compiler cannot emit `spawn` for a bare process at
all today**, so "bare spawn is cheaper" is currently true only as a BEAM-level fact, not as
something the exemplar could demonstrate compiling. If Candidate A is chosen, the honest framing
is "here is what BEAM costs for this pattern," identical in spirit to 25d's live-captured
PostgreSQL rows — evidence from the platform, not from `bsc`.

## 5. Recommendation

**Candidate A (fan-out/collect over bare `spawn`+`monitor`+`receive`)**, written the way 25a–25e
were: honest `.bs` source including the awkward parts, a hand-written Erlang lowering that
actually runs (per the ticket's non-negotiable requirement), and a friction list. Grounds:

- It is the only candidate that matches ticket 25's own stated shape constraint (no long-lived
  server, no wire format) without qualification — Candidate B fails that constraint outright and
  Candidate C only partly avoids it.
- It is the sharpest test of ticket 14/15's actual content: untyped `pid` (§1), no `Task` (§2),
  `monitor`+`receive` beating `try` for remote failure (15 §4 case 3, the ticket's own
  strongest-measured finding), and the `Unwrap<T,E>` escalation pattern (15 §3) all have a natural
  place in this program and none in Candidate C.
- Its main risk — that essentially nothing about it compiles today (§1, §3) — is not a reason to
  avoid it; it is itself the finding worth recording, and it is a *cleaner* finding than any prior
  exemplar's wall, because it traces to an absent surface grammar rather than an absent library
  function. It also surfaces a real gap upstream of the exemplar: **`spawn`/`send`/`monitor` have
  a decided model (ticket 14) but no decided spelling**, and whoever writes this exemplar will
  either invent one in the write-up or should have a short ticket settle it first — David's call,
  flagged here per CLAUDE.md's "never write 'not decided' without checking" rule (this was
  checked: ticket 14's resolution text does not commit to a spelling; only its restated *question*
  uses the words `spawn`/`send`/`receive` at all).
- The per-process overhead numbers (§4) argue against treating "supervised pool" and "bare spawn"
  as a cost trade-off at all — the memory difference is ~5% and irrelevant next to the fact that
  neither compiles yet. Frame the exemplar's honest finding as: BEAM overhead is not what should
  decide this, buildability is.

## 6. Probes-run appendix

All under `artifacts/_probes/25/`:

- `probe1_baseline.txt` — sanity check that the module/file-per-function machinery (F13/F15) works
  before testing anything concurrency-specific.
- `probe2_spawn_keyword.txt`, `probe3_receive_keyword.txt`, `probe4_send.txt`,
  `probe5_monitor.txt`, `probe8_spawn_as_call.txt` — the five primitive probes behind the table in
  §1.
- `probe6_genserver_pool.txt` — the one concurrency-adjacent thing that compiles (OTP-callback
  shell), included as the contrast case.
- `probe7_overhead_otp28.txt` — the process-cost measurement behind §4, with the Erlang source at
  `sources/probe7_overhead.erl`.
- `sources/` — every `.bs`/`.erl` file actually compiled or run, exactly as tried, so the table in
  §1 and §3 can be independently re-run.

**Environment used**: OTP 28.5 built at `/opt/otp28-src` this session (`BUILD_DONE` in
`/tmp/otp-build.log`); `bsc` built via `rebar3 escriptize` against a **scratch copy** of
`compiler/` at `/tmp/ticket25-scratch/compiler` (tracked tree never touched); escript at
`/tmp/ticket25-scratch/compiler/_build/default/bin/bsc`. No exemplar file was added under
`wayfinder/prototypes/`.
