# 39 — The Day 1 hot loop, re-measured

## 2026-11-13

**Toolchain: Erlang/OTP 28.5 (erts 16.4, JIT) built from `otp_src_28.5.tar.gz` (the pin in
`.tool-versions` is 28.5), rebar3 3.27.0 from its GitHub release, on x86_64 Linux.** Neither came
from mise, so `bin/check-toolchain.sh --env` would not accept this sandbox; the versions match the
pin. `compiler/` at `2e458ba`, unmodified, built with `rebar3 escriptize`; the repo's test suite
and gates other than `check-links.sh` were not run. Elixir and Gleam were not installed and nothing
below was executed on either.

**The ticket's numbers were taken on Apple Silicon and these on x86_64.** The JIT is a different
backend on each, so no timing below confirms or refutes the 20% the ticket recorded. What carries
across architectures is the assembly comparison in section 1.

Every result below is printed by
[`39a_the_hot_loop_today.sh`](../prototypes/39a_the_hot_loop_today.sh), run on that toolchain. The
numbers in the headings are the script's.

### What the ticket observed, and when

[Ticket 39](../issues/39-emitted-code-quality.md) was written on 2026-08-15 at `18ca054`. It
recorded beam-sharp 20% behind Erlang, Elixir and Gleam on
[`aoc/bench`](../../aoc/bench/README.md)'s loop, ruled out the FFI, the instruction sequence and the
`-spec`, and left one observation standing: Erlang's `spin/4` had
`{tr,{x,0},{t_integer,{0,99}}}` where beam-sharp's had a bare `{x,0}`.

Two things landed after it:

| When | What | Where |
|---|---|---|
| 2026-08-17 | F12: a signature carries `public` or `private`, and only `public` is exported | [`F12`](../../compiler/features/F12-public-and-private.md) |
| 2026-08-17 | the benchmark source marks six of its seven functions `private` | commit `1243cab`, [`bench_bs.bs`](../../aoc/bench/Day01/bench_bs.bs) lines 11 to 38 |

### 1. Today's benchmark beside Erlang's

`bsc` compiled `aoc/bench/Day01`, and `erlc -S +from_abstr` printed the assembly of the `.abstr` it
wrote. `erlc -S` printed `bench_erl.erl`'s. With labels, the module name and the case of function
names normalised, `diff` reports:

```
  wrap vs 'Wrap': identical, operand types included
  hit vs 'Hit': identical, operand types included
  spin vs 'Spin': identical, operand types included
  clicks vs 'Clicks': identical, operand types included
  part_two vs 'PartTwo': identical, operand types included
  sign vs 'Sign': DIFFERS
  size_ vs 'Size': DIFFERS
  t_integer annotations: Erlang 18, beam-sharp 18
```

`'Spin'/4` as `bsc` emits it today carries the annotation the ticket found missing:

```erlang
  {label,9}.
    {'%',{var_info,{x,0},[{type,{t_integer,{0,99}}}]}}.
    {'%',{var_info,{x,1},[{type,{t_integer,{-1,1}}}]}}.
    {'%',{var_info,{x,3},[{type,{t_integer,{0,'+inf'}}}]}}.
    {test,is_eq_exact,{f,10},[{x,2},{integer,0}]}.
    ...
    {gc_bif,'+',
            {f,0},
            2,
            [{tr,{x,0},{t_integer,{0,99}}},{tr,{x,1},{t_integer,{-1,1}}}],
            {x,0}}.
    {call,1,{f,4}}. % 'Wrap'/1
```

`Sign` and `Size` differ because the two sources differ: `bench_erl.erl` writes `sign/1` in three
clauses and orders `size_/1` the other way round. Each is called once per rotation, 4,732 times a
run, against 673,364 iterations of `Spin`.

### 2. The same source, every function public

`sed 's/^private /public /'` over the benchmark, compiled as `Day01Pub`. The range on `Spin`'s
arguments goes, and [F24](../../compiler/features/F24-boundary-kind.md)'s boundary test takes its
place: four `is_integer` tests per iteration, after which the operands are typed
`{t_integer,any}`.

```erlang
  {label,10}.
    {test,is_integer,{f,8},[{x,0}]}.
    {test,is_integer,{f,8},[{x,1}]}.
    {test,is_integer,{f,8},[{x,2}]}.
    {test,is_integer,{f,8},[{x,3}]}.
    {gc_bif,'+',
            {f,0},
            4,
            [{tr,{x,0},{t_integer,any}},{tr,{x,1},{t_integer,any}}],
            {x,0}}.
```

So the export list alone decides whether the optimiser may narrow `Spin`'s arguments from its call
sites. OTP says so in its own source, `lib/compiler/src/beam_ssa_type.erl`, OTP 28.5:

- lines 121 to 123: *"The argument types of all exported functions start out a 'any', whereas
  local functions start at 'none'."*
- lines 434 to 437: *"We can't infer the parameter types of exported functions"*, followed by
  `Ts = #{V => any || #b_var{}=V <- Args}`.

### 3. Erlang with the type pass off

`bench_erl.erl` compiled with `+no_type_opt` has no `t_integer` annotation anywhere (0, against 18).
This is the experiment the ticket's §3.2 asked for: Erlang's loop with the annotations removed.

### 4. The compiler at `18ca054`, on that day's source

Built in a detached worktree and run over the `bench_bs.bs` of that commit, which has no visibility
markers because the language had none. The module exports everything:

```erlang
{attribute,0,export,
           [{'Wrap',1},
            {'Hit',1},
            {'Spin',4},
            {'Sign',1},
            {'Size',1},
            {'Clicks',3},
            {'PartTwo',1}]}.
```

and `'Spin'/4` has the bare operands the ticket recorded:

```erlang
  {label,8}.
    {gc_bif,'+',{f,0},4,[{x,0},{x,1}],{x,0}}.
    {allocate,4,4}.
```

This is the difference the ticket observed, and its cause: an exported `Spin` may be called by
anyone, so the optimiser assumes nothing about its arguments. The Erlang, Elixir and Gleam sources
all keep `spin` local (`bench_erl.erl` line 2 exports `part_two/1` only;
`bench_ex.ex` lines 2 to 23 are `defp`; `bench_gleam.gleam` lines 1 to 36 are `fn` without `pub`),
so the benchmark compared three private loops with one public one.

### 5. Timed

All five modules loaded in one VM, 25 runs a round, six rounds, the order reversed on even rounds.
Minimum of each round in ms, then the best of the six.

```
Erlang                   9.40  9.18  8.93  8.91  8.91  9.22    8.91  1.00x
beam-sharp today         9.53  9.51  9.05  9.02  9.06  9.13    9.02  1.01x
beam-sharp all public    9.68  9.71  9.33  9.66  9.39  9.66    9.33  1.05x
Erlang +no_type_opt      9.57  9.54  9.08  9.30  9.48  9.31    9.08  1.02x
beam-sharp at 18ca054    9.52  9.53  9.37  9.38  9.19  9.10    9.10  1.02x
```

A second full run of the script gave 1.00, 1.01, 1.05, 1.02 and 1.06 in the same row order. One
implementation's own rounds spread by about 5% (Erlang: 8.91 to 9.40), so only the first two rows
can be told apart from the rest with any confidence, and they cannot be told apart from each other.

What this does and does not show:

- **Today's beam-sharp and Erlang are level**, which follows from section 1: the five functions on
  the hot path are the same code.
- **On x86_64 the August module is not 20% behind either.** Neither is Erlang with every annotation
  removed. So on this machine the annotations are worth about 2%, and the 20% the ticket recorded
  on Apple Silicon was not reproduced here for any module, old or new. Whether the arm64 JIT
  makes more of the annotations than the x86_64 one was not measured: no arm64 machine was
  available.
- **The four `is_integer` tests of the all-public build cost about 4%**, at the edge of what this
  harness resolves.

### Not measured

- Anything on Apple Silicon, the architecture the ticket's numbers came from.
- Elixir and Gleam. The ticket's table puts them within 3% of Erlang; Erlang is the control here.
- Records and dispatch, which the ticket's §3.4 names as never measured. They still are not.
- `bin/check-shell.sh` over the probe script: `shellcheck` is not installed in this sandbox.
