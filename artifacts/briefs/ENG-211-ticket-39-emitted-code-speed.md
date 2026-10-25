# Ticket 39 (ENG-211): why is instruction-identical code 20% slower, and what is the ceiling?

**State: open. Nothing here resolves it.** Written 2026-10-25 from `artifacts/probes/39/`; the verifier's report is `artifacts/verification/ENG-211.md`.

## The question, asked alone

Gleam is 11% faster than Erlang, Elixir and beam-sharp on this loop, and the cause is one compile attribute. **May a private function disappear from the compiled module, and from crash stack traces, in exchange for about 12% on call-heavy code?** The speed is available; this is the price.

## The ticket's premises, re-measured

Machine: x86-64 Xeon @ 2.1 GHz, 4 vCPU. The ticket's numbers came from Apple Silicon, so absolute times and possibly ratios differ. Same OTP (28, erts-16.4); Elixir 1.20.4 against 1.19.5, Gleam 1.19.1 against 1.18.1. The harness is `aoc/bench/bench.erl`, unmodified, on the repo's own `input.txt`; all four return 6770.

**1. The 20% gap to Erlang does not reproduce here.** Six runs of the harness, min ms: Erlang 12.68 to 12.95, Elixir 12.65 to 12.81, beam-sharp 12.81 to 13.24, **Gleam 11.32 to 11.41**. beam-sharp is about 1% behind Erlang. The outlier is Gleam, 11% *ahead* of all three (`p39_four.sh`).

**2. The ticket's observation (`{tr,…}` missing in beam-sharp's `Spin`) does not reproduce.** Listings of `Spin/4` from Erlang source and from beam-sharp's emitted forms (`asm_of.escript`, `asm_fn.escript`): **identical, operand types included** (`{tr,{x,0},{t_integer,{0,99}}}` in both); the only differences are the label numbers of the two callees. OTP's analyser infers `0..99` for beam-sharp's code unaided, so the §2 tension (a mandatory signature discarding the range) does not appear in the emitted code of this loop.

**3. Gleam's lead is `-compile(inline)`.** Gleam's forms carry `[no_auto_import, nowarn_*, inline]`; its `Spin` has `Wrap` and `Hit` inlined (28 listing lines against beam-sharp's 30; no call to either). One factor changed at a time, each variant in its own VM, 8 interleaved rounds (`p39_inline.sh`), median of per-VM minimum, ms:

| variant | ms | against the unmodified Erlang |
|---|---|---|
| Erlang (`bench_erl.erl`) | 12.72 | |
| Erlang, `+inline` | 11.39 | **−10.4%** |
| beam-sharp, forms as emitted | 12.82 | +0.8% |
| beam-sharp, `inline` added to its forms | 11.53 | −9.4% |
| Gleam as built | 11.37 | −10.6% |
| Gleam, `inline` stripped from its forms | 12.73 | +0.1% |

Stripping it from Gleam removes Gleam's lead; adding it gives Erlang and beam-sharp the same lead. The control `Gleam as built` recompiled through the same path matches the shipped `.beam`'s time. About 1% remains between beam-sharp and Erlang under inline (11.53 against 11.39); it is not explained.

## What the emitter would need

`bs_emit:forms/1` (`bs_emit.erl:31`) emits no `-compile` attribute and `bsc:build/3` passes `[from_abstr, debug_info, …]` (`bsc.erl:843`). Two prototypes of the real emitter, each compiling `aoc/bench/Day01`:

```erlang
{attribute, ?A, compile, [inline]}                                              % I1, module-wide
{attribute, ?A, compile, [{inline, [{Name, Arity} || F <- Fns, not is_public(F)]}]}   % I2, private only
```

Patches `v39-I1`, `v39-I2`; one and two added lines, after the `export` attribute at `bs_emit.erl:76`.

| build | ms (median of 8) | against unpatched |
|---|---|---|
| unpatched | 12.88 | |
| **I1** | 11.54 | **−10.4%** |
| **I2** | 11.31 | **−12.2%** (about Gleam's 11.37; see the next paragraph) |

Two verifier findings qualify the table. (a) Under a module-wide `inline` attribute the emitted `Wrap` stays a call (bsc lowers it as `case erlang:rem(..)`); only `Hit` is inlined, whereas Erlang and Gleam inline both. That is why beam-sharp+inline (−9%) trails Erlang+inline (−12%) in the earlier table. (b) I2's list includes the recursive `Spin` and `Clicks`, so `Spin` is unrolled once (46 listing lines against 27), which probably explains I2 sitting 1 to 2% ahead of Erlang+inline. "Faster than Gleam" is inside the noise and partly an unrolling effect. The verifier's own runs (pinned core) put Erlang+inline at −12.1%, I1 at −9.7% and I2 at −13.8%: about two points either way from mine, same order.

## What it costs (`p39_cost.sh`, `p39_trace.sh`, `eunit_variant.sh`)

- **Size**: 22 example modules (the probe's "25 modules, 3 fail" is wrong: two are `aoc/*/Day01` paths outside `--src-root`, one is a namespace directory, none a real compile failure; the benchmarked `Day01` is not in the total), 54364 bytes unpatched, 54608 (+0.45%) with I1, 54744 (+0.70%) with I2.
- **Compile time**: 9.6 to 9.9 s for the same 25 `bsc` invocations (22 of them compiling) in every build, VM boot included; no difference measurable.
- **Stack traces.** A crash inside a small private function, called from a public one (`First` / `Run`):

  | build | frames |
  |---|---|
  | unpatched | `erlang:hd/1`, **`T:First/1` line 8**, `T:Run/1` line 11 |
  | I1, I2 | `erlang:hd/1`, **`T:Run/1` line 8** |

  The `First` frame is gone, and the surviving frame names `Run` with `First`'s source line. F15's guarantee that a crash names the `.bs` file and line still holds; the *function* named is wrong.
- **A test fails, for a reason that generalises.** `repl_tests:a_private_function_is_refused_by_name_at_the_prompt_test` (the only new failure; `compiler/test` is 1493 passed / 5 failed against the baseline's 1494 / 4). `bs_run:private_names/2` (`bs_run.erl:75`) and the REPL (`bs_repl.erl:39`) learn a module's private functions from `module_info(functions)`. An inlined private function whose every call site was inlined is deleted from the module, so `bsc Mod Half 4` stops saying *"Half is private"* and says *"no such function"*. That is F12's message, lost.

## Options

### 1. Inline the private functions (I2), and keep their names

I2 plus a way for `private_names/2` to find private functions that are no longer in the module. The precedent is F55's `'bs@type_atoms'/0`, a compiler-owned export (`bs@` prefix); an attribute such as `-bs_private([{Name,Arity}])` would do and costs bytes (ticket 52's probe: about 50 bytes per `{app, "vsn"}` entry; a list of name/arity pairs was not measured). Not built: only the failure it must fix is measured.

Measured: −12.2%, +0.7% size, no compile-time change. **Open cost**: the lost frame (above).

**Strongest counterargument.** Debuggability is what a language with "a crash names the `.bs` file" (F15) promises, and the frame names the wrong function. The language's authors will read these traces and so will agents; a trace that says `Run` for a crash in `First` is the kind of plausible-looking wrong answer ticket 39 itself warns about.

### 2. Inline module-wide (I1)

Same, `[inline]`. Measured −10.4%. It also inlines public functions into their in-module callers; they stay exported so the module and the REPL are unaffected, but their frames vanish from in-module call chains too.

**Strongest counterargument.** It gains less than I2 (−10.4% against −12.2%) and loses more traces. Nothing measured recommends it over I2.

### 3. Emit nothing; record the finding

beam-sharp is within about 1% of the same source written in Erlang. Gleam's lead is a compile option it chooses; anyone can have it.

**Strongest counterargument.** It leaves 12% on the table against the one comparison the repo has, on code written the way B# encourages (small private helpers), and the fix is two lines.

## The ceiling

**Inline is the whole of the first step; beyond it the ticket's hope holds but the mechanism it names is not the one.** The ticket expected the ceiling to be above Erlang's because the checker holds exact intervals the OTP analyser must reconstruct. In this loop OTP reconstructs them anyway (finding 2), so passing ranges through the Abstract Format would add nothing it lacks.

What would lie above: a hand-specialised Erlang version of the same loop, using one fact (`pos` is `0..99`, `step` is `-1|1`, so `pos + step` is `-1..100`) to replace `((n rem 100) + 100) rem 100` with a two-way fix-up (`artifacts/probes/39/oracle/oracle.erl`), **2.61 ms against 11.36 for Erlang with inline: 4.4 times faster** (`p39_ceiling.sh`), same answer 6770. Read it as an upper bound only:
- it is hand-written, not an emitter output, and it uses only facts the BEAM compiler already prints for itself (`pos` in `0..99`, `step` in `-1..1`) plus a range-based `rem` rewrite that no existing pass performs. It therefore says nothing about what B#'s type system could add; the verifier re-checked its answers against `bench_erl` and `Day01` on 300 random inputs, 0 mismatches;
- B# does not hold the fact for this program: every parameter is declared `int`, so the checker never sees `0..99`. An author would have to write `type Pos = int where value >= 0 and value <= 99` through the signatures;
- even with that, no pass turns an interval into a cheaper `rem`. That pass is the unbuilt work, and nothing in the repo measures what it costs to build or what it breaks.

## Recommendation

**Option 1**, after David decides the gating question in the affirmative: accept a missing private frame for 12%. If traces matter more, **option 3** and close the ticket as "beam-sharp equals Erlang; Gleam inlines". The measured numbers do not favour option 2.

A test either way: pin the trace behaviour (a crash inside a private helper) so the choice is visible instead of discovered.

## Not re-measured

- §3 item 4 (`fib(100,000)`, a dead heat) and the record/dispatch workload (the tag guard) were not re-run; this brief says nothing about them.
- That inline explains the *ticket's* numbers. There Gleam led Erlang by about 3%, here by 12%; no probe tests the Apple Silicon case.
- No Apple Silicon. If the 20% is real there, the cause above may still apply, but it has not been shown to.
- The unexplained 1% between beam-sharp and Erlang under inline.
