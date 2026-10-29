# Decision brief: ticket 39, emitted-code quality (Linear ENG-211)

Date 2026-10-29. **DECISION OPEN — for human review.**
Ticket: `wayfinder/issues/39-emitted-code-quality.md`. Probes: `artifacts/probes-39/` (README.md maps claim to dir; `run_all.sh` re-runs all).

Toolchain for every MEASURED-HERE row: OTP 25 / compiler-8.2.6.3, `emu_flavor=jit`, Elixir 1.14.0, Gleam 1.12.0. This box is a slow VM (the loop takes ~17 ms, not 5 ms), so only ratios transfer. Input is synthetic (4732 rotations, sum |d| = 673,364, seeded), because the real AoC input is not in the repo; the answer is 6725, not 6770. `bsc` cannot run here, so every claim about what bsc emits is a stand-in or RECORDED.

## Headlines (read these first)

1. **The ticket's premise cannot be re-tested here and one half of it is wrong on this toolchain.** On OTP 25, none of the abstract-form shapes bs_emit plausibly produces (remote-call `rem`, widened `-spec`, the F42 return guard) changes the instruction list or any `{tr,..}` annotation, or the time (rows 5-6). I could not reproduce "bare `{x,0}`" from the emitter's shapes. Separately, "all four languages emit identical bytecode" is false for Gleam here: Gleam 1.12 passes `inline`, folds `wrap`/`hit` into `spin`, and runs at 0.61x of Erlang (rows 11-12).
2. **Annotations do cost time, and the cost depends on inlining.** Stripping `{tr,..}` from otherwise identical code costs +5.5..8% as the benchmark is written and **+25%** once the loop is inlined (rows 1-3). The ticket's 20% is the size you get when the loop is tight, which is consistent with the ticket's guess but is not proof that bsc loses annotations.
3. **The bigger lever is inlining, not types.** `erlc +inline` on the same source is 0.57x; on the B#-shaped forms it is 0.63x (rows 11, 13). bsc passes no `inline` (`compiler/src/bsc.erl:845`). That is one atom.
4. **Ticket section 2's thesis does not hold for this loop.** The checker does not hold `0..99` for `Wrap`: `bs_check.erl:4333` says "Arithmetic returns `int`, not an exact interval" (RECORDED, not re-run). And on OTP 25 even a proven range cannot be handed to the optimiser through a `-spec` or a relational guard (rows 7-9). B# is not "throwing away" a fact here; it never had it.
5. **The benchmark is stale.** It was taken 2026-08-15. It predates F24 (08-23), F26 `%` (08-25), F37 (09-08) and F42 (09-11, which wraps every foreign call, including `:erlang.rem`, in `case Call of V when is_integer(V) -> V end`; `bs_emit.erl:1259-1266`). Nobody has re-run `aoc/bench/` against current bsc (grep of tickets and F-files found none).

## What is actually being asked, gating question first

1. **(Gating) Does current bsc output differ from `bench_erl` in `{tr}` annotations at all?** Everything else depends on it. Nothing here can answer it. It needs one run on a box with bsc: `bsc` on `aoc/bench/Day01`, then `erlc -S` on the `.abstr` and on `bench_erl.erl`, and diff `var_info`/`{tr}` (command under Option A).
2. If yes: which emitted construct removes them (section "Limitations"). If no: the 20% on OTP 28 is something else (OTP 28 differences, harness state), and the ticket's cause is wrong.
3. Independent of 1-2: should bsc pass `inline`? Which stack-trace behaviour does B# promise? (Option B.)
4. Only then: is checker interval arithmetic (ticket 20's "stronger fact") worth building for speed? (Option C.)

## Evidence table

All paths are under `artifacts/probes-39/`. Min/median over 301-401 interleaved repeats; "copy" is a negative control (the same variant built twice under two module names).

| # | Probe | Claim | Result | Label |
|---|---|---|---|---|
| 1 | `a/cmp.out` | Stripped variant has the same instructions as the original | 116 vs 116 instrs, equal after dropping `{tr}`; 8 vs 0 `{tr}` operands; Type chunk 116 B vs 26 B. `var_info` comments are not encoded (strip_vi leaves the chunk at 116 B), so `{tr}` operands are the whole difference | MEASURED-HERE |
| 2 | `a/run1.out`, `run2.out` | Stripping `{tr}` slows the loop | strip 1.053-1.057x (min), 1.051-1.062x (median) vs original; run2 reversed order: original 0.922-0.933x of strip. **Copy controls: erl_a vs erl_b 0.994x, strip_a vs strip_b 1.004-1.006x** | MEASURED-HERE |
| 3 | `d/time_inline_strip.out` | Same experiment on the inlined loop | inl_a 10.00 ms, stripped 12.53 ms = **+25%**; copies inl_b 0.998x, inls_b 1.000x of their twins | MEASURED-HERE |
| 4 | `a/strip_*.escript` method | How "stripped" was built | `erlc -S`; `file:consult` the .S; replace every `{tr,R,T}` by `R`; recompile the .S with `erlc`. Same bytes otherwise | MEASURED-HERE |
| 5 | `a2/cmp_fn.out` | The shapes bs_emit produces keep instructions and annotations | `wrap` 8, `hit` 10, `spin` 26 instrs identical **with** annotations to `bench_erl`, for `sh_op`, `sh_remote` (rem as `erlang:rem/2` call), `sh_spec` (+7 widened specs), `sh_guard` (+F42 return guard). `clicks`/`part_two` differ only because B#'s `Sign`/`Size` are guard clauses | MEASURED-HERE (stand-ins, not bsc) |
| 6 | `a2/time_shapes.out`, `a3/` | ...and the time | all four shapes 0.986-1.001x of erl_a (min); strip_a 1.055x. `a3`: `compile:file(.abstr,[from_abstr,debug_info])` == `compile:forms` for the same forms | MEASURED-HERE |
| 7 | `b2/ranges_ann.out` | What gives `{t_integer,{Lo,Hi}}` on OTP 25 | `band 127` -> `{0,127}`; `rem 100` -> `{-99,99}`; `=:= 3 ; =:= 4` -> `{3,4}`. **`-spec f(0..99)` -> `any`; guards `X >= 0, X =< 99` -> `any`** (also as a body `case`, and as a return-position guard) | MEASURED-HERE |
| 8 | source reading | Why | `beam_ssa_type.erl:2260-2370`: `infer_type/4` has clauses for `succeeded`, `is_tagged_tuple`, `is_nonempty_list`, the `is_*` tests and `=:=` (2329, 2358); the catch-all is at 2370, so `<`, `>=`, `=<` narrow nothing. Ranges come only from BIF result types (`beam_call_types.erl:358-360`, `:987-992` for `rem`). `-spec` is not read by the pass (`grep spec beam_ssa_type.erl` finds only its own specs). OTP 26+ may differ; not checked | MEASURED-HERE (source of 25) |
| 9 | `b/ann_spin.out`, `time1.out`, `time2.out` | A range reaches `spin` only through an op the optimiser understands | start position as a parameter: `b_unk` bare `{x,0}` (exactly the ticket's shape); `+ is_integer` guard -> `{t_integer,any}`; `+ range guard` -> `any`; **`P band 127` after the guard -> `{-99,127}`**. Time, run 2, rel to b_unk_a: const 0.96, band 0.96, unk copy 0.98, kind 1.01, guard 1.01 (guard copies agree to 0.1%). Run 1 (rel const): unk 1.02-1.05, kind/guard 1.07, band 1.00. Copy spread of the unk pair is up to 2.7%, so unk-vs-band is at the noise margin; kind/guard-vs-band (6-7%) is not | MEASURED-HERE |
| 10 | `e/time_guard_*.out` | Emitted guards on a private hot function | restating a known range (`Pos >= -99, Pos =< 99`): **folded away at compile time** (same `is_ge` count, 0.99x). A real extra test (`Left >= 0, Left =< 1000000`, 2 more tests in the module): 0.99x, i.e. no measurable cost, no typing benefit | MEASURED-HERE |
| 11 | `d/time_langs.out` | Cross-language | erl_a 17.62, Elixir 0.98x, **Gleam 0.61x**, `erlc +inline` **0.57x**, sh_remote 0.995x, **sh_remote + inline 0.63x** | MEASURED-HERE |
| 12 | `c/gl/out_tr.txt`, `c/gl/build/.../bench_gleam.erl` | Gleam is not instruction-identical here | generated .erl has `-compile([no_auto_import, ..., inline])` (line 2), wide `integer()` specs on every function, `N rem 100` as an operator. Compiled beam: no `wrap` function, `spin` has 8 `{tr}` operands vs 4 in Erlang's | MEASURED-HERE |
| 13 | `c/ex/out.txt` | Elixir | `rem` is an operator in the abstract code, **no specs** on `defp`, only `[:no_auto_import]`; 4 `{tr}` in `spin`, 3 in `wrap` (Elixir: no source installed, behavioural evidence only) | MEASURED-HERE |
| 14 | `c/gl3` | Gleam `%` and `/` | literal divisor: `N rem 100` bare; variable divisor: `case D of 0 -> 0; Den -> N rem Den end`. A range guard `n >= 0 && n <= 99` carries no range in the beam either (`bounded/1`: untyped `{x,0}`) | MEASURED-HERE |
| 15 | `f/out.txt` | Cost of `inline` | `g/1` raising inside `f/1`: without inline the trace is `[g, f, ...]`; with `+inline` it is `[f (line 3), ...]`, the callee's frame is gone | MEASURED-HERE |
| 16 | `beam_validator.erl:2553-2556`, `beam_asm.erl:433-441` | Who checks a `{tr}` claim | validator unpacks a `#tr{}` to its register and drops the type; assembler encodes the claimed type into the Type chunk. A false claim would be trusted by the JIT. I did not test a false claim | RECORDED from source, not run |
| 17 | `bs_emit.erl:335-350`, `:331` | F24/F37 guards are on exported functions only | RECORDED in the repo, not re-run |
| 18 | Elm | | Elm: not probed (not installed) | n/a |

## Options

The program under test (from `aoc/bench/Day01/bench_bs.bs`), unchanged under A and B:

```
private int Wrap(int n)
Wrap(n) -> :erlang.rem(:erlang.rem(n, 100) + 100, 100)

private (int, int) Spin(int pos, int step, int left, int zeros)
Spin(pos, step, 0, zeros) -> (pos, zeros)
Spin(pos, step, left, zeros) ->
    var next = Wrap(pos + step)
    Spin(next, step, left - 1, zeros + Hit(next))
```

### Option A: do nothing in the emitter; take the gating measurement first

Compiler delta: none. The work is one run on a machine with bsc and OTP 28:

```
cd aoc/bench && bash build.sh                       # builds with current bsc
bsc -o /tmp/d Day01 && erlc -S /tmp/d/Day01.abstr   # or: compile:file(.., ['S'])
erlc -S bench_erl.erl
diff <(grep -E 'var_info|\{tr,' Day01.S) <(grep -E 'var_info|\{tr,' bench_erl.S)
erl -noshell -pa ebin -s bench main ../2025/day01/input.txt
```

Measured support: rows 5-6 say the current emitter's shapes do not remove annotations on OTP 25; row 2 says the effect is real if they were removed.

Strongest counterargument: it leaves 6-25% (rows 2-3) and ~37% (row 11) on the table and the ticket stays open on an unmeasured premise. And it spends nothing on the one thing David can see running today.

### Option B: pass `inline` to the Erlang compiler

B# source is unchanged; what changes is what runs. Delta, concrete: add the atom `inline` to `Options` in `bsc.erl:845` (`[from_abstr, debug_info, inline, ...]`), or emit `{attribute, ?A, compile, [inline]}` in the header list at `bs_emit.erl:73-78`. The attribute form also applies to anyone compiling the `.abstr` with plain `erlc`, which is the "`.abstr` plus external erlc always works" promise at `bsc.erl:838`. Gleam already ships exactly this (row 12).

Measured: B#-shaped forms 17.54 ms -> 11.04 ms (0.63x), Erlang source 0.57x, Gleam 0.61x (rows 11-12). It also makes the annotation question matter more (row 3: +25% if lost).

Strongest counterargument: **stack traces lose frames** (row 15). A B# runtime error inside a small `private` function is reported against its caller. B# has `function_clause`-shaped crash behaviour recorded in F37 (`crashed: error:function_clause`) and a diagnostics tradition (F16); whether any test or promise reads the callee name is unchecked here. Second: the ticket's own OTP 28 table shows Gleam within 3% of Erlang, which is irreconcilable with Gleam being 0.61x here. Either Gleam 1.18.1 stopped passing `inline`, or OTP 28's compiler changed what `inline` does. So the size of this win on the target toolchain is **unproven**; the sign probably transfers, the 37% may not.

### Option C: build the "stronger fact" and carry it (ticket section 2)

B# program that compiles under C and is refused today:

```
type Cell = int where value >= 0 and value <= 99

private Cell Wrap(int n)
Wrap(n) -> (n % 100 + 100) % 100          // today: `int` is not a Cell; bs_check.erl:4330-4335 types % and + as int

private (Cell, int) Spin(Cell pos, int step, int left, int zeros)
```

Compiler delta: (1) `bs_check.erl` `op_type/1` becomes interval arithmetic: `% k` with a literal positive divisor gives `-(k-1)..k-1`, `+` adds intervals, and the checker needs a sign-aware `%` to get `0..99` from `(x % 100 + 100) % 100`; (2) an emitter step that hands the range to OTP. The only carriers measured to work are ops: `band` (nonnegative power-of-two-minus-one masks) and `rem` (symmetric). For `0..99` there is no exact carrier; row 9 shows `P band 127` gives `-99..127` at the join, recovers the const-50 speed, and costs one `band` per public call. Guards (what F37 emits at the exported boundary) are not carriers on OTP 25 (rows 7-10) and cost nothing, so emitting them for speed buys nothing.

Strongest counterargument: **for this loop it adds nothing**. OTP already infers `-99..99` for `Pos` from the `rem` chain in the body (row 5, `bench_erl` annotations), so the B# fact is redundant exactly where the benchmark looks. The facts only B# has (a declared `Octet` parameter, a record field range) live at exported boundaries, and there F37 already emits the guard, which feeds OTP nothing on 25 (row 7). So C is a large checker change (`op_type`, plus F2/F26 divisor tests, plus the exhaustiveness consequences of arithmetic now producing intervals) whose speed payoff is unshown anywhere in this evidence. It may still be right for exhaustiveness reasons; this brief says only that speed is not one of them.

## Recommendation

Do A first (one command on the box that has bsc), because everything in the ticket hangs on the unmeasured premise and the benchmark is two months and four features stale. Then decide B on that box's OTP 28 numbers: it is the only change with a measured effect larger than the gap, and costs one atom; settle the stack-trace promise before taking it. Do not start C for speed.

## Limitations

- **bsc cannot be built here** (repo pins OTP 28; lexer needs OTP 27+ leex). Every "shape" row is a stand-in built by rewriting Erlang forms to mimic `bs_emit.erl:1133-1150` and `:1259-1266`. I did not diff bsc's real `.abstr`, so the actual source of "bare `{x,0}`" is unlocated. Candidates not excluded: OTP 28 behaviour; something in real bsc output absent from my stand-ins.
- **OTP 25, not 28.** Relational narrowing, `inline` behaviour and JIT specialisation may differ on 28 / Apple Silicon. The beam_ssa_type claim (rows 7-8) is a statement about 25 only. The percentage effects here (6%, 25%, 37%) are x86 ratios on a slow VM.
- **Which annotation matters** was not localised. I stripped all `{tr}` at once. I did not strip per-function, and I did not test why the JIT is faster with them (no JIT source read).
- **Gleam 1.18.1 / Elixir 1.19.5 not available**; Elixir has no .ex sources installed, so row 13 is behavioural.
- **Synthetic input** (row 6 answer 6725). The distribution of rotation sizes differs from the real puzzle (one rotation is 5020 clicks), but per-click work is identical.
- Elm: not probed (not installed). `fib` workload and records/dispatch (ticket section 3.4) not re-run.
- A forged `{tr}` claim was not tested (row 16).

## Probe index (exact commands, from `artifacts/probes-39/`)

```
bash run_all.sh                                   # everything, ~15 min; set GLEAM=<path to gleam 1.12 binary>
# or by claim:
cd a  && escript cmp.escript ebin/erl_a.beam ebin/strip_a.beam                      # rows 1,4
cd a  && erl -noshell -pa ebin -eval 'timeit:main(["input.txt","301","erl_a","strip_a","erl_b","strip_b"])'   # row 2
cd a2 && escript mk_shapes.escript . && escript cmp_fn.escript ../a/ebin/erl_a.beam sh_guard.beam wrap hit spin clicks part_two   # row 5
cd a2 && erl -noshell -pa ../a/ebin -pa . -eval 'timeit:main(["../a/input.txt","301","erl_a","sh_op","sh_remote","sh_spec","sh_guard","strip_a"])'  # row 6
cd a3 && escript via_abstr.escript                                                   # row 6
cd b2 && erlc -S ranges.erl && escript ann.escript ranges.S                          # row 7
cd b  && bash mk.sh && for m in b_const b_unk_a b_kind_a b_guard_a b_band_a; do escript ann.escript $m.S | grep ^spin; done   # row 9
cd b  && erl -noshell -pa . -eval 'timeit:main(["../a/input.txt","301","b_const","b_unk_a","b_unk_b","b_kind_a","b_guard_a","b_guard_b","b_band_a","b_band_b"])'
cd e  && bash mk.sh && erl -noshell -pa . -eval 'timeit:main(["input.txt","301","e_base_a","e_left_a","e_base_b","e_left_b","e_guard_a"])'   # row 10
cd d  && erl -noshell -pa . -eval 'timeit:main(["input.txt","201","erl_a","erl_inl","bench_gleam","Elixir.BenchEx","sh_remote","sh_remote_inl"])' # row 11
cd d  && erl -noshell -pa . -eval 'timeit:main(["input.txt","301","inl_a","inls_a","inl_b","inls_b","erl_a"])'   # row 3
cd c/gl && $GLEAM build && escript tr_count.escript build/dev/erlang/bench_gleam/ebin/bench_gleam.beam     # row 12 (project has no deps; hex is unreachable)
cd c/ex && elixirc -o . bench_ex.ex && elixir ex_probe.exs                           # row 13
cd f  && bash run.sh                                                                 # row 15
```
