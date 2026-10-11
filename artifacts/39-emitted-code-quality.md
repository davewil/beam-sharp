# Brief 39 — Why is instruction-identical code 20% slower, and what is the ceiling?

Ticket: `wayfinder/issues/39-emitted-code-quality.md` (ENG-211), left OPEN. Measured at repo HEAD `a5af573`, OTP 28 / erts-16.4
(JIT), Elixir 1.20.4, Gleam 1.19.1, **Linux x86_64, Xeon 2.8 GHz, 4 shared vCPUs** (the ticket's numbers are Apple Silicon).
Every number below comes from `artifacts/probes/39/output.txt`; rerun with `bash artifacts/probes/39/run.sh`.

## What this brief found, in six lines

1. **The 20% gap does not reproduce.** beam-sharp 16.69-16.81 ms, Erlang 16.82-16.96, Elixir 16.77-16.84 (min of 25, three runs of the ticket's own
   `bench.erl`; all four answers 6770). beam-sharp is level with Erlang, not behind it.
2. **The ticket's observation is wrong at HEAD.** bsc's `Spin` carries the same `{tr,{x,0},{t_integer,{0,99}}}` operands as Erlang's;
   `Spin`, `Wrap`, `Hit` disassemble identically (label/line pseudo-instructions aside). There is no missing annotation to blame.
3. **Annotations do not matter on this machine anyway.** Stripping every `{tr,..}` from the beam leaves the time unchanged
   (16.5-16.6 vs 16.8 for Erlang, 16.3-16.4 vs 16.7 for bsc). Adding more (guards) leaves it unchanged too (16.5-17.0).
4. **There is a large, reproducible gap, and it is the other way round: Gleam takes 36% less time than beam-sharp** (10.8 vs 16.8 ms).
   Cause, isolated by a control: Gleam emits `-compile(inline)`. Remove that one attribute from Gleam's own abstract code and it
   runs at 16.8 ms. Add it to the Erlang source and Erlang runs at 10.6 ms.
5. **The ceiling is not in type information.** The Abstract Format carries type facts only through guards, `-spec` is ignored by
   `beam_ssa_type` (probe 5), and bsc's checker does not derive `0..99` for `Wrap` in the first place (probe 7). The ceiling is in
   inlining, which bsc can switch on by emitting one `-compile` attribute.
6. **Open for David: whether crash traces may lose the frames of inlined private functions** (probe 8).

## Which of the ticket's claims survived

| Ticket claim | Observed here | Probe |
|---|---|---|
| beam-sharp ~20% slower than Erlang | **No**: 16.69-16.81 vs 16.82-16.96 (Erlang, same three runs) | output §2 |
| `Spin`/`Wrap` instructions identical | **Yes**: IDENTICAL for spin, wrap, hit once label/line lines are ignored (20 instructions in `Spin`, 26 counting them) | §3 |
| bsc's operands are bare `{x,0}` | **No**: `[{tr,{x,0},{t_integer,{0,99}}},{tr,{x,1},{t_integer,{-1,1}}}]`, same as Erlang | §3 |
| Not the `-spec` | **Yes**, and stronger: `beam_ssa_type` ignores specs entirely (none / wide / `0..99` spec produce byte-identical operand types) | §5 |
| "beam-sharp knows `0..99` and throws it away" | **No**: the checker never derives it. `Wrap` returns `int` because `rem` is a declared-`int` FFI, and `a + b` over two `0..99` values is `int`, not `0..198` | §7 |
| Gap is in the emitted loop, not in BIFs/GC | Moot: no gap vs Erlang. Isolating `Spin` alone gives the same ratios as the whole fold | §4 |

Things the ticket did not know: Gleam's lead, and that it comes from `-compile(inline)`.

## Noise floor

Three fresh VMs, 101 round-robin rounds each, 19 variants interleaved. **Minimum per variant moves by at most 0.15 ms (1%) between VMs**
(`v_bs` 16.77 / 16.72 / 16.77; `v_gl` 10.61 / 10.58 / 10.60). Medians are not usable on this shared box: p25..p75 spans roughly 17 to 28 ms
around a 16.7 ms minimum. I therefore claim only differences between minimums, and only above 3%. The ticket's claim of a 0.04 ms
min/median spread is not reproduced here; the 36% result clears the floor by thirty times, the 6% result (bsc's private list vs the hand-written Erlang list) by six.

## The gating question

**May bsc put a `-compile` inline directive into the modules it emits?**
Everything else follows from it. If the answer is no, there is nothing to do for emitted-code speed on this program: it is level with
hand-written Erlang and Elixir, and type-information emission (annotations, guards, specs) was measured to buy nothing. If yes, the
second question (whole-module `inline` or an explicit list) is a measured choice, below.

## The program

The benchmark loop, unchanged (`aoc/bench/Day01/bench_bs.bs`):

```csharp
private int Wrap(int n)
Wrap(n) -> :erlang.rem(:erlang.rem(n, 100) + 100, 100)

private int Hit(int pos)
Hit(0) -> 1
Hit(n) -> 0

private (int, int) Spin(int pos, int step, int left, int zeros)
Spin(pos, step, 0, zeros) -> (pos, zeros)
Spin(pos, step, left, zeros) ->
    var next = Wrap(pos + step)
    Spin(next, step, left - 1, zeros + Hit(next))
```

Three emission choices. All three compiled by the prototype bsc and timed end to end (min ms, three fresh VMs, 101 rounds; beam bytes
include `debug_info`):

| Choice | Emitted module header | `Day01.PartTwo` min ms | .beam bytes |
|---|---|---|---|
| **A. nothing** (today) | no `compile` attribute | **16.62 – 16.70** | 2356 |
| **B. whole module** | `-compile(inline).` | **10.67 – 10.81** | 2240 |
| **C. private list** | `-compile({inline, [<every private function>]}).` | **10.20 – 10.23** | 2740 |
| reference: Erlang source, as in the benchmark | none | 16.71 – 16.81 | n/a |
| reference: same Erlang source + `-compile(inline)` | `inline` | 10.77 – 10.81 | n/a |
| reference: same Erlang source + `{inline,[wrap/1,hit/1]}` | list | **9.65 – 9.66** | n/a |
| reference: Gleam 1.19.1 as shipped | `inline` | 10.76 – 10.78 | n/a |

What A compiles to: `Spin` allocates a four-slot frame, moves `x3,x2,x1` to `y1..y3`, `call`s `Wrap`, `call`s `Hit`, then `call_last`s itself
(output §3 prints it in full). What C compiles to: no `call` at all in the loop; `Wrap`'s three `gc_bif`s and `Hit`'s `is_eq_exact` sit inside
`Spin`, no frame is allocated, and the compiler peels one iteration (the second `gc_bif` run appears twice in `Spin`).

### Compiler delta (prototype built, 11 added lines, `probes/39/proto.patch`)

`compiler/src/bs_emit.erl`: one new function `inline_attr/2` (7 lines) and one `++ inline_attr(Fns, Behaviours)` in `forms/1`, directly
after the `behaviour` attributes (around line 79). The prototype reads `BSC_INLINE=all|private` from the environment so all three rows
came out of one binary; a real version needs no switch. Option C needs `is_public/1` and `name/2`, both already in the module; the
private functions' names go through `name/2`, so a behaviour callback keeps its lowered name.
Gate coverage (`probes/39/eunit_proto.txt`, `rebar3 eunit` in the patched copy): prototype off, all 1434 tests pass; with
`BSC_INLINE=private` or `BSC_INLINE=all`, 1433 pass and one fails (`repl_tests`, discussed under Option C).

## Option A — emit nothing

Compiles every program bsc compiles today; no tests move. The loop is level with Erlang and Elixir.
**Strongest counterargument:** it leaves a measured 36-39% on the table on loops of small private helpers.
Wrapping the small `Wrap`/`Hit` helpers is *encouraged* by the language (every clause is a function), so B# programs will have more
tiny private functions than C# ones.

## Option B — `-compile(inline)` on every module

Same hot loop, 10.7-10.8 ms, 36% under today. Matches Gleam (10.8) and Erlang-with-`inline` (10.8) within noise.
Two things the measurement showed that a reader will not expect:

- The default heuristic (`inline_size` 24, `compile.erl:112-114`, `cerl_inline.erl:116`) does **not** inline bsc's `Wrap`, because bsc's
  FFI result guard makes it bigger: `'Wrap'` is `case erlang:rem(case erlang:rem(N,100) of V when is_integer(V) -> V end + 100, 100) of ...`
  (output §3, abstract code), where Erlang's is `(N rem 100 + 100) rem 100`. In the isolation variants (Spin exported, so its argument
  types are not inferred) this costs 17%: bsc `Wrap` 12.3 ms, Erlang `wrap` 10.6 ms. **Swapping only the `Wrap` body between the two
  modules moves the 17% in both directions** (Erlang module with bsc's `Wrap`: 12.1; bsc module with Erlang's `wrap`: 10.6) and
  raising `inline_size` to 200 removes it (10.8). When `Spin` is private, as in the real module, the cost shrinks to nothing measurable
  (10.67-10.81 vs 10.77-10.81), because the inferred argument type recovers what the missing inline would have given.
- It is not the fastest: the explicit list below is 5% faster still.

**Strongest counterargument:** `inline` changes compile time and crash traces for every module. See Option C's counterargument; B has it
in full, because it inlines exported-function bodies' callees too and the heuristic is opaque to a B# author.

## Option C — `-compile({inline, [private functions]})`

Fastest bsc-produced loop: **10.2 ms**, 39% less time than today. 6% behind the hand-written Erlang that lists its helpers (9.65), which
I have not explained: the disassembly of `p_private` and Erlang's differ in iteration peeling, and swapping `Wrap` bodies in the list
setting was not run (UNMEASURED). Only private functions are named, so exported entry points keep their own frames and their `function_clause`
error shape, and the list is exactly what the checker already knows (`is_public/1`).

**Strongest counterargument, against both B and C — crash traces change.** With the same `inner/1`, called with a value no clause accepts
(`probes/39/stack_probe.erl`):

```
default : {error,function_clause,[{inner,[3],5},{outer,1,7}]}
+inline : {error,function_clause,[{'-inlined-inner/1-',[3],5},{run,0,5}]}
```

The `outer/1` frame is gone and `inner` appears as `-inlined-inner/1-` (line still correct). Ticket 13 settled that crashes name the right
`.bs` source and line (13, around line 310); the line survives, the *caller chain* does not, and a REPL or debugger user sees a different
function name. Separately, `rebar3 eunit` with `BSC_INLINE=private` (and with `all`) fails
`repl_tests:a_private_function_is_refused_by_name_at_the_prompt_test` (the REPL's "private function" answer comes back empty): an inlined
private function whose every call site was inlined is dropped from the beam, which is a real behavioural difference for the REPL, not a
prototype artefact. Compile time on installed OTP modules, median of 7, `+inline` vs default: `lists.erl` 688 → 1054 ms,
`string.erl` 840 → 1162, `erl_scan.erl` 988 → 1556 (three runs of this probe gave +23% to +67% per module; the box is noisy,
so read it as roughly +25% to +65%). Beam size moved at most 2% (47164 → 47224, 48912 → 49696, 48636 → 49696).

## What bsc could emit instead of inlining, and what it buys: nothing measured

The ticket's section 3.3 asked whether `bs_emit` can supply type facts. Probes:

| Emitted fact | Reaches `beam_ssa_type`? | Time (min ms, Erlang / bsc loop) |
|---|---|---|
| `-spec` wide, narrow (`0..99`, `-1..1`), or absent | No: operand types identical in all three (§5) | ticket's own finding: specs stripped, time unmoved |
| `is_integer/1` guard on each parameter | Yes: 3 annotated operands instead of 1, 7 more instructions | 16.54 / 16.56-16.61 (baseline 16.75-16.80 / 16.72-16.77) |
| range guards (`0..99`, `-1..1`, `>=0`) | Yes: 14 annotated operands, 18 more instructions | 16.96-17.02 / 16.93-16.96 (same baselines) |
| annotations stripped from the finished beam | n/a (control) | 16.52-16.64 / 16.31-16.41 |
| `no_type_opt`, `no_ssa_opt` (compiler switches, not B# facts) | removes every `{tr,..}` | 16.63 and 16.63-16.71 (Erlang) |

The control row is the experiment that separates cause from correlation: with all annotations removed the loop is not slower, so on
this CPU they are correlation at most. Integer guards are level with baseline; range guards are 1% slower (the 18 extra instructions). Guards are already what bsc emits for public parameters (`bs_emit.erl`, `int_guard/6`, "Exported functions only"
comment above it), so bsc does not need a new mechanism for them, and for private functions the data says do not add one.

And bsc cannot emit the ranges the ticket hoped for, because it does not hold them (probe 7, checker output verbatim):

```
Wrap.bs:21:5: error: Spin hands Spin an argument it does not accept   // Spin(Digit pos, ...) called with Wrap's int result
  argument 1 is not covered by Spin's declared type: int <= -1 | int >= 100
Arith.bs:8:1: error: Add returns a value its signature does not declare // Digit + Digit declared as 0..198
  not covered by the declared return type: int <= -1 | int >= 199
Neg.bs:4:1: error: this refinement is not a predicate the checker can read   // value >= -1 and value <= 1 (ticket 57, open)
NegControl.bs: compiles (value >= 0 and value <= 2)
```

So the tension ticket 39 section 2 describes (mandatory signature discards the range) is not what discards it today: the checker has
no interval arithmetic, so there is no range to discard. Adding interval arithmetic to `+`, `-`, `rem` is real checker work, and
the measured payoff of delivering its output to the optimiser through guards is zero on this loop.

## How the neighbours do it

- **Gleam 1.19.1** (binary only; source not installed): the shipped beam's abstract code begins
  `-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline])` (output §3).
  Whole-module `inline`, no list. Its `-spec`s are emitted too, and ignored by the optimiser.
- **Erlang**: nothing by default; `inline` and `{inline,List}` are documented opt-ins (`compile.erl:100-125`); default `inline_size` is 24.
- **Elixir 1.20.4** (source not installed, binary probed): `BenchEx` was built with options
  `[no_spawn_compiler_process, from_core, no_core_prepare, no_auto_import]`, no inline, and times with Erlang (17.0 vs 16.9).
- **Elm** compiles to JavaScript; it has no counterpart. Not probed.

## Recommendation

**Answer the gating question "yes", and take Option C.** Emit `-compile({inline, [<private functions>]})`: it is the fastest of the three
(10.2 ms, 39% under today's 16.7), costs eleven lines in `bs_emit.erl`, and leaves exported functions' frames alone. Before it lands,
settle the REPL regression in `repl_tests` (a private function that was fully inlined vanishes from the beam), and decide whether a
crash trace that loses a private caller's frame is acceptable under ticket 13's "crashes name the right source". Do not emit
annotations, widen or narrow specs, or add guards to private functions for speed: all three were measured to do nothing. Close the
"20% behind Erlang" framing of ticket 39 as not reproduced.

## Unmeasured

- **Apple Silicon.** Whether the ticket's 20% is real there. `beam_ssa_type` output is architecture independent, so a bare-`{x,0}`
  disassembly at HEAD would be a bsc difference; but the JIT's use of `{tr,..}` is per-architecture and I did not run aarch64.
- **Why the ticket saw bare `{x,0}`.** Perhaps an older bsc. Not bisected.
- **Records and dispatch** (ticket 39 section 3.4's open axis): the boundary tag guard (ticket 18) was not benchmarked.
- **The 6% between bsc's private list (10.2) and Erlang's hand list (9.65).** Observed, not explained.
- **Option C on a large module**: compile time, size and trace effects were measured on OTP modules, not on a big B# program.
- **Whether crash traces through inlined private B# functions keep their `.bs` file attribute**: shown for Erlang only.

## Probes and how to rerun

`bash artifacts/probes/39/run.sh` (about 5 minutes; builds everything in a scratch dir under `/tmp/claude-0/work-39/`, needs
`source /tmp/claude-0/env.sh` and the built `compiler/_build/default/bin/bsc`). Output is `artifacts/probes/39/output.txt`.

| File | What it does |
|---|---|
| `run.sh` | Whole pipeline; prints tool versions first. Gleam is built with its `gleam_stdlib` dependency removed (hex.pm is unreachable; the source uses none). |
| `mkvariants.escript` | Builds the 19 variants from debug_info abstract code: `inline`, explicit inline lists, `inline_size`, `no_type_opt`, `no_ssa_opt`, guards, annotations stripped via `+'S'` and `from_asm`, a `Wrap` body swap between Erlang and bsc, Gleam with `inline` removed. Each variant exports `spin/4` so the loop can be timed alone. |
| `harness.erl` | Round-robin timing, min / median / p25 / p75, checks all answers agree first. |
| `spec_probe.escript` | Specs vs guards vs `beam_ssa_type`. |
| `stack_probe.erl` | Stack frames with and without `+inline`. |
| `ctime.escript` | Compile time and size, `+inline` vs default, on installed OTP modules. |
| `proto.patch` | The 11-line `bs_emit.erl` prototype. |
| `refused/{Wrap,Arith,Neg,NegControl}` | B# programs the checker refuses (and one control it accepts). |
| `eunit_proto.txt` | `rebar3 eunit` summaries with the prototype off / `all` / `private` (run by hand, not part of `run.sh`: about 6 minutes each). |

Probe bugs fixed along the way (everything rerun after each): the first disassembly diff reported `wrap` DIFFERENT because it compared
`{label}` and `{line}` pseudo-instructions that sit in a different order; they are now dropped before comparing. The first prototype run
crashed in the harness because the prototype modules do not export `Spin`; the harness now skips the isolation table when nothing exports
it. An early `eunit` run was cancelled (timeouts while a compile-time probe shared the CPU; its summary said 'cancelled') and was discarded;
`eunit_proto.txt` is from reruns with nothing else running. The isolation variants export `Spin`, which changes inference for `Wrap`'s argument; that is why the
bsc-vs-Erlang `inline` gap appears there (17%) and not in the private-`Spin` end-to-end runs (0.1 ms).

## Verifier corrections (artifacts/verification/39.md)

Headline minimums reproduced (A 16.61-16.67, B 10.68-10.73, C 10.21-10.24, Gleam 10.75-10.81 ms; bsc, Erlang and Elixir level to ~1%). No circular probe found. Corrections to the wording above:

- Stripping every `{tr,...}` does not leave the loop unchanged: it is 1.4-2.8% *faster* on 3 of 3 VMs (a round-trip control assembled without stripping equals baseline). Annotations buy nothing; if anything their presence costs.
- The REPL failure under `BSC_INLINE=private`/`all` is real, but the REPL answers "no Half/1 -- try :exports" rather than "is private in"; it does not come back empty.
- The "p25..p75 spans 17 to 28 ms" noise claim is unsupported (max p75 in output.txt is 19.3 ms). Minimums-only remains the right policy.
- The 6% gap between option C and hand-written Erlang compared unlike lists (the Erlang list named two functions, C names six). With all six listed: 9.58 vs 10.24 ms, so the gap is unexplained.
- Scope: the ticket's Apple Silicon run had Gleam 1.18.1 level with Erlang; the 36% Gleam lead here is x86_64 with Gleam 1.19.1. Apple Silicon is UNPROBED. Option C also grows this module's beam by 16% (2372 to 2756 bytes).
- Prototype LOC is 12 added by `git apply --numstat` (not 11); compile-time cost was measured on OTP modules only; stack-trace behaviour under inlining was shown on Erlang source only.
