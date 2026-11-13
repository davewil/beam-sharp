# 39 — Why is instruction-identical code 20% slower, and what is the ceiling?

Type: grilling
Status: **open** — raised 2026-08-15 from
[the four-language benchmark](../../aoc/bench/README.md)

## Question

beam-sharp runs a hot integer loop **~20% slower than Erlang, Elixir and Gleam**, while emitting
**instruction-for-instruction identical bytecode**.

Measured on AoC 2025 Day 1 part two — 673,364 iterations, all four loaded as `.beam` and called
directly so no CLI startup, compile step or VM boot is inside the number, and all four returning
the same answer:

| | min ms | median | rel |
|---|---|---|---|
| Gleam | 5.13 | 5.18 | 1.00x |
| Elixir | 5.25 | 5.49 | 1.02x |
| Erlang | 5.30 | 5.48 | 1.03x |
| **beam-sharp** | **6.14** | **6.18** | **1.20x** |

The other three cluster within 3%, which is what says the harness measures something real.

**Decide what causes it and what the ceiling is.** The second half matters more than the first.

## §1. What is already ruled out

Not suspected — measured, and the measurements are reproducible from `aoc/bench/`.

- **Not the FFI.** `:erlang.rem` is not a remote call at run time. The compiler lowers it to the
  `rem` BIF exactly as it lowers Erlang's own operator.
- **Not the instruction sequence.** `Wrap/1` and the hot `Spin/4` disassemble to the same
  instructions in the same order — 26 each, `A =:= B` on the instruction list.
- **Not the `-spec`.** This was the obvious candidate: ticket 13 emits a widened spec for every
  function, and `integer()` where the body would infer `0..99` looks exactly like the thing that
  defeats inference. **Refuted** — stripping all seven spec attributes from the emitted `.abstr`
  and recompiling leaves the hot loop byte-identical and the time unmoved (6.51 ms with, 6.54 ms
  without, against Erlang's 5.40 ms in the same run).

**What is observed** is that the operands carry less type information for the JIT. Erlang's loop has
`{tr,{x,0},{t_integer,{0,99}}}` where beam-sharp's has a bare `{x,0}`, so the JIT has less to
specialise against.

## §2. The framing to argue with, because it is the wrong way round

David, raising this: *"obviously there will be a slight degradation from beam-sharp strictly typed
to erlangs."*

**The intuition is reasonable and the evidence points the other way.** Static typing is not paying a
runtime tax here — there is no extra work in the emitted code, because the instruction sequences are
identical. Nothing is being checked at run time that Erlang does not check.

What is happening is the **opposite of a tax**: Erlang's compiler *infers* `0..99` from `wrap/1`'s
body and propagates it; beam-sharp *knows* the same fact in a stronger form and **throws it away at
the emission boundary**.

That inverts the ceiling. Ticket 20 put **exact integer intervals** in the algebra — the checker
prints residuals like `int <= 1 | int >= 3` and proves `m <= 8` covers a clause. So beam-sharp holds
type information Erlang's analyser has to reconstruct, and in a form Erlang cannot express in a
`-spec` at all. **The interesting question is not why it is 20% behind but why it is not ahead.**

**One structural reason it currently cannot be, and it is ticket 04's doing.** A mandatory signature
means `Wrap` is *declared* `int Wrap(int n)`, so the checker never narrows its return to `0..99` —
the declaration is the answer. Erlang, having no declaration, is free to infer the tighter fact.
So the same rule that makes exhaustiveness well-posed may be what discards the range. That is a
tension worth stating plainly, not a defect.

## §3. What would settle it

1. **Is the gap in `Spin` at all?** Time the loop in isolation rather than the whole fold. Cheap,
   and it either localises the cost or moves the question.
2. **Do the annotations cause it, or merely accompany it?** Hand-write an Erlang module whose
   annotations are stripped to match beam-sharp's, and see whether it slows to 6.1 ms. This is the
   experiment that turns a correlation into a cause, and nothing else in §1 substitutes for it.
3. **Can `bs_emit` supply what the analyser is missing?** The algebra has the ranges. Whether the
   Abstract Format can carry them into the optimiser — and whether the optimiser trusts them — is
   unmeasured. If it can, the ceiling is above Erlang's, not below.
4. ~~**Does it survive a second shape?** One tight integer loop is one data point.~~
   **ANSWERED THE SAME NIGHT, and it narrows the question considerably.** `fib(100,000)` — the same
   four languages building a 100,000-element list of bignums — is a **dead heat**. Two consecutive
   runs put beam-sharp fastest and then Gleam fastest, so run-to-run variance exceeds any difference
   between them.

   | workload | dominated by | beam-sharp |
   |---|---|---|
   | 673k tight integer iterations | the emitted loop | **consistently 20% behind** |
   | fib(100,000) — bignums, cons cells, GC | the runtime | indistinguishable |

   So this is **not a general overhead**. It appears exactly where the emitted instructions are the
   whole cost and vanishes where time goes into BIFs, allocation and garbage collection — which
   every language on this VM shares equally. Whatever the cause is, it lives in code the JIT would
   otherwise specialise, which is consistent with the missing `{tr, …}` annotations and rules out a
   broad class of explanations.

   Still open on this axis: **records and dispatch**. Neither workload touches a record, so the
   boundary tag guard (ticket 18, F3) has never been measured at all.

## §4. The thing this ticket is not

**No optimisation work has ever been done.** David: *"we haven't even looked at beam-sharp
optimisations yet"*. This is a **baseline**, taken the first time anyone measured against another
language, on a compiler whose emitter has been written to be *correct* and never once tuned. A 20%
gap on a first measurement with an untuned emitter is not a verdict on the design; it is a starting
number.

The F1 benchmark (`bench/bs_bench.erl`) measures the compiler's own speed, not the emitted code's.
This is the first measurement of the second thing, and there is no harness for it in the repo other
than `aoc/bench/`.

## Consequences elsewhere

- **[Ticket 13](13-compilation-target-decision.md)** owns the emission contract and the widening
  rule. §3.3 is a question about whether that widening is load-bearing for performance as well as
  for Dialyzer, which 13 has never been asked.
- **[Ticket 20](20-untheorised-term-shapes.md)** owns the intervals §2 says are being discarded.
- **[Ticket 18](18-boundary-defence.md)** already argues over a two-tier emitted boundary on
  precision grounds; this is the same tier question arriving from performance.

## Notes

Raised from a benchmark rather than from the map, like 33 (from F3), 37 (from F6) and 38 (from AoC).
Those established that such a ticket is a **timestamped claim about the compiler**, so re-run
`aoc/bench/` before resolving — the numbers here are OTP 28 / erts-16.4, Elixir 1.19.5, Gleam
1.18.1, Apple Silicon, 2026-08-15.

**And re-read the benchmark's own first table before trusting any of this.** It showed beam-sharp
and Gleam *beating* Erlang, because three of the four implementations carried a guard the fourth
did not. The corrected table is the one above; the wrong one is kept in `aoc/bench/README.md`
because the failure mode — a plausible table that measures the author's coding style — is the one
this ticket is most likely to repeat.

## Round 1 — 2026-11-13

Measured on Erlang/OTP 28.5 (built from `otp_src_28.5`, the pinned release) with rebar3 3.27.0,
against an unmodified `compiler/` at `2e458ba`, **on x86_64 Linux, where the numbers above were
taken on Apple Silicon**. The probes are in
[the research file](../research/39-emitted-code-quality.md) and are printed by
[`39a`](../prototypes/39a_the_hot_loop_today.sh).

**The difference §1 observed is gone, and its cause was the export list.** At `18ca054` the
language had no visibility marker, so every function in the benchmark was exported, and OTP's
optimiser assumes nothing about the arguments of an exported function. F12 shipped
`public`/`private` two days later, and `1243cab` marked the benchmark's helpers `private` the same
day. Nobody re-ran the benchmark after that.

### The program

[`aoc/bench/Day01/bench_bs.bs`](../../aoc/bench/Day01/bench_bs.bs), as it stands today:

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

What `Spin`'s recursive clause compiles to today. The operand that was a bare `{x,0}` in August
carries the range:

```erlang
    {gc_bif,'+',
            {f,0},
            2,
            [{tr,{x,0},{t_integer,{0,99}}},{tr,{x,1},{t_integer,{-1,1}}}],
            {x,0}}.
    {call,1,{f,4}}. % 'Wrap'/1
```

`Wrap`, `Hit`, `Spin`, `Clicks` and `PartTwo` are identical to `bench_erl.erl`'s assembly, operand
types included (18 `t_integer` annotations in each module). `Sign` and `Size` differ because the
two sources write them differently, and they run 4,732 times a run against `Spin`'s 673,364.

Timed in one VM, best of six rounds of 25:

| | min ms | rel |
|---|---|---|
| Erlang | 8.91 | 1.00x |
| beam-sharp today | 9.02 | 1.01x |
| the same source, every function `public` | 9.33 | 1.05x |
| Erlang, `+no_type_opt` (no annotations at all) | 9.08 | 1.02x |
| beam-sharp at `18ca054` | 9.10 | 1.02x |

One implementation's own rounds spread by about 5%, so the last three rows are not separable from
each other.

**Two limits on this, stated before the question.** The 20% itself was not reproduced on this
machine for any module: on x86_64 the August build is within the noise of Erlang, and so is Erlang
with its annotations stripped. So the timing shows today's build level with Erlang, and it does
not show that the missing annotations cost 20% on arm64. And nothing here measures records or
dispatch, which §3.4 named and no benchmark has touched.

### Q1. Is this ticket closed as no longer reproducing?

### What each answer does

**Yes.** The benchmark compiles as it does today and nothing in the compiler changes. The ticket's
entry records the cause (an exported function's arguments are untyped to the optimiser; a
`private` one's are inferred from its call sites) and that §3.3's *"can `bs_emit` supply what the
analyser is missing"* was answered by F12 without anyone asking it. `aoc/bench/README.md` still
says *"beam-sharp is ~20% slower"* in the present tense and gains a dated line saying which
compiler that was.

**No.** The ticket stays open, and the benchmark above is no longer its program, since it has no
gap left to explain. The next round would have to bring a program in which the checker holds a
type that reaches the optimiser by neither route measured here: not by call-site inference
(`private`), and not by F24's head test (`public`, four `is_integer` tests per iteration of
`Spin`, about 4%). The compiler gains nothing from this answer alone; what it would gain is that
round's question.

### Recommended answer

Yes: the five functions on the hot path are now the same code as Erlang's, so there is no
difference left for this ticket to explain, and a question about what else the checker could hand
the optimiser needs its own program, which this benchmark is not.

