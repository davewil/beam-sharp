# Decision brief — ticket 39, emitted code quality

**Autonomous research. Not a decision. Ticket 39 / ENG-211 is left OPEN for David.**

Session: 2026-09-08/09. Nothing in `wayfinder/issues/39-emitted-code-quality.md`, its Linear
issue, or any ticket file was edited to produce this. This file lives at
`artifacts/39-emitted-code-quality-brief.md` and is not committed.

**Headline: re-measured today, on current `master` and this environment's OTP 25, the ticket's
central premise — a reproducible 20% gap — does not reproduce.** The hot-path bytecode
(`Wrap`/`Hit`/`Spin`, the three functions that run once per click, 673,364 times) disassembles
byte-for-byte identical to hand-written Erlang, JIT type annotations included, and the wall-clock
benchmark shows beam-sharp inside 1–3% of Erlang and Elixir across six independent runs. This
directly contradicts §1's "observed" claim that beam-sharp's operands "carry less type
information for the JIT" than Erlang's. See §2 for the actual numbers and why this is not the
same thing as "the gap is fixed forever."

---

## 0. Build note — this environment could not build `bsc` out of the box

Worth recording because it bears on how much to trust "current master" as a baseline. The
container's `erlang-parsetools` 25.3.2.8 package (Ubuntu noble) ships `leex.erl`/`yecc.erl` but
**not** their `include/leexinc.hrl` / `include/yeccpre.hrl` — `leex:file/1` fails outright, so no
`.xrl` in the repo, including `bs_lexer.xrl`, could be regenerated. Separately, OTP 25's `leex`
predates the `{error_location, column}` option `rebar.config`'s `xrl_opts` requires (it was added
in OTP 26) — so even with the headers restored, `bs_lexer.erl` came out missing the `TokenLoc`
binding every scanner rule references, and compilation failed with 114 `variable 'TokenLoc' is
unbound` errors.

Fixed by fetching OTP 26.0's `leex.erl` + `leexinc.hrl` from `raw.githubusercontent.com/erlang/otp`
(network egress to GitHub is allowed through this session's proxy), compiling `leex.erl` against
the local `stdlib`'s `erl_compile.hrl`, and installing the result as the system `leex.beam` so
both my manual regeneration and `rebar3`'s own build step picked it up. `rebar3` itself also had
to be fetched (not preinstalled) — the S3-hosted latest build is compiled for an OTP newer than 25
and fails to load (`Use of opcode 182; this emulator supports only up to 180`), so I used the
`3.22.1` GitHub release instead, which is OTP-25-compatible. None of this touches `bs_emit.erl`
(the actual code generator) or `bs_parser.yrl` (yecc needed no such patch) — only lexer-generation
tooling — so I don't believe it altered anything the ticket cares about, but it means "building
`bsc` here" is not yet a zero-friction path, which is a fact worth someone's attention independent
of ticket 39. After the patch: `rebar3 escriptize` is clean, `bsc examples/Fib 10` returns
`[0, 1, 1, 2, 3, 5, 8, 13, 21, 34]` as documented, and `./_build/default/bin/bsc` is the escript
used for every measurement below.

Gleam could not be installed (no network to its release host or crates.io, confirmed) and no
Gleam `.beam` artifact was checked into `aoc/bench/`. Every "Gleam" line below is from the
ticket's own 2026-08-15 record, not from anything I measured, and is marked as such.

---

## 1. What I actually measured, and how (§3's four settling questions, retaken)

### 1a. Is the emitted hot-path bytecode really instruction-identical? (§1's central claim, retested)

Built `aoc/bench/bench_erl.erl` with `erlc` and `aoc/bench/Day01/bench_bs.bs` with `bsc`, then
disassembled both `.beam` files with `beam_disasm:file/1` (OTP's own compiler-internal
disassembler, `compiler-8.2.6.3/src/beam_disasm.erl`) and diffed the instruction lists by eye
(full transcripts: `/tmp/disasm/bench_erl_full.txt`, `/tmp/disasm/day01_full.txt` — not preserved
past this session; reproducible with the commands in §4).

| function | called | Erlang instrs | beam-sharp instrs | identical? |
|---|---|---|---|---|
| `wrap/1` / `Wrap/1` | 673,364× | 8 | 8 | **yes, byte-for-byte, `{tr,...}` included** |
| `hit/1` / `Hit/1` | 673,364× | 10 | 10 | **yes, byte-for-byte, `{tr,...}` included** |
| `spin/4` / `Spin/4` | 673,364× | 26 | 26 | **yes, byte-for-byte, `{tr,...}` included** |
| `sign/1` / `Sign/1` | 4,732× | 13 | 10 | no — see below |
| `size_/1` / `Size/1` | 4,732× | 10 | 9 | no — see below |
| `clicks/3` / `Clicks/3` | 4,732× | 29 | 29 | yes |
| `part_two/1` / `PartTwo/1` | 1× | 7 | 7 | yes |

The three functions that dominate runtime are **identical down to the JIT type-range
annotation**. Example, `wrap/1` vs `'Wrap'/1`, complete function bodies, verbatim from the two
disassemblies:

```
{gc_bif,'rem',{f,0},1,[{tr,{x,0},{{t_integer,any},0,18446744073709551615}},{integer,100}],{x,0}}
{gc_bif,'+',  {f,0},1,[{tr,{x,0},{{t_integer,any},18446744073709551517,99}},{integer,100}],{x,0}}
{gc_bif,'rem',{f,0},1,[{tr,{x,0},{{t_integer,any},1,199}},{integer,100}],{x,0}}
```
— same three lines, same bounds, same register, in both `.beam` files. (The huge unsigned
integers are BEAM's wraparound encoding of small negative bounds: `18446744073709551517 =
2^64 - 99`.)

**This refutes §1's stated observation** — *"Erlang's loop has `{tr,{x,0},{t_integer,{0,99}}}`
where beam-sharp's has a bare `{x,0}`"* — as a description of the code this session built and
ran. Whatever produced that difference on 2026-08-15 either was fixed by a later commit to
`bs_emit.erl` (six commits have touched it since; none of their messages mention this specific
mechanism, so I can't name the one commit responsible without bisecting historical builds across
two OTP versions, which was out of scope for this session's budget) or was itself an artifact of
the OTP-28 toolchain the original measurement used, not of anything beam-sharp emits. §1c below
gives the mechanism that makes the second explanation plausible.

`sign`/`size_` differ, but not because of emitted-code quality: **`bench_erl.erl`'s `sign/1` has
three source clauses** (`sign(0)`, `sign(D) when D>0`, `sign(D) when D<0`) **while
`bench_bs.bs`'s `Sign` has two** (`d<0`, `d>=0` — the `0` case falls into `d>=0`). That is a
difference in the hand-transliterated source, not in what the compiler does with equivalent
source — and both functions run 4,732 times against `Spin`'s 673,364, so even a real per-call
delta here is worth roughly 0.006 ms out of a multi-millisecond run. I did not chase this further.

### 1b. Does the 20% gap still exist at all? (§3.1: "time the loop in isolation")

`aoc/bench/build.sh` calls `gleam build`, which isn't available here, so I wrote a
three-language variant of `bench.erl` (`bench3.erl`/`bench3b.erl`, diffed against the checked-in
original below) that drops only the Gleam line and nothing else. Same methodology as the
original: load all `.beam`s, call directly, check the answer, report min-of-N and median.

```
$ diff aoc/bench/bench.erl bench3.erl
1,12c1,3
< [fairness comment block] -module(bench).
---
> [one-line note this drops Gleam] -module(bench3).
23d13
<              {"Gleam",      fun bench_gleam:part_two/1},
46c36
<         [] -> io:format("~nall four agree on 6770~n");
---
>         [] -> io:format("~nall agree on 6770~n");
```

Six independent runs (three at `?RUNS = 25` in the checked-in order, three at `?RUNS = 51` with
the call order reversed — beam-sharp first — to rule out a warm-VM/JIT-warmup advantage for
whichever language runs first):

```
run (Erlang, Elixir, beam-sharp order; RUNS=25):
             answer      min ms    med ms      rel
Erlang       6770         17.79     18.01    1.03x
Elixir       6770         17.31     17.48    1.00x
beam-sharp   6770         17.50     17.88    1.01x
[×3, all within this spread]

run (beam-sharp, Elixir, Erlang order; RUNS=51):
             answer      min ms    med ms      rel
beam-sharp   6770         17.25–17.68   17.64–17.89   1.00–1.03x
Elixir       6770         17.19–17.21   17.33–17.38   1.00x
Erlang       6770         17.43–17.59   17.73–17.77   1.01–1.02x
[×3, all within this spread]
```

All 6 runs, both orderings: **beam-sharp is within 1–3% of Erlang and Elixir** — the same
cluster width the ticket itself used as "the harness is measuring something real" for the
original three. There is no 20% gap in this environment, today, on this build. (Absolute times
are ~17ms here vs. ~5-6ms in the ticket's Apple-Silicon numbers — this is a shared container, not
a performance claim; only the *relative* numbers are the finding.)

**I cannot rule out that this is OTP-version-dependent rather than compiler-version-dependent.**
This container has OTP 25.3.2.8 (`erts-13.2.2.5`); the ticket's original measurement was OTP 28 /
erts-16.4. I could not install OTP 28 here (no `kerl`/`asdf`, no precompiled package on the
reachable apt mirrors, and building OTP from source was outside this session's budget). §1c gives
a mechanistic reason the *compiler's own* success-typing pass — not the `-spec` — is what produces
the `{tr,...}` annotations, which argues for "the abstract-forms shape changed" over "OTP 28
infers more aggressively than OTP 25," but this is not something I measured directly and is the
single biggest open variable in this brief.

### 1c. Mechanism: why the `-spec` was always a red herring, with a citation

§1's spec-stripping experiment (widened `-spec` stripped, timing unmoved) is corroborated by
reading the actual pass that produces `{tr,...}`: `beam_ssa_type.erl` in this OTP's own
`compiler-8.2.6.3` application.

> `/usr/lib/erlang/lib/compiler-8.2.6.3/src/beam_ssa_type.erl:20–26`
> *"This pass infers types from expressions and attempts to simplify or remove subsequent
> instructions based on that information. This is divided into two subpasses; the first figures
> out function type signatures for the whole module without optimizing anything, and the second
> optimizes based on that information..."*

> `beam_ssa_type.erl:114–124`
> *"The initial signature analysis is based on the paper 'Practical Type Inference Based on
> Success Typings' by Tobias Lindahl and Konstantinos Sagonas... The general idea is to start out
> at the module's entry points and propagate types to the functions we call. The argument types
> of all exported functions start out at 'any', whereas local functions start at 'none'. Every
> time a function call widens the argument types, we analyze the callee again and propagate its
> return types to the callers..."*

This pass **never consults `-spec`**. It rebuilds argument/return types from scratch by
propagating from call sites through the SSA control-flow graph, starting local (unexported)
functions at the bottom type `none` and widening only as call sites demand it. `Wrap`/`wrap` and
`Hit`/`hit` are `private`/unexported in both source files, so both get the tightest possible
starting point and the same propagation regardless of what either module's `-spec` attribute
claims — which is exactly why stripping the `-spec` in §1's earlier experiment changed nothing,
and exactly why today's `Wrap`/`Spin` come out identical: the analysis run is a pure function of
the SSA graph shape, and where the two modules' abstract forms have the same shape (confirmed by
diffing `Day01.abstr` against `bench_erl.erl`'s structure — same operators, same clause
recursion), the inferred `{tr,...}` will be the same too. Confirming this: `Day01.abstr`'s
`-spec` for `Wrap/1` is **still** the widened `integer()`, not `0..99` — ticket 13's widening
rule is untouched — and it still makes no difference, because it was never in the causal chain.

### 1d. The still-open axis: records and dispatch (§3's closing note)

§3's last paragraph flags this as genuinely unmeasured: *"Neither workload touches a record, so
the boundary tag guard (ticket 18, F3) has never been measured at all."* I measured it.

`compiler/examples/Shop/shop.bs`'s `Which(Doc d)` dispatches on a union of two records by
erasing them to maps carrying a minted `Kind` tag (per F3/ticket 26). Disassembled `Which/1` and
`Amount/1` from the built `Shop.beam`, then hand-wrote the same shape directly in Erlang
(`#{'Kind' := 'Shop.Order'} -> order; ...` and `maps:get('Total', D)`), compiled and disassembled
that too:

```
=== 'Which'/1 (13 instrs), both versions, byte-for-byte identical ===
  {test,is_map,{f,1},[{x,0}]}
  {get_map_elements,{f,1},{tr,{x,0},{{t_map,any,any},0,18446744073709551615}},
                    {list,[{atom,'Kind'},{x,1}]}}
  {select_val,{x,1},{f,1},
              {list,[{atom,'Shop.Invoice'},{f,4},{atom,'Shop.Order'},{f,3}]}}
  ... (identical in both)

=== 'Amount'/1 (6 instrs), both versions, byte-for-byte identical ===
  {bif,map_get,{f,0},[{atom,'Total'},{x,0}],{x,0}}
  return
```

Record-union dispatch compiles to a single `is_map` + `get_map_elements` + `select_val` **jump
table** — not a sequential per-clause scan — and it is identical to what a person would hand-write
with Erlang maps. `Amount`'s field projection emits the same `map_get` BIF either way, with no
extra guard on either side (the checker's exhaustiveness proof lets it skip a runtime kind check
entirely — a soundness question for a different ticket, not a performance one). **This closes
§3's flagged gap: records and dispatch show zero measured instruction-level overhead**, extending
today's "instruction-identical" finding from the tight-integer-loop shape to the tagged-union
shape.

### 1e. Second workload, re-confirmed (§3.4)

`aoc/bench/fib/` minus Gleam, `fib(100,000)`, 9 runs/impl, fresh process per run (same GC-safety
shape the ticket's harness already uses):

```
                min ms    med ms    max ms      rel
Erlang           786.9    1116.6    4606.0    1.06x
Elixir           740.3    1002.2    1969.5    1.00x
beam-sharp       793.0    1159.1    1749.7    1.07x
all agree
```

Consistent with the ticket's own 08-15 finding: a dead heat, GC/allocation-dominated workload,
no signal either way. Nothing new here; included for completeness since CLAUDE.md's Notes section
explicitly asks for a re-run before trusting any of this.

### 1f. Ruled out again while I was in there: module size and load time

`Day01.beam` is 2172 bytes vs `bench_erl.beam`'s 1244 bytes — but the whole difference is in the
`abstract_code`/`Dbgi` chunks (6557/3850 bytes vs 16/306 bytes: `bsc` retains full debug info by
default, `erlc` without `+debug_info` doesn't). Neither chunk is read into the runtime code area
at call time — both are tooling metadata (dialyzer, xref, stack traces) — so this is a build-flag
difference, not a codegen-quality one, and it doesn't touch the hot-loop question. Cold
`code:load_file/1` for both modules: ~360–490 µs either way, in the noise, and irrelevant at
673,364 calls regardless (it happens once).

---

## 2. Adversarial re-verification

The task asked for a separately-spawned verifier subagent. **No subagent-spawning tool is
available to me in this session** (I checked: `ToolSearch` for "spawn subagent task agent"
surfaces only `TaskStop`, `SendMessage` to already-running peers, and worktree tools — nothing
that starts a fresh independent reviewer instance). Rather than fabricate a second opinion, I
re-ran the checks below myself, deliberately adversarially, and report exactly what I checked
rather than asserting an outside agent "agreed":

- **Is the harness calling what it claims to call?** Confirmed via the disassembly itself — the
  `.beam` module/function atoms in every listing above read `'Day01'`/`'Wrap'`/`'Spin'` and
  `bench_erl`/`wrap`/`spin`, matching the `fun M:F/A` references in `bench3.erl`'s `Impls` list
  exactly. Not spoofed.
- **Warm/cold asymmetry, call-order bias**: controlled for directly — reran with the call order
  reversed (beam-sharp first instead of last) at double the iteration count; result unchanged
  (§1b). `bench.erl`'s own design already calls each `F(Deltas)` once to check the answer before
  the timed loop, so every implementation gets one warm-up call regardless of position.
- **GC bleed between implementations** (the exact bug the ticket's own README section "The fib
  harness measured garbage collection first" documents): the day01 harness runs all timed calls
  in one long-lived process with no explicit GC between implementations, same as the ticket's
  original; I did not change this. It's a real caveat inherited from the original harness, not
  introduced by me, and the reordering test above suggests it isn't hiding a large effect (if
  running third were a systematic disadvantage, beam-sharp would have looked *worse* in the
  original order and *better* when moved first — it didn't move either way, within noise).
- **Is my Gleam-removal a fair diff of the harness?** Full `diff` shown in §1b — it is exactly the
  Gleam line and a docstring/message change, nothing in the timing methodology.
- **Rigged record comparison?** I wrote the hand-Erlang equivalent myself, so checked it isn't a
  strawman: it uses the same map representation `bsc` actually emits (`#{'Kind' := ...}`), not a
  weaker or stronger one, confirmed by reading `Shop.abstr`'s emitted pattern before writing the
  by-hand version.

What I could **not** independently cross-check: OTP-28 behavior (no OTP 28 available here — see
§1b), and Gleam's numbers (no Gleam available here — every Gleam figure in this brief is quoted
from the ticket, not measured by me).

---

## 3. Options

### Option A — Close the "why 20%" half of the ticket as not reproducible; note it, don't build for it

**What**: Record today's measurement (§1) as the answer to "is the cause" — it wasn't a cause,
because on current `master` there's no gap to have a cause. Leave "the ceiling" (§3.3's real
question, still unanswered) as the only live thread, and don't spend compiler-engineering effort
chasing a regression that isn't currently present.

**Evidence**: §1a–§1d, six independent timing runs across two call orders, byte-identical
disassembly across every hot-path function including the previously-unmeasured record-dispatch
axis.

**Strongest counterargument**: the original 08-15 measurement was *also* internally consistent
across repeated runs (the ticket says so explicitly) and still turned out to be a real, if
transient, gap — "reproducible today" is not the same guarantee as "won't reproduce again."
`bs_emit.erl` has had 6 commits land against it in under a month; a compiler under this much
active development regressing the exact mechanism §1c describes (SSA-shape parity with
hand-written Erlang) is not a remote risk, and closing the ticket outright discards the only
record that this was ever checked. And this brief's biggest unmeasured variable — OTP 28 — is
exactly the toolchain the gap was originally found on.

### Option B — Turn `aoc/bench/` into a standing parity gate, concretely: `check-emitted-parity.sh`

**What**: A new `compiler/bin/check-emitted-parity.sh`, in the shape of the repo's other
`check-*.sh` gates, that: builds `aoc/bench/Day01` with `bsc` and `aoc/bench/bench_erl.erl` with
`erlc`, disassembles both with `beam_disasm:file/1`, and **fails the run if the instruction lists
for `Wrap/1`, `Hit/1`, or `Spin/4` differ from `wrap/1`/`hit/1`/`spin/4`** — the exact diff this
brief did by hand in §1a, scripted. Optionally, a second, generously-thresholded check: median of
N runs must be beam-sharp ≤ 1.15× Erlang's (loose enough not to flake on a shared CI runner, tight
enough to catch a real 20%-class regression).

**Evidence**: this is literally the probe methodology of §1a and §1b, already written and run in
this session — turning it into a gate is copying working code, not new design.

**Strongest counterargument**: **CLAUDE.md's own rule** — *"A gate guards the language or the
handoff, never the tracking layer... a new check on tickets, the glossary, or the checks
themselves needs a second occurrence of the failure it names."* There has been exactly *one*
occurrence of this specific failure (the 08-15 measurement) and it has not recurred since (this
brief). The instruction-diff half is arguably "guards the language" (emitted-code quality is part
of what makes B# usable) and defensible on one occurrence since it's cheap and precise; the
*timing* half is the part CLAUDE.md would push back on hardest — timing gates are exactly the kind
of noisy, environment-sensitive apparatus that grew and then got cut on 2026-09-05, and ticket
39's own §4 says plainly *"no optimisation work has ever been done... a 20% gap on a first
measurement is not a verdict on the design."* A defensible middle ground is the instruction-diff
check alone, no timing assertion — but that's a design call for David, not something this brief
should pre-decide.

### Option C — Chase the ceiling: write a benchmark shaped to defeat success-typing, not confirm it

**What**: §3.3's real question — *"Can `bs_emit` supply what the analyser is missing? ... If it
can, the ceiling is above Erlang's, not below"* — is still completely unanswered, and today's
finding makes it *sharper*, not smaller: `beam_ssa_type.erl`'s success-typing pass (§1c) is known
to have real limits the literature it cites documents — correlated multi-argument constraints,
guards it can't read as refinements, value flow through aggregate structures. Day 1 and fib are
both shapes success-typing already handles well (single accumulator, monotone recursion), which
is *why* they came out identical — they were never going to show a ceiling. A concrete next step
per CLAUDE.md's own preference ("a design question is B# code plus the compiler delta") would be
a program the standard pass can't fully narrow on its own — e.g. a function whose exhaustiveness
depends on a relationship *between* two parameters (`Foo(n, m) when n > m`, the exact shape ticket
46/F37's commit `b5b091a` already had to reason about for boundary guards) — compiled once
straight, once with beam-sharp's algebra additionally driving an emitted range fact the standard
inference wouldn't reach on its own, and timed.

**Evidence**: none yet — this is the least-evidenced of the three options. I did not write or run
this benchmark; identifying that it's the right shape to test is inference from reading
`beam_ssa_type.erl`'s own stated method and from `b5b091a`'s commit message, not a measurement.

**Strongest counterargument**: speculative, open-ended compiler-engineering work chasing a ceiling
nobody has asked to beat yet, on a compiler ticket 39 §4 explicitly says has never had a tuning
pass and isn't overdue for one. Per CLAUDE.md's own ban on option-menus, this option is the
weakest-grounded of the three precisely *because* it isn't yet "a B# program plus the compiler
delta" — it's a description of what that program would need to look like. It shouldn't be
resolved from this brief; at most it's raw material for a future ticket, written the way ticket 39
itself was — from a real program that does not compile to a better answer today.

---

## Recommendation

**A, folding B's instruction-diff half in as the concrete follow-through — not B's timing half,
and not C.** The specific claim ticket 39 was raised to explain (a 20% gap, instruction-identical
code) does not hold on current `master`; that's worth recording precisely so nobody re-discovers
it from scratch, and worth guarding cheaply (an instruction-diff check costs little and matches
CLAUDE.md's "guards the language" bar) — but not worth a timing-based CI gate on a first,
untuned, single-environment measurement, and not worth opening a new speculative-ceiling
workstream (Option C) until someone actually wants B# code to run faster than Erlang, not merely
as fast. The one thing I'd flag as genuinely unresolved and worth a human's judgment call: whether
this ticket should stay open specifically *because* OTP 28 remains untested here — that's a real
gap in this brief's coverage, not a formality, since it's the one variable that differs from the
original measurement that I could not control for.

---

## 4. Reproducing

```bash
# from a fresh checkout — see §0 if leex fails with "TokenLoc is unbound"
cd compiler && rebar3 escriptize

cd ../aoc/bench
erlc -o /tmp/b bench_erl.erl
../../compiler/_build/default/bin/bsc -o /tmp/b Day01
erl -noshell -eval '
{beam_file,_,_,_,_,C}=beam_disasm:file("/tmp/b/bench_erl.beam"),
[io:format("~p/~p: ~p instrs~n",[N,A,length(I)]) || {function,N,A,_,I}<-C],
halt().'
# repeat for /tmp/b/Day01.beam, diff by eye or with erlang:'=='/2 on the instruction lists
```
