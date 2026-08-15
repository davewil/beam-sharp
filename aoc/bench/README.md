# Four BEAM languages on the same problem

**Erlang, Elixir, Gleam and beam-sharp**, all solving AoC 2025 Day 1 part two — 4,732 rotations,
**673,364 clicks** simulated one at a time. Asked for 2026-08-15 (David: *"compare Elixir, Erlang,
Gleam and beam-sharps execution times"*).

## What is being compared, and what is not

All four compile to BEAM bytecode and run on the same VM, so the only honest thing to compare is
the **emitted code**. The harness therefore:

- loads all four as `.beam` and **calls the function directly** — no CLI startup, no compile step
  and no `erl` boot inside the number. `bsc` compiles *and* runs, so timing the CLI would have
  measured the compiler;
- **checks the answer first**, because a fast wrong answer is worth nothing. All four return 6770;
- reports the **minimum** of 25 runs alongside the median, since micro-benchmark noise is one-sided
   — nothing makes a run accidentally faster.

Measured on OTP 28 / erts-16.4, Elixir 1.19.5, Gleam 1.18.1, Apple Silicon.

## The first run was wrong, and how it was wrong is the useful part

```
             answer      min ms    med ms      rel
Erlang       6770          6.44      6.64    1.23x
Elixir       6770          6.49      6.85    1.24x
Gleam        6770          5.25      5.46    1.00x
beam-sharp   6770          5.59      6.06    1.07x
```

Gleam and beam-sharp appearing to *beat* hand-written Erlang is not a result, it is a bug in the
benchmark. My Erlang, Elixir and beam-sharp loops carried a `when left > 0` guard on the recursive
clause; the Gleam one, written as a `case`, did not. **One extra comparison per click, 673,364
times.**

That is worth keeping visible: the first plausible-looking table was measuring my coding style, not
the compilers.

## The comparison with all four algorithmically identical

```
             answer      min ms    med ms      rel
Erlang       6770          5.30      5.48    1.03x
Elixir       6770          5.25      5.49    1.02x
Gleam        6770          5.13      5.18    1.00x
beam-sharp   6770          6.14      6.18    1.20x
```

**Erlang, Elixir and Gleam are within 3% of each other** — which is the expected result, since all
three lower to the same bytecode through the same backend. That tight cluster is also the evidence
that the harness is measuring something real.

**beam-sharp is ~20% slower**, consistently, across repeated runs.

## Why — and this is NOT established

The obvious suspects were checked and are not the cause.

**The emitted code is instruction-for-instruction identical.** `Wrap/1` and the hot `Spin/4` loop
disassemble to the same instructions in the same order as the Erlang version — same `gc_bif rem`,
same `call_last`, same register moves, 26 instructions each. The `:erlang.rem` FFI call is *not* a
remote call at run time; the compiler lowers it to the `rem` BIF exactly as it lowers Erlang's
operator.

**The only visible difference is JIT type annotations on operands.** Erlang's `Spin` carries
`{tr,{x,0},{t_integer,{0,99}}}` where beam-sharp's has a bare `{x,0}` — so the JIT has less to
specialise on.

**The `-spec` was the obvious explanation and it is refuted.** Ticket 13 emits a widened `-spec` for
every function, and a spec saying `integer()` where the body would infer `0..99` looked like exactly
the thing that would defeat inference. Tested by stripping all seven spec attributes from the
emitted `.abstr` and recompiling: **the hot loop is byte-identical (26 instructions, `A =:= B`) and
the time does not move** (6.51 ms with, 6.54 ms without, against Erlang's 5.40 ms in the same run).

So: **the cause is not established.** What is known is that it is not the FFI, not the instruction
sequence, and not the spec. The remaining candidate is why the compiler's type analyser infers less
from beam-sharp's abstract forms than from equivalent Erlang source — which is a real question and
not one to answer at 4am by guessing.

## A second workload, and it is the contrast that matters

David: *"Do fib(100,000,000) in each language"*, then *"or fib(100,000)"*.

**10⁸ is not slow, it is impossible.** `examples/fib.bs` returns a *list* of the first n Fibonacci
numbers, and the nth has ~0.209n decimal digits. Measured scaling on beam-sharp:

| n | time | last number |
|---|---|---|
| 10,000 | 1.8 ms | 2,090 digits |
| 50,000 | 56.8 ms | 10,449 digits |
| 100,000 | 544 ms | 20,899 digits |
| 200,000 | 4,292 ms | 41,797 digits |

Roughly **O(n²)** — n additions whose operands grow linearly — so 10⁸ extrapolates to about *six
years*, and the list alone would need ~10¹⁵ bytes. The shape of the answer, not the speed of the
compiler, is what rules it out.

**At n = 100,000, all four are indistinguishable.** Two consecutive runs, 9 runs each:

```
             min ms  med ms    rel        min ms  med ms    rel
Erlang        188.7   190.9  1.11x         197.2   203.3  1.19x
Elixir        181.4   189.8  1.07x         211.7   232.5  1.28x
Gleam         180.5   202.9  1.07x         165.8   170.9  1.00x
beam-sharp    169.3   188.1  1.00x         171.1   175.3  1.03x
```

**The ordering flips between runs** — beam-sharp fastest in the first, Gleam in the second — so
run-to-run variance exceeds any difference between the languages. The honest reading is a dead heat,
and reporting a winner here would be reporting noise.

### That contrast is the actual result

| workload | dominated by | beam-sharp |
|---|---|---|
| Day 1 part two — 673k tight integer iterations | **the emitted loop** | **consistently 20% behind** |
| fib(100,000) — bignum arithmetic, 100k cons cells, GC | **the runtime** | indistinguishable |

So beam-sharp's gap is **not a general overhead**. It appears exactly where the emitted instructions
are the whole cost, and vanishes where the time goes into BIFs, allocation and garbage collection —
which every language on this VM shares. That localises [ticket 39](../../wayfinder/issues/39-emitted-code-quality.md)
considerably: whatever it is, it lives in code the JIT would otherwise specialise.

### The fib harness measured garbage collection first

Worth recording beside the guard mistake above, because it is the same class of error. Timing the
calls in one process gave an 8× min/median spread for Elixir — 82 ms against 832 ms — because each
run's garbage was still being collected while the next ran, and whoever went first paid for whoever
went last. Every run now happens in a **fresh process that then exits**, so its heap is discarded
wholesale rather than collected.

**Two benchmarks, two ways of accidentally measuring something else.** That is the honest rate.

## Reproducing

```
bash build.sh                       # compiles all four into ebin/
erl -noshell -pa ebin -s bench main ../2025/day01/input.txt
```

`build.sh` expects `gleam build` to have been run once in `gleam/`.

## Caveats worth stating

- **One workload.** A tight integer loop with a tuple return. It says nothing about records,
  binaries, message passing or anything beam-sharp has not built yet.
- **Micro-benchmark.** 5–6 ms per run; the spread between min and median is ~0.2 ms, so a 20% gap
  is well outside the noise but a 3% one is not — which is why Erlang, Elixir and Gleam are
  reported as *a cluster* rather than ranked.
- **The implementations are deliberately unidiomatic.** They are the same algorithm transliterated,
  so that the comparison is of compilers rather than of standard libraries. None of them is how you
  would actually write this.
