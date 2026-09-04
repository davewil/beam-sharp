# Independent verification — ticket 25's sixth exemplar decision brief

Adversarial audit of `artifacts/25-exemplar-programs-decision-brief.md` against a freshly built
`bsc` (`cd compiler && rebar3 compile && rebar3 escriptize`, escript at
`compiler/_build/default/bin/bsc`) and real BEAM (Erlang/OTP 25.3.2, erts-13.2.2.5 — same runtime
the brief used; OTP 28 remains unavailable in this environment too, so that caveat is unchanged).
Every probe below was written from scratch in a scratch directory outside `artifacts/`, not by
re-running the brief's own scripts, except where noted.

This file does not edit the brief or its artifacts, and touches no `wayfinder/`, git, or
`compiler/src/` state.

## Claim-by-claim

### 1. Candidate B compiles clean, exit 0, no scratch-copy workaround

**CONFIRMED.** Built `bsc` fresh, then ran it directly against the repo path (no copying):
`bsc -o <scratch>/out artifacts/25-exemplar-programs/probes/candidates/BatchReduce` → `exit=0`.
Same for `Worker` and `WorkerPool` (Candidate A), each `exit=0`, matching
`compile_transcripts.txt`.

### 2. Candidate B runs correctly and deterministically: `Reduce([1..5]) = 55`

**CONFIRMED, and more thoroughly than the transcript.** Wrote an independent Erlang driver
(`my_run_batch.erl`, not derived from `run_batch.erl`) that starts a fresh `BatchReduce`
coordinator and calls `Reduce` 10 times on `[1..5]` and 10 times on `[]`, plus once on `[1..200]`.
All 10 `[1..5]` runs returned `55`, all 10 `[]` runs returned `0`, and `[1..200]` returned
`2686700`, matching `sum(x*x for x in 1..200)` computed independently. Deterministic across every
repeat.

### 3. Candidate A compiles and runs: `Submit results = [1,4,9,16,25]`

**CONFIRMED.** Independent driver (`my_run_pool.erl`) against freshly compiled `Worker.beam` /
`WorkerPool.beam`: `Submit results = [1,4,9,16,25]`, exact match.

### 4. The double-DOWN signal claim (sharpest claim #1)

**CONFIRMED — real, standard BEAM behaviour, not a probe artifact.** Wrote an independent probe
(`my_down_probe.erl`, different structure and message shapes from `spawn_monitor_probe.erl`, not
a re-run of it) with three scenarios, each repeated 500 times:

- **Scenario A** (`spawn_monitor/1`, worker sends a result message then exits normally): **500/500**
  runs delivered *both* the result message and a `'DOWN'` with `reason = normal`. Zero anomalies.
- **Scenario B** (plain `spawn/1`, then a *separate*, later `erlang:monitor/2` call, with the
  worker's trivial body having already run to completion): **500/500** runs delivered `'DOWN'`
  with `reason = noproc`, **0/500** with `normal`. Zero anomalies.
- **Scenario C** (control: monitor established *before* the target can exit): **500/500** delivered
  `reason = normal`, confirming the reason genuinely tracks exit-vs-already-gone rather than being
  some other artifact of timing.

This is documented, standard `erlang:monitor/2` semantics (a `'DOWN'` fires for a normal exit same
as any other, and monitoring an already-dead process yields `noproc` — not something that needs
OTP 28 to differ). The brief's claim holds at 500/500 with an independently written probe.

**Load-bearing check beyond the brief's own claim:** to rule out this being a manufactured
narrative, I copied `BatchReduce` to a scratch module (`BatchReduceBuggy`) and removed exactly the
`reason =:= normal` special-case from `HandleInfo` (the "naive" first-draft shape the brief
describes). Compiled clean, then ran it 10 times: it returned **14** instead of **55** on
`[1..5]` (finishing after only 2 of 5 casts, on the first coincidental double-signal to zero out
`Pending`), and subsequent runs threw a live `function_clause` crash in `gen:reply/2` because
`Finish` had already replied and reset `From` to `:none` before the real cast total arrived. This
is a genuine, reproducible, load-bearing correctness bug that a naive `handle_info` hits — not a
dressed-up non-issue.

### 5. The residual-checking loophole claim (sharpest claim #2)

**CONFIRMED independently**, with a wholly separate probe (different type name `Signal` vs `Ev`,
different atoms, different function name `Classify` vs `F`, different unused-variable name
`unused` vs `x`, in a fresh directory pair under scratch, not copied from
`residual_bound_var_loophole_probe.sh`):

- `Classify(:red) -> :stop; Classify(:green) -> :go; Classify(unused) -> :other` (closed residual
  `{:blue, :yellow}`, `unused` never read) — **exit 0**, and `-v` shows no warning of any kind, not
  even at increased verbosity.
- Identical program with `Classify(_) -> :other` in place of `Classify(unused) -> :other`) —
  **exit 1**, `"error: Classify discards cases the compiler can name"`, naming `:blue` and
  `:yellow` exactly.

The asymmetry is real: an unused bound-variable catch-all over a closed residual is silently
accepted while `_` over the identical residual is refused, with zero diagnostic difference in
verbosity mode. Note (not a flaw in the brief, worth restating for the record): `checked.bs`'s own
`Checked(n, state) -> Accumulate(n, state)` does **not** itself exploit this loophole — `n` is
read, not discarded — exactly as the brief says. The loophole is a separate, deliberately
constructed test, not something latent in Candidate B's working code.

### 6. Candidate C: `!` has no grammar production, `receive` lexes as an identifier

**CONFIRMED as a parsing fact; FLAGGED as to how "undocumented"/"surprising" the `!` half really
is** (see below). Independently:

- `grep -n receive\|spawn\|monitor\|behaviour\|GenServer compiler/src/bs_lexer.xrl` shows only
  `behaviour`/`behavior` as lexed keywords; `receive`, `spawn`, `monitor`, `pid` are absent.
- `bs_parser.yrl`'s `Terminals` block has no `'!'`, `'receive'`, `'spawn'`, `'monitor'`, `'pid'`
  token — confirmed by reading the block directly (`'->' '=>' '==' '!=' '<=' '>=' '<<' '<' '>' '+'
  '-' '*' '/' '%' ...`, no bare `!`).
- Compiled the exact `OneShotFuture` probe fresh: `awaited.bs:6: error: syntax error before: '('`,
  `exit=1`, matching the transcript.
- Isolated the two constructs myself in fresh files with different module/function names
  (`MySendOnly`/`Ping`, `MyReceiveOnly`/`Wait`, not copied from `SendOnly`/`ReceiveOnly`): got the
  **identical** error text for both — `"beam-sharp has no \`!\`\n  negation is not an operator
  here..."` and `"Wait uses receive, which nothing binds\n  a name comes from a clause head or a
  binding above it."` This rules out the specific probe files being a fluke; the errors are
  produced by the general mechanism, not something peculiar to those files.

**FLAG — the "not documented as a gap anywhere in `LANGUAGE.md` or the tickets" framing is
inaccurate.** The error text itself (`beam-sharp has no \`!\``, "negation is not an operator
here") is the exact, ticket-63/F27 diagnostic (`bs_diag.erl:1035`, tag `no_negation`) for a fully
decided, **shipped** feature: LANGUAGE.md states outright, "**There is no `not`, and no `!`**...
**shipped**", with its own resolved ticket (`wayfinder/issues/63-negation-has-no-spelling.md`,
also indexed in `decisions.md`). Separately, ticket 14 §1 *already* discusses "raw `!` from
Erlang" by name, arguing typed pids wouldn't help because "raw `!` from Erlang goes through
regardless" — i.e., ticket 14 already treats bare `!` as something beam-sharp code does not write,
with the client-API-wrapper idiom (exactly what Candidate A does) offered as the replacement:
*"Nobody writes `Pid ! {apply, Id, E}` in OTP; they call `orders:apply(Server, Id, E)`."* So the
underlying fact — beam-sharp has no send operator, full stop — is real and the compile failure is
real, but describing it as *undocumented*, discovered "only by trying to write it," overstates the
surprise: a `grep '!'` over `LANGUAGE.md` (which the brief's own opening claims tickets 14/15 were
fully digested from) would have surfaced the exact diagnostic text before ever running `bsc`. This
does not undermine the core finding that Candidate C's literal program does not parse — that part
is solid — but the framing of it as a fresh, unrecorded gap is overstated. The `receive`-as-plain-
identifier half of the claim does **not** have this problem: LANGUAGE.md marks `receive` "decided"
without a "shipped" tag, correctly matching what the brief calls "decided-but-unbuilt," and I could
find no ticket claiming `receive` is implemented.

### 7. The `pid` builtin-type claim

**CONFIRMED, both halves, independently.**
- Compiler: `grep -n "not a builtin type" compiler/src/bs_diag.erl` → line 1095, and an independent
  fresh probe (`public pid Who() -> ...`) reproduces `"error: pid is not a builtin type\n  this
  slice has \`int\`, \`atom\`, \`term\`, \`bool\`, \`binary\`,\n  \`string\` and \`list<T>\`."`
  exactly, exit 1.
- LANGUAGE.md §13 ("Processes") reads verbatim: *"There is no typed `Pid<T>` — a process identifier
  is a `pid`, and the message type belongs on the client API function's signature..."* — so the
  noun "a `pid`" genuinely has no compiler-accepted surface referent, exactly as claimed.

### 8. Supporting citations spot-checked

- `decisions.md` line ~589: *"every async operation owes a synchronous observation in the same
  client API"* — **CONFIRMED**, exact phrase present.
- 25d's finding 3, *"`term` poisons every union it joins"* — **CONFIRMED** present in both
  `wayfinder/issues/25-exemplar-programs.md:521` and `wayfinder/prototypes/25d-database-querying.md:507`,
  and Candidate B's own `HandleCast`/`Checked` genuinely route a `term` through `ValidateAs<int>`
  before use, consistent with the claim.
- Searched `wayfinder/` for any prior recording of the double-DOWN / noproc-vs-normal distinction
  (`grep -rl "spawn_monitor\|'DOWN'"`) — hits exist (`14g_handle_info_blind_spot.erl`,
  `06-interop-surface.md`, etc.) but none discuss the double-signal-on-success or
  noproc-vs-normal distinction specifically. The "nothing in `wayfinder/` had measured this
  before" claim is consistent with what's on record.

## Circularity verdict

**No circularity found; the two sharpest findings look organically discovered, not tuned to
order.** Reasoning:

- All of `artifacts/25-exemplar-programs/probes/` landed in a single commit
  (`4192075`), so git history cannot show iteration — I instead tested the claims' *substance*
  rather than relying on a paper trail.
- The residual loophole is demonstrably **not** back-fitted into Candidate B: `checked.bs` uses a
  bound variable (`n`) that is genuinely read, not a dead unused one — the brief says this
  outright, and it is easy to check independently (§5 above). The loophole was tested via a
  minimal, separate probe with invented types, unrelated to BatchReduce's own domain — the shape
  of an incidental discovery ("why is this legal"), not a manufactured example.
- The double-DOWN finding is not a rhetorical flourish: I independently reproduced the exact
  documented BEAM semantics 500/500 across three scenarios with a probe of different construction,
  **and** confirmed by direct experiment that removing the fix from a copy of `BatchReduce`
  produces a genuine wrong-answer-then-crash failure (14 instead of 55, then live
  `function_clause` crashes) rather than a cosmetic issue. A brief trying to manufacture drama
  would not need to show a fix that actually matters this much — the bug is real and the fix in
  the final source is exactly what's needed.
- The one place inflation *did* show up is not in Candidate B at all, but in Candidate C's `!`
  framing (§6): calling a fully documented, shipped, ticket-cited refusal "not documented as a gap
  anywhere" is the kind of overstatement that adversarial review exists to catch, and it is
  flagged above. It does not touch Candidate B's two headline findings.

## Overall confidence: **HIGH**

The two things that most inform this rating:

1. Every load-bearing, testable claim about Candidate B — compiles clean, runs correctly and
   deterministically, the double-DOWN signal, the residual loophole, and (going beyond what the
   brief itself checked) the double-DOWN fix being genuinely load-bearing — reproduced exactly
   under my own independently written probes, in a different environment setup, with zero
   discrepancies across roughly 1,000+ repeated trials total.
2. The one flaw found (Candidate C's `!` "undocumented gap" framing) is a real overclaim, but it
   is scoped narrowly to Candidate C, which the brief itself does not recommend and treats as "a
   measurement... worth recording once" rather than load-bearing evidence for the recommendation.
   It does not touch Candidate B, the two sharpest claims, or the recommendation itself, which is
   why it lowers confidence in one paragraph rather than the whole document.
