# Decision brief — ticket 25's sixth exemplar: async processing

**Not a resolution.** This is research for David to read against
`wayfinder/issues/25-exemplar-programs.md`. Nothing here edits the ticket, `decisions.md`,
`map.md`, or Linear. All source, transcripts and probe output referenced below are under
[`artifacts/25-exemplar-programs/probes/`](25-exemplar-programs/probes/) in this repo, and every
claim of the form "compiles" or "runs" was executed against the real `bsc` built from this
checkout (`rebar3 escriptize`, on Erlang/OTP 25.3.2 — see the version caveat at the end) and real
BEAM, not read and assumed.

## What is actually still undecided

Tickets 14 (concurrency/OTP model) and 15 (error model) are both resolved, and between them they
already answered every *design* question an async exemplar could raise: no `async`/`await`/`Task`
(14 §2), `pid` is untyped and unparameterised (14 §1), `receive` is a decided-but-unbuilt filter
exempt from exhaustiveness (14 §5), process failure is `monitor` + `receive` (12 §5, LANGUAGE.md
§7/§11), and every async operation owes a synchronous observation in the same client API (ticket
24's testing-story finding, `decisions.md` line 589). So this exemplar cannot invent a decision —
ticket 25's own note is right about that. What is undecided is narrower and entirely the ticket's
own to answer, not David's:

1. **Which concrete B# program is exemplar #6.** Candidates below.
2. **What fresh evidence, if any, that program produces on ticket 12's standing empirical
   question** (how often a closed residual is deliberately closed with `_`, and does naming the
   cases read better or worse) — genuinely open, since neither prior finding (25b's WebSocket
   opcode, 25d's silence) involved concurrent fan-in.
3. **Whether writing it now is worth it**, given both tickets it was scoped to test are closed.

## The three candidates, as real code, compiled against the real `bsc`

### Candidate B — fan-out/fan-in map-reduce over a batch (recommended)

A `GenServer` coordinator spawns one process per item (`erlang:spawn_monitor/3` to a plain
exported top-level function — no lambda needed, so it does not hit the wall every other exemplar
hit), each worker computes and casts its result back, the coordinator gathers in `HandleCast` and
`HandleInfo`, and the client's `Reduce` call blocks synchronously until the batch settles or the
call times out. Full source:
[`probes/candidates/BatchReduce/`](25-exemplar-programs/probes/candidates/BatchReduce/) (13 files,
12 functions, 20 clauses, 72 lines). The two load-bearing files:

```csharp
// index.bs
module BatchReduce

behaviour GenServer

using :erlang {
    (term, term) spawn_monitor(atom m, atom f, list<term> args)
    term self()
}

using :gen_server {
    term call(term server, term request, int timeout)
    atom cast(term server, term msg)
    atom reply(term from, term reply)
}

record BatchState { Pending: int, Total: int, From: term }

type Item    = int
type Request = (:reduce, list<Item>)
type Reply   = (:reply, int, BatchState) | (:noreply, BatchState)
```

```csharp
// handle_info.bs — the fan-in's failure path, and where ticket 12 bites (see below)
public (:noreply, BatchState) HandleInfo(term msg, BatchState state)

HandleInfo((:'DOWN', _, :process, _, :normal), state)                 -> (:noreply, state)
HandleInfo((:'DOWN', _, :process, _, _), state) when state.Pending > 0 -> Accumulate(0, state)
HandleInfo((:'DOWN', _, :process, _, _), state)                       -> (:noreply, state)
HandleInfo(_, state)                                                  -> (:noreply, state)
```

**Compiles clean, `bsc` exit 0, no scratch-copy trick needed** — the only exemplar besides 25d to
reach that, and unlike 25d it needed no front-wall workaround at all
(`probes/compile_transcripts.txt`). **It runs and is correct**, measured against real OTP:

```
$ erl -noshell -pa out -s run_batch main
Reduce([1..5]) = 55        %% 1²+2²+3²+4²+5² = 55, repeated 3x, deterministic
Reduce([])     = 0
```
(`probes/run_transcripts.out`)

**What it cost to get there — three real bugs, not typos, each one evidence in its own right:**

- **First draft replied to the caller from the base case of the spawn loop**, not from the last
  worker's result — `gen_server:call` returned before any work was done. The fix is the standard
  OTP "deferred reply" idiom (`(:noreply, state)` from `HandleCall`, `:gen_server.reply/2` later),
  which this exemplar is the first in the set to need and which types cleanly once the `Reply`
  union covers both the immediate and deferred shapes.
- **A successful worker delivers *two* signals, not one — its own `cast` and, because it is
  monitored, a `'DOWN'` for its own normal exit — and a fan-in handler that does not special-case
  `reason =:= normal` double-counts.** Measured directly against OTP (not inferred):
  `probes/spawn_monitor_probe.erl` / `.out`, probe 2. **Worse: with `spawn` then a separate
  `monitor` call (not the atomic `spawn_monitor/3`), a worker that already exited before the
  monitor call lands still delivers a `'DOWN'`, but with reason `noproc`, not `normal`** (probe 1)
  — so a handler that only excludes `:normal` is still wrong under load; only the atomic
  `spawn_monitor/3` (used in the final source) collapses this to one reason space (`:normal` for
  every success, never `:noproc`), and even then the `:normal` exclusion is still required. **This
  is a real, load-dependent BEAM correctness hazard that nothing in `wayfinder/` had measured
  before**, and it is squarely inside what ticket 14 named "the OTP showcase" without writing.
- **`term poisons every union it joins` (25d's finding 3) reproduces a fourth time.** `HandleCast`
  and `HandleInfo` both receive `term` by OTP's own mandatory signature, so a worker's own `int`
  result arrives untyped at the coordinator and needs `ValidateAs<int>` before `Accumulate` (an
  `int`-typed helper) will take it — one more hand-written narrowing site this exemplar's own
  author did not expect going in.

**Ticket 12's question — this candidate is not silent on it, and it sharpens the question rather
than answering it the expected way.** `Checked` (the file discriminating `ValidateAs`'s
`int | (:error, ValidationError)`) uses a bound-variable fallthrough, not `_`:

```csharp
// checked.bs
Checked((:error, _), state) -> (:noreply, state)
Checked(n, state)           -> Accumulate(n, state)
```

That is legal and clean — `n` is used, not discarded. But probing *why* it is legal surfaced a
loophole ticket 12 §2's own wording does not cover: **`_` over a closed residual is refused; an
unused bound variable over the identical closed residual is silently accepted, with no warning at
all**, measured directly:

```
F(:a) -> :got_a
F(x)  -> :other      // closed residual {:b, :c} — ACCEPTED, exit 0, no diagnostic
F(_)  -> :other      // same residual — REFUSED: "F discards cases the compiler can name"
```
(`probes/residual_bound_var_loophole_probe.sh` / `.out`) This candidate's own code does not
exploit it (`n` is used), but the loophole means **ticket 12 §2's rule is enforced on one spelling
of "discard everything left" and not on an equally common one that reads almost identically** —
worth a line in 12 or 04 regardless of what happens to exemplar #6, and it is new evidence this
investigation produced rather than something already on the map.

### Candidate A — a pool of worker `GenServer`s, dispatched round-robin (compiles, not recommended)

Two modules, `Worker` (does the arithmetic) and `WorkerPool` (starts N workers via
`gen_server:start_link`, keeps them in a list, dispatches by popping and re-appending — real
round-robin needs a list-rotate the language has no operator for, since `List.At` does not exist
and `Fold`/`Map`/`Filter` wait on the lambda ticket 27 §(c) still owes). Full source:
[`probes/candidates/Worker/`](25-exemplar-programs/probes/candidates/Worker/),
[`probes/candidates/WorkerPool/`](25-exemplar-programs/probes/candidates/WorkerPool/) (9 functions,
12 clauses, 50 lines across both). **Also compiles clean and runs correctly**:

```
$ erl -noshell -pa out -s run_pool main
Submit results = [1,4,9,16,25]
```

**Why it is not the recommendation, even though it is cheaper and got there with fewer surprises:**
this is architecturally *"a sixth gen_server"* — the closing line of the RESULTS section already
on file for this ticket explicitly asks for the opposite: *"the only remaining shape with no
long-lived server and no wire format... should not be written as a sixth gen_server."* Every
worker here is itself a permanent `GenServer` instance living for the pool's whole lifetime; there
is no genuinely transient, fire-and-forget work anywhere in it. It is real evidence that the
GenServer-chain shape keeps compiling easily (a fourth data point that behaviour-based OTP code is
where this language is most finished), but it tests nothing this ticket does not already know.

### Candidate C — a one-shot future via bare `spawn` + `monitor` + `receive` (the ticket's own
literal wording; unwritable today)

The ticket text itself nominates this shape. Written as literally as the decided surface allows —
a plain, non-`GenServer` process that a caller spawns, monitors, and blocks on:

```csharp
// awaited.bs
public int Await(int item)

Await(item) ->
    var (worker, ref) = :erlang.spawn_monitor(:'OneShotFuture', :'Compute', [:erlang.self(), item])
    receive {
        (:result, worker, value)                    -> value
        (:'DOWN', ref, :process, worker, reason)     -> raise (:worker_failed, reason)
    }
```

```csharp
// compute.bs
public atom Compute(term caller, int item)

Compute(caller, item) -> caller ! (:result, :erlang.self(), item * item)
```

**Fails at the very first non-OTP primitive it touches, and fails twice over — not at `receive`
alone.** Isolated separately (`probes/compile_transcripts.txt`):

```
compute.bs:3: error: beam-sharp has no `!`
  negation is not an operator here. ...
```
```
awaited.bs: error: Start uses receive, which nothing binds
  a name comes from a clause head or a binding above it.
```

**`!` (raw send) does not exist in the grammar at all** — not documented as a gap anywhere in
`LANGUAGE.md` or the tickets, discovered only by trying to write it — and **`receive` is lexed as
an ordinary identifier**, matching what LANGUAGE.md §13 already says ("`receive` is a filter...
decided") but conspicuously never says is *built*, unlike the adjacent "shipped" callouts for
`behaviour GenServer` two paragraphs above it. Grepped directly against the grammar to confirm
neither is a gap in my reading: `grep -n "spawn\|monitor\|behaviour\|GenServer" bs_lexer.xrl`
shows `behaviour` lexed and nothing else process-related; `receive`/`spawn`/`monitor`/`!`/`pid` are
absent from `bs_parser.yrl`'s terminal list entirely. **The literal candidate the ticket names is
not a program that is awkward to write in beam-sharp today — it is not a program the compiler can
parse, on two separate constructs, neither of which is `receive` alone.**

One more small, related gap surfaces from the same probing and belongs on the record regardless of
which candidate is picked: **`pid` is not a builtin type.** LANGUAGE.md §13 says "a process
identifier is a `pid`"; `bsc` says `pid is not a builtin type — this slice has int, atom, term,
bool, binary, string and list<T>` (`probes/pid_type_gap_probe.out`). Every candidate above spells
a process identifier as `term`, which is consistent with the *rest* of §13 ("no typed `Pid<T>`")
but the specific noun "a `pid`" in the decided prose has no surface referent today.

## Recommendation

**Candidate B, the fan-out/fan-in batch, if exemplar #6 is written at all.** The tipping evidence
is not that it compiles clean (25d also does, once past a one-line front wall) — it is that **a
72-line program produced three genuine, previously-unrecorded findings** (the deferred-reply idiom
this set had not yet needed; the double-DOWN / `noproc`-vs-`normal` hazard, measured against real
OTP and not inferred; the `_`-vs-bound-variable residual loophole) **in addition to** confirming
`term poisons every union` a fourth time and giving ticket 12 a genuine, if inconclusive, second
data point (an author reaching for a bound-variable catch-all rather than `_`, which the rule as
written does not stop). Candidate A produces none of these — it is cheaper and safer precisely
because it stays inside territory four prior exemplars already proved solid. Candidate C is not
really a third option so much as a measurement that the ticket's own literal wording is currently
unimplementable, which is worth recording once and then not revisiting until `receive` and `!`
ship.

**On sub-question 3 (write it now, or leave the ticket at five-of-six):** this investigation is
itself evidence for "now." The premise that async processing "only tests, invents nothing" because
14 and 15 are resolved undersold what actually happened — Candidate B surfaced two compiler gaps
(`pid` unbuilt, the DOWN double-signal) and one enforcement loophole (§ above) that no prior
exemplar could have found, because none of the first five involved more than one process doing the
program's own work at a time. That is new ground, not confirmation of old ground, and it cost
about half a day of an agent's time against a compiler that already exists. The counter-argument is
real and should be stated plainly: none of what Candidate B found required the *ticket* to be
written up in the formal 25a–25e format (write-up + lowering + friction list) to be discovered —
it fell out of just compiling and running the code. If the bar is "is a full ticket-25f write-up
worth the additional overhead beyond what this brief already captured," that is a much closer
call, and reasonably David's to make rather than this brief's.

## What I could not verify

- **OTP 28 specifics.** Everything here ran on Erlang/OTP 25.3.2 (erts-13.2.2.5), per this
  environment; the project is pinned to 28.5, which could not be installed (github.com blocked).
  The `spawn_monitor` double-signal and `noproc`-vs-`normal` behaviour (`spawn_monitor_probe.erl`)
  is standard, long-stable BEAM process semantics and very unlikely to have changed, but I have not
  run it on 28 to confirm, and the exact microsecond cost in `probes/spawn_monitor_probe.out`
  (1.77 µs/round-trip) is JIT-generation-sensitive and should be treated as an OTP-25 number, not
  a claim about 28.
- **Elixir.** Elixir 1.14.0 (OTP 24) is installed; I did not write an Elixir-side probe for this
  ticket. The concurrency primitives probed (`spawn_monitor`, `gen_server:call`/`cast`/`reply`)
  are Erlang/OTP-level and Elixir-version-independent, so I judged a separate Elixir probe low
  value here, but did not run one to confirm that judgement.
- **Gleam.** Not installed, cannot be installed (no apt package, github.com blocked). I did not
  cite any Gleam concurrency behaviour in this brief; none of `wayfinder/prototypes/`'s existing
  Gleam observations (`14b_gleam_mailbox_probe.erl`, `14c_gleam_named_forgery.erl`,
  `14f_gleam_selective_receive.gleam`) are about fan-out/fan-in or supervised pools, so there was
  nothing on-topic to cite with provenance rather than fabricate.
- **A live worker crash mid-flight, under real timing.** Candidate B's `HandleInfo` crash path
  (a worker whose exit reason is not `:normal`) is verified by code review and by the type checker
  accepting the clause, and the *mechanism* it depends on (a monitored abnormal exit delivering a
  `'DOWN'` with a non-`:normal`, non-`:noproc` reason) is standard BEAM behaviour, but my test
  harness's attempt to kill a real spawned worker before it could finish its (near-instantaneous)
  computation did not win that race in this environment (`run_transcripts.out`, "crash path" line
  shows the full uncrashed sum, not a partial one) — so this one path is not confirmed by a
  successful live reproduction, only by static and type-level review.
- **Whether a formal 25f write-up (in the `wayfinder/prototypes/25*.md` format, with a hand
  lowering to Erlang alongside the `bsc`-compiled `.beam`) would surface further findings beyond
  what this brief's direct compile-and-run pass already found.** I did not produce that document;
  I produced compiled, running source and this brief. If David wants exemplar #6 formally written,
  Candidate B's source under `probes/candidates/BatchReduce/` is a working starting point but is
  not itself in the write-up format the other five follow (no prose walkthrough, no companion
  hand-written Erlang lowering distinct from what `bsc` emits).
