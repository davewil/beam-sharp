# Decision brief: ticket 39, emitted-code quality (Linear ENG-211)

Ticket: `wayfinder/issues/39-emitted-code-quality.md`. Status left open. Nothing in the ticket, Linear or git was changed.
All probes ran on this host: OTP 25 (erts-13.2.2.5, x86_64 JIT), Elixir 1.14, Gleam 1.12.0, 4 cores, shared VM. The ticket's numbers
are OTP 28 / Apple Silicon / Gleam 1.18.1. **Nothing here measures that platform.**

## Question

The ticket says beam-sharp's hot integer loop is ~20% slower than Erlang, Elixir and Gleam with identical bytecode. It names the
cause as missing `{tr,...}` type annotations on operands, and says the language "knows" the `0..99` range and throws it away at
emission. It asks what the cause is and, more importantly, what the ceiling is. On this host the gap does not reproduce against
Erlang, the annotations are identical, and the annotations turn out not to matter. The ceiling lever that does exist is `inline`,
which Gleam already uses and `bsc` does not.

## Sub-decisions (gating first)

1. **Gating: is emitted-code speed a thing `bsc` tunes now, and is the target "equal to `erlc` defaults" or "equal to Gleam"?**
   Everything else follows from this. If the answer is "equal to erlc defaults", this ticket closes as a baseline (Option A).
2. Given a yes: where does `inline` live, in the forms (`-compile(inline)`) or in `bsc`'s option list?
3. Given a yes: does the private-function record tag guard (F3.9 / ticket 18) stay? This is a new finding, see Measurements 4.

Question 2 is the only one asked in the options below. Question 3 belongs to ticket 18's tier argument and is raised there, not here.

## Evidence table

| # | Claim | Probe | Result | Status |
|---|---|---|---|---|
| 1 | bs hot loop is ~20% slower than Erlang/Elixir/Gleam | `01-rebench.sh` (repo's own harness, unmodified), `04-shuffled.sh` | unmodified harness, 3 runs: bs 1.14x, 1.28x, 1.20x vs fastest. Shuffled, fresh-process, 150 rounds: bs 9.59/9.01 min, Erlang 9.58/9.03, Elixir 9.57/9.00. **No gap vs Erlang/Elixir.** Gleam is 12% faster (7.9) | **NOT REPRODUCED on this host** (OTP 25, x86_64; noise-dominated, the unmodified harness gave 1.20x and 1.28x in two of three runs). UNVERIFIED on OTP 28 / Apple Silicon |
| 2 | The 20% is one implementation's property and not the machine's | `05-order.sh` | same bs build called three times in a row in the original protocol: 11.32, 9.23, 8.95 ms min; another run 11.51, 11.44, 11.18; another 11.48, 11.48, 11.87. Bimodal ~9.0 / ~11.5 ms (27%), independent of implementation | VERIFIED that host noise of the ticket's size exists here. Not shown to be the cause on the ticket's machine |
| 3 | `Wrap`/`Hit`/`Spin` disassemble identically | `02-asm-diff.sh`, `03-hot-diff.py` | identical after renaming labels and functions, including every `{tr,..}` and `var_info`. Extra function `bs@type_atoms/0` only. **Note:** `03-hot-diff.out` literally prints DIFFERENT for all three, because my script compares the function-name atoms too; the printed bodies differ only in `bench_erl`/`wrap` vs `'Day01'`/`'Wrap'` | VERIFIED (OTP 25) |
| 4 | Erlang has `{tr,{x,0},{t_integer,{0,99}}}` where bs has bare `{x,0}` | same | **Not reproduced.** Both have `{t_integer,{-99,99}}` for Spin's arg and `{1,199}` inside Wrap. OTP 25 infers `rem` as -99..99. `{0,99}` needs a newer OTP | **REFUTED on OTP 25**; OTP 28 UNVERIFIED |
| 5 | Missing annotations cause slowness | `06-variants.sh`, `07-tr-count.sh` | `+no_type_opt` removes all 8 `{tr,` and 11 `var_info`. Erlang 9.01 -> 9.07 ms min, bs 9.03 -> 9.12. **No effect** | **REFUTED on OTP 25.** The ticket's §3.2 experiment, done |
| 6 | `-spec` narrowing carries a B# range into the optimiser | `08-carry-ranges.sh`, `11-refined-range.sh` | `-spec wb(integer()) -> 0..99` leaves `wb` asm unchanged. B# `type Pct = int where ...` emits `-> 0..99` and the asm after the `Clamp` call says `{t_integer,any}` | VERIFIED: specs are not read by the OTP 25 optimiser |
| 7 | A result guard does carry a range | `08-carry-ranges.sh` | `case .. of R when R >= 0, R < 100` compiles to `{test,is_ge,..,[{tr,{x,0},{t_integer,{0,99}}},{integer,0}]}`. The `< 100` test was proved redundant and dropped; `>= 0` was kept | **NOT CONFIRMED (verifier, 2026-09-30).** The tested value `((N rem 100)+100) rem 100` is already inferred 0..99 by the optimiser, so `< 100` is dropped as redundant, not because the guard carried a range. With an opaque value both tests are kept and the following `+` carries no `{tr}`. The recommendation does not rely on this row |
| 8 | The mandatory signature means B# knows a stronger fact than Erlang (ticket §2) | read `aoc/bench/Day01/bench_bs.bs:8-10`, `11-refined-range.sh` | `Wrap` calls FFI `int rem(int,int)`, so B# holds `int` for its result and **no interval**. Only a hand-written refinement like `Clamp` gives B# `0..99`, and that reaches the spec only (row 6) | **REFUTED for Day01**: B# has no stronger fact here |
| 9 | Gleam's bytecode is identical to the others | `12-survey-options.sh` | Gleam `spin/4`: 25 instrs, 1 local call (self). Erlang/Elixir/bs: 26 instrs, 3 calls. Gleam's generated `.erl` line 2 carries `inline` | **REFUTED** (ticket says "all four") |
| 10 | `inline` is the speedup | `06-variants.sh`, `17-inline100.sh` | Erlang +inline 9.01 -> 7.93 ms min (-12%), bs 9.03 -> 8.12 (-10%); both land on Gleam's 7.9-8.0 | VERIFIED (OTP 25) |
| 11 | `inline` can travel inside the forms | `13-inline-as-attribute.sh` | `{attribute,0,compile,inline}` in the `.abstr`, compiled with no inline option: compiles, 28 instrs, p25 10.46 vs 11.63 ms | VERIFIED |
| 12 | Crash frames change under `inline` | `15-stacktrace-under-inline.sh` | `function_clause` inside `h/1` gives `[{st,h,[0],..},{st,f,1,..}]` without inline and `[{st,'-inlined-h/1-',[0],..}]` with it; the caller frame is gone | VERIFIED |
| 13 | bs `Wrap` is not inlined at default size | `14-inline-threshold.sh` | bs keeps `call Wrap/1` at `inline`, `{inline,40}`, `{inline,60}`; Erlang inlines it. The FFI result `case .. when is_integer(bs@rv0)` (`bs_emit.erl:1241-1249`) enlarges it. `{inline,100}` inlines it in bs | VERIFIED |
| 14 | `{inline,100}` beats plain `inline` for bs | `17-inline100.sh` | p25 9.62 vs 9.91 ms, min 7.90 vs 8.14; iqr ~2.1 ms | **UNVERIFIED**: the difference is inside the spread |
| 15 | Exported int guards cost something | `10-public-int-guards.sh` | every function `public`: 9.18 vs 9.03 ms min, p25 11.25 vs 11.06 | VERIFIED: +1-2%, inside noise |
| 16 | The record tag guard is free / unmeasured | `09-record-guard-cost.sh` | see Measurements 4. **It is not free.** | VERIFIED: ~1.9x on a loop that only reads one field |
| 17 | The ticket's 26 instruction count / `A =:= B` claim | `03-hot-diff.py` | holds for wrap/hit/spin here | VERIFIED (OTP 25) |

## Survey

Erlang, Elixir and Gleam compiler sources are not installed here ("not available"), so no file:line into them. What can be read is
the output of each toolchain.

- **Erlang**: `bench_erl.beam` compile_info `options=[]` (`12-survey-options.out:1`). No inline by default.
- **Elixir**: `Elixir.BenchEx.beam` compile_info `[no_spawn_compiler_process,from_core,no_core_prepare,no_auto_import]` (`12-survey-options.out:4-5`). No inline. Its `spin/4` has 3 local calls.
- **Gleam**: generated `build/gleam/build/dev/erlang/bench_gleam/_gleam_artefacts/bench_gleam.erl:2` is
  `-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).` Its `spin/4` has 1 call.
  That line is the whole reason Gleam is the fast one of the three. The Gleam compiler itself is a binary, so whether this is
  deliberate is not checkable here.
- **Elm**: not BEAM, not relevant.
- **beam-sharp**: `bsc.erl:843` passes `[from_abstr, debug_info, {outdir, Dir}, report_errors, report_warnings]`. `bs_emit.erl:73-76`
  builds the module and export attributes and is where a `compile` attribute would go.

## Measurements

All min and p25 in ms, 150 shuffled rounds, each sample in a fresh process (`bench2.erl`). iqr is the p25-p75 spread, about 1 ms.

1. **Four-way, default options** (`04-shuffled.out`, two runs): Erlang 9.58/9.03, Elixir 9.57/9.00, Gleam 7.93/7.89, bs 9.59/9.01.
2. **Variants** (`06-variants.out`): erl 9.01, erl+inline 7.93, erl+no_type_opt 9.07; bs 9.03, bs+inline 8.12, bs+no_type_opt 9.12; Gleam 7.96.
3. **`{inline,100}`** (`17-inline100.out`): bs default 9.05, inline 8.14, {inline,100} 7.90, Erlang+inline 7.96, Gleam 7.99.
4. **Record tag guard** (`09-record-guard-cost.out`, 3,000,000 iterations, 60 rounds): hand Erlang with no guard 18.45 min /
   22.68 p25; `RecPriv` (private `Spin`) 35.15 / 42.84; `RecPub` (public `Spin`) 33.85 / 40.92; hand Erlang with the same guard
   as bsc emits 36.10 / 42.53. All four return 9000000. **`RecPriv` is private and still carries the tag guard**
   (`RecPriv.abstr`: `erlang:map_get('Kind', O) =:= 'RecPriv.Order'` on both clauses). `bs_emit.erl:322-325` says so:
   "The record tag guard above is emitted on private functions too; that asymmetry is deliberate." Cost is about 5.8 ns per call
   of a function whose body is one `map_get` and an add, so the ratio is exaggerated by the tiny body. This is the first
   measurement of the axis the ticket's §3.4 left open ("records and dispatch... has never been measured").
5. **Integer guards on public functions** (`10-public-int-guards.out`): all-public Day01 is +1-2%, inside noise.
6. **`.beam` size and compile time with `inline`** (`16-inline-size-and-time.out`, Shop, Frame, Intake, Ledger, Queue): size
   +0.5% to +1.0%. Compile time from `.abstr` moved +2% to +76% over two runs on 3-10 ms compiles, noisy; treat as "some tens of
   percent of a few ms". Signalbox fails to compile on OTP 25 with or without inline (`internal error in pass core` for
   `'ModelKey'/1`), so it is excluded. That is an OTP 25 incompatibility on this host, not an inline effect.
7. **Bytes/instructions**: Spin 26 instrs (default) vs 25 (Gleam, or Erlang +inline). `.beam` sizes: Erlang 1276 B, Gleam 2492, Elixir 2652, bs 2168 (bs carries `debug_info` and the extra `bs@type_atoms/0`).

## Options

The question is the ticket's second half: given that type annotations do not move the number, what should the emitter do about speed?
The program in every option is the repo's own `aoc/bench/Day01/bench_bs.bs` (`Spin`, `Wrap`, `Hit`, private, as written there).

### Option A: emit nothing new; close 39 as a baseline

B# program: unchanged. Compiled form: unchanged (`Spin` has three `call`s and a `call_last`).
Compiler delta: none. Amend the ticket and `aoc/bench/README.md` to say the 20% is host- and ordering-sensitive and not reproduced.
Evidence: rows 1-5. bs equals Erlang and Elixir.
**Strongest counterargument:** it leaves a measured 10-12% on the table that Gleam already takes, and a clean-room implementer judged by
speed against Gleam would notice. It also closes the ticket on a platform (OTP 25) that is not the one the ticket was written on.

### Option B: emit `-compile(inline)` in the forms

B# program: unchanged. Compiled form: the `.abstr` gains `{attribute,0,compile,inline}` after the module attribute, so `erlc +from_abstr`
honours it too (ticket 13's "the forms are the contract" holds). `Spin` becomes a self-loop with `Hit` inlined; `Wrap` stays a call.
Compiler delta: one element in the attribute list at `bs_emit.erl:73-76`; a test that the `.abstr` contains it; one line in F-file
for the decision. No checker change.
Evidence: rows 10, 11; Measurements 2, 6. -10% on Day01.
**Strongest counterargument:** crash frames for inlined local calls change (row 12). A B# function whose boundary guard
fails on a local call to a `public` function reports `'-inlined-h/1-'` and loses the caller frame. If B# diagnostics or the
REPL ever read stack frames, inline changes what they see. Compile time rises by some tens of percent of a few ms.

### Option C: B, and make the FFI result guard small enough to inline

B# program: unchanged. Compiled form: as B, plus `Wrap` inlined (either `{inline,100}` or hoisting the `is_integer` test so the
inliner sees a smaller function). Compiler delta: either an option in the attribute (`{attribute,0,compile,{inline,100}}`) or a
change to `return_guard/3` (`bs_emit.erl:1241-1249`) so that the wrapper is not counted; the second needs its own probe, none
was run.
Evidence: row 13 shows Wrap is held back by that wrapper; row 14 shows the gain over B is inside the noise.
**Strongest counterargument:** row 14. The extra gain (7.90 vs 8.14 ms min) is smaller than the spread. `{inline,100}` also grows
every function across the whole module, and only `Day01` was measured with it; no larger module was timed at size 100.

## Recommendation

**Option B**, and to correct the ticket text. Reasoning: it is one attribute, reversible, carries in the forms, and takes the
whole measured gain (Day01 bs 9.03 -> 8.12, Gleam 7.96). Do not do C until a probe on a second workload shows it matters.

Independently of B, amend the ticket and the benchmark README on these points, which are in the ticket and did not hold on this host:
(a) the harness order and run-to-run phases can produce a 20% gap with identical code (row 2); (b) the annotations are not the cause
(row 5); (c) B# does not hold a stronger interval than Erlang on `Day01` (row 8); (d) Gleam's bytecode is not the same as Erlang's
because of `inline` (row 9). Raise the private-function tag guard (Measurements 4) in ticket 18, where the tier argument lives.

## Open risks

- **The -10% is an OTP 25 number.** The ticket's own OTP 28 table has Gleam only ~3% ahead of Erlang (5.13 vs 5.30 ms), so the gain from `inline` there is probably much smaller. Re-running `13`/`16` on the ticket's machine is the gate before resolving (added after verification; see `verification.md`).

- **Platform.** Everything is OTP 25 / x86_64. The ticket's bare `{x,0}` vs `{0,99}` observation needs a newer OTP to reproduce;
  a later OTP may use `-spec` or narrower `rem` ranges, which would change rows 4-6. The tie between bs and Erlang may not hold on
  Apple Silicon. **Re-run `01-rebench.sh`, `04-shuffled.sh`, `06-variants.sh` on the ticket's machine before resolving.**
- **Lexer shim.** `bsc` was built without rebar3 (not installed). The installed leex has no `TokenLoc`/`error_location`, so
  `00-build-bsc.sh` rewrites `TokenLoc` to `{Line,1}`. That affects diagnostic columns only. Emitted code is unaffected, but the
  `.abstr` position annotations have column 1 rather than real columns, so the asm `line` data differs from a real build.
- **Shared-VM noise.** Samples jump between ~9.0 and ~11.5 ms regardless of implementation. The comparisons above are within one
  shuffled run, but absolute milliseconds do not compare across runs.
- **One workload, plus one record loop.** Nothing here exercises binaries, `switch` dispatch, or message passing.
- **The record guard number is a worst case** for a body that does almost nothing; a body that does real work will show a smaller ratio.
  The guard is emitted for exported functions and private ones alike (`bs_emit.erl:267-275`), which was not known to the ticket.
- **Erlang/Elixir/Gleam compiler sources were not available**, so no claim about *why* OTP 25's optimiser ignores specs or how the
  inliner sizes a function rests on source; both rest on observed output only.
- **Harness variants.** `bench2.erl`/`bench3.erl` are mine; the repo's `aoc/bench/bench.erl` was run unmodified in `01-rebench.sh`.
  `13-inline-as-attribute.v1-quoting-bug.*` and the fixes to probes 14 and 16 (format strings only) are logged in the scripts.

## Reproduce

From a clean shell, in `/home/user/beam-sharp/artifacts/39`:

```
probes/00-build-bsc.sh                    # builds bsc with erlc (no rebar3); needs leex/yecc from OTP
mkdir -p build/gleam/src && cp ../../aoc/bench/gleam/src/bench_gleam.gleam build/gleam/src/ \
  && printf 'name = "bench_gleam"\nversion = "1.0.0"\ntarget = "erlang"\n' > build/gleam/gleam.toml \
  && (cd build/gleam && /tmp/tools/gleam build)     # stdlib dependency dropped: the program does not use it
probes/01-rebench.sh                      # repo's own harness, unmodified; builds build/day01
probes/02-asm-diff.sh; python3 probes/03-hot-diff.py build/asm   # run from artifacts/39/build/asm as in the transcript
probes/04-shuffled.sh
probes/05-order.sh
probes/06-variants.sh
probes/07-tr-count.sh
probes/08-carry-ranges.sh
probes/09-record-guard-cost.sh
probes/10-public-int-guards.sh
probes/11-refined-range.sh
probes/12-survey-options.sh
probes/13-inline-as-attribute.sh
probes/14-inline-threshold.sh
probes/15-stacktrace-under-inline.sh
probes/16-inline-size-and-time.sh
probes/17-inline100.sh
```

`probes/bsc.sh` is the wrapper the scripts use to run the built compiler. Captured outputs sit next to each script as `<name>.out`.
