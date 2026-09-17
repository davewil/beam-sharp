# Brief: ticket 39 — why is instruction-identical code 20% slower, and what is the ceiling?

Research brief, not a decision. Does not resolve ticket 39; its `Status:` line and
`## Decisions entry` are untouched. `compiler/src/bs_emit.erl` and every other compiler source
file are untouched — `bsc` was rebuilt clean from the unmodified HEAD and every probe below runs
that binary against scratch `.bs`/`.erl` modules outside the repo. `git status` in
`/home/user/beam-sharp` is clean at the end of this session, HEAD `7065fa0d97822a5f3126d88ecab087fd0427cbc1`.

**Headline: the 20% gap does not reproduce on this toolchain.** Re-running `aoc/bench/` on the
exact OTP 28.5 / erts-16.4 / Elixir 1.19.5 / Gleam 1.18.1 versions ticket 39 names, beam-sharp's
emitted `Spin/4` disassembles **byte-identical, annotation-for-annotation**, to hand-written
Erlang's `spin/4` — including the `{tr,{x,0},{t_integer,{0,99}}}` the ticket says beam-sharp lacks.
The wall-clock gap is gone with it: beam-sharp is statistically tied with stock Erlang and Elixir,
and Gleam — not beam-sharp — is the outlier, running ~10-14% faster than the other three. The
causal experiment (stripping the JIT's type-range annotations with the documented `no_type_opt`
compiler option) does not reproduce a slowdown either: annotation-free Erlang runs in the same
band as annotated Erlang and beam-sharp. Records are a different story — a real, reproduced,
already-decided-and-accepted 6-32% cost, corroborating ticket 26's own micro-benchmark, not a new
finding.

## Methodology

Every number below is a real captured transcript from this session, against the environment
`RESEARCH_ENVIRONMENT.md` describes: OTP 28.5 (erts-16.4), Elixir 1.19.5, Gleam 1.18.1 (built
against a `path`-vendored `/tmp/gleam-stdlib-src` since `repo.hex.pm` is blocked — confirmed
working, not a mock), `bsc` rebuilt clean (`rebar3 clean && rebar3 escriptize`) from HEAD
`7065fa0`. Hardware is a 4-core shared Xeon VM (`cat /proc/cpuinfo`: `Intel(R) Xeon(R) Processor @
2.10GHz`), **not** the Apple Silicon the ticket's 2026-08-15 numbers were taken on — this matters
and is addressed in § Noise floor.

This repo checkout is **shallow**, rooted at commit `c405149` (2026-09-13); `git log` cannot see
anything from 2026-08-15, so I cannot diff `bs_emit.erl` against the exact state ticket 39
measured. Every claim about "what changed since" is therefore inference from the current source
plus the current binary's observed behavior, stated as such, never as a verified diff.

Probe scripts live at this session's scratchpad, `bench39/` (build scripts, hand-written `.erl`
drivers, `.bs` modules, raw captured output files) and `records/`. Where the brief quotes a
number, the source transcript is named so it can be re-opened.

**Noise floor.** `nproc` reports 4 cores, `/proc/loadavg` showed other activity during the session
(a shared host, not a dedicated benchmark box), and there is no `cpufreq` governor file to check or
pin (`/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor` does not exist — a VM, no host-level
frequency control visible to the guest). Unpinned 25-rep runs showed real run-to-run swings (§1);
pinning to one core (`taskset -c N`) and raising the harness to 101 reps per implementation
tightened the spread substantially and is what every aggregated table below uses unless marked
otherwise. This is a materially noisier environment than the ticket's original Apple Silicon
bare-metal measurement, which is itself part of why a 20% gap that was clean on that hardware
might not be trustworthy evidence of anything beam-sharp-specific if it only ever showed up there —
though on this hardware the direction of the result is the opposite problem: the gap doesn't show
up at all, in either the noisy or the pinned/high-rep form.

## Sub-decisions extracted

1. **Is the AoC integer-loop gap a fixable emission gap, or ticket 04's mandatory-signature
   tradeoff made visible?** Neither, on this toolchain — **there is currently no gap to attribute**.
   §1-§3 below show byte-identical disassembly and statistically tied timings. The interesting
   question the ticket raises (declared-return narrowing vs Erlang's free inference) is real in
   principle but is not what's happening in this binary's output today: OTP's own arithmetic-range
   inference (§5) reconstructs the tight range from the instruction stream regardless of what
   either language's type system declared, so ticket 04's tension never gets a chance to bite for
   *this* function shape.
2. **If fixable, where does the fix belong — `bs_emit` carrying ranges into `-spec`, or elsewhere?**
   Moot for the reason above, but the structural answer survives independent of whether there's a
   live gap: **`-spec` is not the channel.** §5 traces the actual channel — a `Type` chunk in the
   `.beam` container, populated by `beam_ssa_type`/`beam_call_types` from local SSA dataflow, read
   by the loader (`beam_file.c`) at load time. `-spec` lives in a different chunk the loader never
   consults for this. Widening `bs_emit`'s `-spec` (ticket 13's rule) would change nothing here,
   which is also what the ticket's own already-refuted spec-stripping experiment showed.
3. **What's the actual ceiling — can beam-sharp get ahead of Erlang, not just at parity?** On *this*
   mechanism, the ceiling is parity, already reached — OTP's inference is derived from the
   instruction stream and export visibility (§5), not from any richer channel beam-sharp could
   feed it, so matching Erlang's instruction shape is sufficient and matching its `-spec` is
   irrelevant. Getting ahead would require beam-sharp to emit a **different, more specialised
   instruction sequence** that Erlang's own inference wouldn't derive on its own — e.g. dropping a
   branch or comparison that ticket 20's proven exhaustiveness makes provably dead but that
   Erlang's local analysis can't rule out. **I did not build or measure such a version — this is a
   real, named, unmeasured lever, not a demonstrated result.**
4. **Records and dispatch (ticket 18/F3's boundary tag guard) — genuinely unmeasured, until now.**
   §7 below is a real, reproduced measurement: beam-sharp's record erasure (a tagged **map**) is
   6-32% slower per boundary crossing than Erlang's hand-written tagged **tuple**, in a
   673,364-iteration hot loop built for this brief. This is **not a new problem** — ticket 26
   (resolved 2026-08-13) already measured and *decided* this tradeoff at the per-access
   nanosecond level for DDD-identity reasons, and my macro measurement corroborates its own
   micro-benchmark almost exactly. Restating it here because ticket 39 flagged the axis as
   untouched by any *existing* benchmark, and now it has been touched, once, honestly.

## 1. Reproducing the four-language table

Built `aoc/bench/` for real: `erlc`, `elixirc`, `gleam build` (against the vendored stdlib per
`RESEARCH_ENVIRONMENT.md`), and `bsc -o ... aoc/bench/Day01`, then ran the existing
`bench.erl` harness unmodified via `erl -noshell -pa . -s bench main aoc/2025/Day01/input.txt`.
All four returned `6770` every time — the harness's own answer check never triggered.

First runs, default harness (25 reps), unpinned:

```
             answer      min ms    med ms      rel
Erlang       6770         10.77     12.43    1.02x
Elixir       6770         12.24     13.88    1.16x
Gleam        6770         10.52     10.86    1.00x
beam-sharp   6770         11.18     13.08    1.06x
```

Already visibly different from the ticket's 1.20x. Ten unpinned 25-rep runs (`bench39/day01_10runs.txt`),
aggregated:

```
lang         n   min-of-mins  median-of-mins  median-of-meds
Erlang       10        10.75           10.82           11.88
Elixir       10         9.39           10.79           11.75
Gleam        10         9.24            9.62           10.00
beam-sharp   10         9.73           10.79           12.29
```

Suspecting VM noise (4-core shared Xeon, not Apple Silicon bare metal — see § Noise floor), I
raised `RUNS` to 101 and pinned to one core (`taskset -c 0`) for the rest of the measurements.
Five pinned 101-rep runs (`bench39/day01_pinned101.txt`):

```
=== pinned run 1-5, e.g. ===
             answer      min ms    med ms      rel
Erlang       6770         10.99     12.59    1.13x
Elixir       6770         10.93     12.12    1.12x
Gleam        6770          9.73     11.00    1.00x
beam-sharp   6770         11.01     12.26    1.13x
```

Aggregated over all five:

```
lang         n   min-of-mins  median-of-mins  median-of-meds
Erlang         5        10.98           10.98           12.52
Elixir         5        10.93           10.94           12.19
Gleam          5         9.64            9.69           10.84
beam-sharp     5        10.93           10.94           12.05
```

**beam-sharp and Erlang are the same number (10.93 vs 10.98 ms, min-of-mins) across 505 timed
calls each.** Elixir sits with them. Gleam is ~12% faster than all three — the opposite of the
ticket's picture, where Erlang/Elixir/Gleam clustered and beam-sharp was the outlier.

A completely independent rebuild (`rebar3 clean && rebar3 escriptize`, fresh output directory,
different pinned core) reproduces the same shape (`/tmp/verify39`, three runs):

```
             answer      min ms    med ms      rel
Erlang       6770         11.80     12.65    1.06x
Elixir       6770         12.65     12.97    1.14x
Gleam        6770         11.13     11.49    1.00x
beam-sharp   6770         12.52     12.77    1.12x
---
Erlang       6770         12.42     12.92    1.18x
Elixir       6770         12.33     14.07    1.17x
Gleam        6770         10.55     11.09    1.00x
beam-sharp   6770         11.80     12.72    1.12x
---
Erlang       6770         12.72     12.99    1.14x
Elixir       6770         12.71     14.66    1.14x
Gleam        6770         11.16     11.44    1.00x
beam-sharp   6770         12.20     12.59    1.09x
```

## 2. Isolating `Spin` from the fold (§3 point 1)

Built a fourth module per language exposing `spin`/`Spin` directly through a thin public wrapper
(`SpinOnly`/`spin_only`), called once with `pos=50, step=1, left=673364, zeros=0` — the same total
iteration count as the real benchmark's clicks, none of the list traversal, `Sign`/`Size`, or fold.
Sources: `bench39/isolate/{spin_erl.erl,spin_ex.ex,gleam/src/spin_gleam.gleam,Spin01/spin01.bs}`,
driver `bench39/isolate/spinbench.erl`.

Five pinned 101-rep runs (`bench39/spinonly_pinned.txt`), aggregated:

```
lang         n   min-of-mins  median-of-mins  median-of-meds
Erlang         5        10.87           10.92           12.54
Elixir         5        10.88           10.93           12.51
Gleam          5         9.73            9.77           11.25
beam-sharp     5        10.71           10.75           12.12
```

**In isolation, beam-sharp (10.75) is marginally *faster* than Erlang (10.92) and Elixir (10.93)**,
well inside run-to-run noise. §3 point 1 is answered: there is no gap in `Spin` alone, because
there is no gap anywhere in this workload on this toolchain — isolating it doesn't localise a cost
because there isn't one to localise.

## 3. The causal experiment (§3 point 2) — the load-bearing one

The ticket's literal ask — strip a hand-written Erlang module's annotations "to match beam-sharp's
emission" — has no target to match: §4 shows beam-sharp's emission is *not* missing annotations on
this build. So the experiment tested the general causal claim instead: **does losing the `{tr,...}`
JIT type-range annotations, by itself, cause the slowdown the ticket describes?**

OTP ships a documented compiler option for exactly this, `compile.erl:1090-1096`:

```erlang
expand_opt(no_type_opt=O, Os) ->
    %% Be sure to keep the no_type_opt option so that it will
    %% be recorded in the BEAM file, allowing the test suites
    %% to recompile the file with this option.
    [O,no_ssa_opt_type_start,
     no_ssa_opt_type_continue,
     no_ssa_opt_type_finish | Os];
```

Compiled `bench_erl.erl` unmodified except `-compile(no_type_opt).` added and the module renamed.
Disassembly confirms the flag does exactly what's needed — same 26 instructions, same opcodes,
zero `{tr,...}` anywhere (full transcript in the tool log; `wrap/1`'s three `gc_bif`s go from
`[{tr,{x,0},{t_integer,{-99,99}}},{integer,100}]`-style operands to bare `[{x,0},{integer,100}]`).
This *is* "beam-sharp's bare `{x,0}`" shape the ticket describes — reconstructed faithfully by
disabling the exact compiler pass that produces the annotation, not approximated by hand.

Five-way pinned benchmark (Erlang, Elixir, Gleam, beam-sharp, `Erl-no_type_opt`), 101 reps each,
five runs (`bench39/causal_5way.txt`), aggregated:

```
lang               n   min-of-mins  median-of-mins  median-of-meds
Erlang               5        11.13           12.13           12.97
Elixir               5        11.07           11.86           12.87
Gleam                5         9.69           10.33           11.26
beam-sharp           5        11.08           11.68           12.89
Erl-no_type_opt      5        11.29           11.92           13.00
```

**`Erl-no_type_opt` (11.92 median-of-mins) sits inside the same band as plain Erlang (12.13) and
beam-sharp (11.68) — it is not the outlier.** Stripping the annotations that the ticket's whole
theory rests on does not reproduce a measurable slowdown on this JIT. Independently re-verified
from a clean rebuild in a separate directory, three more runs (`/tmp/verify39/bench_v2.erl`):

```
               answer      min ms    med ms      rel
Erlang         6770         11.86     12.81    1.11x
Gleam          6770         10.71     11.42    1.00x
beam-sharp     6770         12.44     13.02    1.16x
Erl-notype     6770         12.47     13.15    1.16x
---
Erlang         6770         11.71     12.73    1.13x
Gleam          6770         10.33     10.96    1.00x
beam-sharp     6770         11.25     12.72    1.09x
Erl-notype     6770         12.81     13.15    1.24x
---
Erlang         6770         12.65     12.93    1.14x
Gleam          6770         11.06     11.43    1.00x
beam-sharp     6770         12.12     12.98    1.10x
Erl-notype     6770         12.73     13.15    1.15x
```

Same picture: `Erl-notype` tracks Erlang and beam-sharp, never the clear outlier Gleam is. **The
causal claim ("annotation loss causes the slowdown") does not survive a direct test on this JIT.**
Combined with §4's disassembly, the honest reading is that ticket 39's theory — correct as far as
it went in describing a correlation on 2026-08-15's build — is not, on this build, describing a
real cost: the correlation it pointed at itself has disappeared, and the piece of it that could be
tested directly (does losing `{tr,...}` alone cost anything) tests negative.

## 4. Disassembly: the annotation gap is not present on this build

`beam_disasm:file/1` against both the current build's `Day01.beam` and `aoc/bench/bench_erl.erl`'s
`bench_erl.beam`. `Spin/4` and `spin/4`:

```
$ diff <(disasm Day01:Spin/4 with names normalised) <(disasm bench_erl:spin/4 with names normalised)
(only module-name and Capitalised-vs-lowercase function-name lines differ)
```

The two are 26 instructions each, and every operand — including every `{tr,Reg,Type}` — is
identical:

```
{gc_bif,'+',{f,0},2,[{tr,{x,0},{t_integer,{0,99}}},{tr,{x,1},{t_integer,{-1,1}}}],{x,0}}
{gc_bif,'-',{f,0},1,[{y,2},{integer,1}],{y,2}}
{gc_bif,'+',{f,0},1,[{tr,{y,1},{t_integer,{0,'+inf'}}},{tr,{x,0},{t_integer,{0,1}}}],{x,3}}
```

in both. `Wrap/1`/`wrap/1` and `Hit/1`/`hit/1` match the same way — `Hit`'s comparison carries
`{tr,{x,0},{t_integer,{0,99}}}`, the exact tuple the ticket quotes as present in Erlang and absent
in beam-sharp. It is present in beam-sharp too, on this build. Independently re-verified from the
clean rebuild (`/tmp/verify39/Day01.beam`) — identical result, quoted in full in § Verification.

**A plausible mechanical explanation, found while tracing why (§5 explains the mechanism itself):**
export visibility. `beam_lib:chunks(.., [exports])` on both `.beam` files:

```
Day01 exports: [{'PartTwo',1},{module_info,0},{module_info,1}]
bench_erl exports: [{module_info,0},{module_info,1},{part_two,1}]
```

Both modules export **only** the top-level entry point; `Wrap`/`wrap`, `Hit`/`hit`, `Spin`/`spin`,
`Sign`/`sign`, `Size`/`size_`, `Clicks`/`clicks` are non-exported in both. §5 shows this is exactly
the precondition OTP's own cross-call type-narrowing requires. If ticket 39's original build
exported more than its `public` functions — plausible, unverifiable from this shallow checkout —
that alone would explain the loss of narrowing independent of any `-spec` question, since the
narrowing pass explicitly refuses to run across an exported boundary (§5, `beam_ssa_type.erl:428`).
This is offered as the most likely explanation for what changed, not as a verified diff.

## 5. How Erlang/OTP actually derives and delivers `{tr,...}` — survey with citations

All citations read from `/tmp/erlang-28.5-src`, tag `OTP-28.5`, the actual source the installed
`erl` was built from.

**Where the range comes from — purely local arithmetic dataflow, no `-spec` involved.**
`lib/compiler/src/beam_call_types.erl:465-467`:

```erlang
types(erlang, 'rem', Args) ->
    sub_unsafe(beam_bounds_type('rem', #t_integer{}, Args),
               [#t_integer{}, #t_integer{}]);
```

and `:470-488` for `+`/`-`, computing a return range from the *argument types already known to the
SSA optimizer* — never from any declared `-spec`. This is called from the type-propagation pass,
`beam_ssa_type.erl`.

**Where cross-call narrowing is gated on export visibility — the mechanism behind §4's
explanation.** `beam_ssa_type.erl:428-438`:

```erlang
opt_continue(Linear0, Args, Anno, FuncDb) when FuncDb =/= #{} ->
    Id = get_func_id(Anno),
    case FuncDb of
        #{ Id := #func_info{exported=false,arg_types=ArgTypes} } ->
            %% This is a local function and we're guaranteed to have visited
            %% every call site at least once, so we know that the parameter
            %% types are at least as narrow as the join of all argument types.
            Ts = join_arg_types(Args, ArgTypes),
            opt_function(Linear0, Args, Id, Ts, FuncDb);
        #{ Id := #func_info{exported=true} } ->
            %% We can't infer the parameter types of exported functions, but
            %% running the pass again could still help other functions.
            Ts = #{V => any || #b_var{}=V <- Args},
            opt_function(Linear0, Args, Id, Ts, FuncDb)
    end;
```

Read verbatim: for a **local** (non-exported) function, the compiler knows every call site inside
the module and can join their argument types to narrow the parameter; for an **exported**
function, it gives up (`any`) because an external caller could hand it anything. This is exactly
why `Wrap`/`Hit`/`Spin` (all non-exported in both modules, §4) get the tight ranges and why an
exported entry point never would.

**Where the annotation gets attached to a BEAM instruction operand at codegen time.**
`beam_ssa_codegen.erl:2707-2719`:

```erlang
typed_args_1([Arg | Args], Anno, St, Index) ->
   case Anno of
       #{ arg_types := #{ Index := Type } } ->
           Typed = #tr{r=beam_arg(Arg, St),t=Type},
           [Typed | typed_args_1(Args, Anno, St, Index + 1)];
       #{} ->
           [beam_arg(Arg, St) | typed_args_1(Args, Anno, St, Index + 1)]
   end;
```

`#tr{r=Reg,t=Type}` is the record `{tr,Reg,Type}` disassembles as. It reads `arg_types` off the SSA
instruction's own annotation map — populated entirely by the passes above, never by `-spec`.

**Where the loader/JIT consumes it — confirming `-spec` is a different channel entirely.**
`erts/emulator/beam/beam_file.c:620-654`, `parse_type_chunk_data/2`, reads a dedicated **`Type`**
IFF chunk out of the compiled `.beam` file — a binary table the compiler backend serialises
separately from the `Attr`/`Dbgi` chunks that hold `-spec` (those are what Dialyzer and
`erlang:get_module_info/1` read; the JIT loader does not consult them for this). `beam_types.c:44`,
`beam_types_decode_type/2`, decodes each entry's bit-packed type/range. This is the concrete answer
to sub-decision 2: **feeding `bs_emit`'s `-spec` a tighter range would touch the wrong chunk.** The
only way to influence the `Type` chunk is to influence what `beam_ssa_type` infers from the actual
code shape (arithmetic, calls, export visibility) — which for this benchmark it already does,
identically for both languages, once export visibility matches (§4).

**The `no_type_opt` control confirms the whole chain in one place**: disabling
`no_ssa_opt_type_start/continue/finish` (`compile.erl:1090-1096`, §3) removes every `{tr,...}` and
the `Type` chunk contribution that produces them, with zero effect on the emitted opcode sequence
— consistent with the mechanism being purely a codegen/loader annotation layered on top of an
otherwise-unchanged instruction stream, exactly as §1's already-refuted `-spec`-stripping result
implied.

## 6. `fib(100,000)` reconfirmed

Rebuilt `aoc/bench/fib/` fresh (Gleam again vendored). Two runs, 9 reps each, fresh-process-per-run:

```
fib(100000) — a list of 100000 numbers, the last with 20899 digits
                min ms    med ms    max ms      rel
Erlang           698.4     732.2    1089.9    1.00x
Elixir           705.1     732.5     806.2    1.01x
Gleam            705.0     733.3    1013.2    1.01x
beam-sharp       721.7     745.0     858.9    1.03x
---
Erlang           716.4     751.0     771.9    1.03x
Elixir           714.9     742.6     865.9    1.03x
Gleam            696.8     741.8     858.0    1.00x
beam-sharp       718.3     742.5     940.3    1.03x
```

Matches the ticket's own already-answered §3.4 exactly: a dead heat, beam-sharp within 1-3% of the
other three both times. No new information here; recorded for completeness since the task asked
for the full table shape.

## 7. Records and dispatch — the previously-untouched axis, now touched

Wrote a minimal record-touching hot loop in both languages, matching `Spin`'s shape: a public
`Bump(Acc, step) -> Acc` that takes and returns a record, folded 673,364 times from an external
driver so the record crosses the module's exported boundary on **every** iteration — the shape
that would show ticket 18/F3's boundary tag guard cost if it has one. Sources:
`bench39/records/{rec_erl.erl,RecSpin/recspin.bs,recbench.erl}`.

**First surprise, found by reading the compiled output, not assumed:** beam-sharp's `record Acc {
Pos: int, Zeros: int }` does not erase to a tagged tuple. Reading `RecSpin.abstr` directly:

```erlang
{map,{24,5},
 [{map_field_assoc,{24,5},{atom,{24,5},'Kind'},{atom,{24,5},'RecSpin.Acc'}},
  {map_field_assoc,{24,5},{atom,{24,5},'Pos'},{var,{24,17},'Next'}},
  {map_field_assoc,{24,5},{atom,{24,5},'Zeros'},{op, ...}}]}
```

and the guard on `Bump`'s clause head:

```erlang
{op,{22,1},'andalso',
 {op,{22,1},'=:=',
  {call,{22,1},{remote,{22,1},{atom,{22,1},erlang},{atom,{22,1},map_get}},
   [{atom,{22,1},'Kind'},{var,{22,1},'A'}]},
  {atom,{22,1},'RecSpin.Acc'}},
 {call,{22,1},{remote,{22,1},{atom,{22,1},erlang},{atom,{22,1},is_integer}},
  [{var,{22,1},'Step'}]}}
```

A record is an Erlang **map** with a `'Kind'` discriminator key, guarded with `map_get` — this is
ticket 26's own resolved decision (`record erases to a MAP`, 2026-08-13), read straight off the
compiled output rather than assumed from the ticket text.

**The disassembly explains the cost directly.** `Bump/2` (23 instructions) against Erlang's
`bump/2` on the equivalent tagged-tuple record (22 instructions):

```
beam-sharp Bump/2:                              Erlang bump/2 (tagged tuple):
{bif,map_get,[{atom,'Kind'},{x,0}],{x,2}}       {test,is_tagged_tuple,[{x,0},3,{atom,acc}]}
{test,is_eq_exact,[{x,2},{atom,'RecSpin.Acc'}]}
{test,is_integer,[{x,1}]}
{bif,map_get,[{atom,'Pos'},...],{x,2}}          {get_tuple_element,{x,0},1,{x,2}}
...
{bif,map_get,[{atom,'Zeros'},...],{y,1}}        {get_tuple_element,{x,0},2,{x,0}}
...
{put_map_assoc,{f,0},{literal,#{}},...}         {put_tuple2,{x,0},{list,[{atom,acc},{y,0},{x,0}]}}
```

Three `map_get` BIF calls plus a `put_map_assoc` building a fresh map from `#{}` on every call,
against one `is_tagged_tuple` test, two direct `get_tuple_element` reads, and one `put_tuple2` for
Erlang. Maps are real work (hash/sorted-key structure); tuples are direct offsets.

**Measured**, pinned, three runs (`bench39/records/`):

```
                     answer                  min ms    med ms      rel
Erlang-record        {acc,14,6734}            13.17     13.80    1.00x
beam-sharp-record    #{...}                    15.13     16.06    1.15x
---
Erlang-record        {acc,14,6734}            13.19     13.88    1.00x
beam-sharp-record    #{...}                    15.06     16.55    1.14x
---
Erlang-record        {acc,14,6734}            13.61     13.93    1.00x
beam-sharp-record    #{...}                    15.83     16.60    1.16x
```

Independently re-verified from a clean rebuild in a separate directory (`/tmp/verify39/records`),
two more runs:

```
Erlang-record        {acc,14,6734}            11.70     13.72    1.00x
beam-sharp-record    #{...}                    15.46     16.11    1.32x
---
Erlang-record        {acc,14,6734}            13.65     13.88    1.00x
beam-sharp-record    #{...}                    14.40     16.24    1.06x
```

**A consistent 6-32% cost, always in the same direction** (map slower than tuple), noisier than
the arithmetic-loop numbers because the VM's shared-core jitter is a larger fraction of a bigger
per-call cost.

**This corroborates, not contradicts, an already-resolved decision.** Ticket 26 §1 (resolved
2026-08-13) measured the same tradeoff at per-field-access granularity: *"tuple 2.17 ns unguarded,
7.04 ns guarded; map 8.76 ns guarded; tagged map 8.78 ns. The 4× gap is between the unguarded
forms... the comparison that ships is 7.04 vs 8.78."* That's a ~25% per-access cost, and 26 chose
the map anyway — *"David forced it on DDD identity"*: a bare-tuple erasure loses the field **set**
(`{order,1,2} =/= {order,2,1}` while `#{b=>1,a=>2} =:= #{a=>2,b=>1}`, 26a §4.4) and a name-derived
tag would gain a nominal identity ticket 09 explicitly rules out. My end-to-end hot-loop number is
new evidence at a different granularity, in the same direction, at roughly the same magnitude
(6-32% end-to-end vs ~25% per access, consistent given `Bump` does three field touches per call).
**Grepped `wayfinder/issues/` before writing any of this section** — this axis has a decision; my
job here was only to add the macro measurement ticket 39 asked for, not to relitigate 26.

## Options

**Option A — leave it; there is no gap to close on the arithmetic axis, and the record axis is
already decided.** Evidence: §1-§4, five independent measurement passes (default harness, pinned
101-rep, isolated `Spin`, causal `no_type_opt`, clean-rebuild re-verification) all show beam-sharp
tied with Erlang/Elixir on the workload the ticket names, with byte-identical disassembly
including the very annotation the ticket says is missing. The record cost is real but is ticket
26's accepted tradeoff for DDD identity, re-measured, not re-opened. **Counterargument:** this
brief measured one hardware/toolchain snapshot on one micro-benchmark; the ticket's original
20%-slower observation was also real, on its own toolchain, and this brief cannot rule out that
something about the original measurement environment (possibly export visibility, per §4's
mechanical explanation, unverifiable from this shallow checkout) genuinely changed the emitted
code's shape since 2026-08-15 rather than the earlier number being noise. If it changed once
silently, it can regress silently, and nothing in this repo pins Erlang export visibility as a
tested invariant of `bs_emit`.

**Option B — add a check that `bs_emit` only ever exports a `.bs` module's `public` functions to
Erlang's `-export`, matching what §4/§5 shows is load-bearing for OTP's own cross-call type
narrowing.** Evidence: §4's export listing already shows this holds today; §5's
`beam_ssa_type.erl:428` shows *why* it matters mechanically — if it ever regressed (all functions
exported, or a public/private distinction not reaching the emitted `-export`), OTP's own inference
would silently stop narrowing internal calls and the annotation gap the ticket described could
reappear for reasons that have nothing to do with `-spec` or ticket 04's tension. This is a cheap,
mechanically-justified guard rather than a performance fix — it protects a property this brief
shows is already true rather than chasing one that isn't. **Counterargument:** speculative. This
brief has one data point (this build exports correctly); there's no evidence of a real regression,
only a plausible mechanism by which one *could* happen, and CLAUDE.md's own rule is that a check
needs a second occurrence of the failure it names before it's added, not a hypothesis about a
first one.

**Option C — investigate the gap between beam-sharp's stronger static knowledge (ticket 20's exact
intervals) and Erlang's local-only inference as a genuine "ahead" opportunity, before deciding
anything is settled.** Evidence: §5 shows OTP's own inference is *purely local* — it cannot use a
cross-clause exhaustiveness proof, only per-function arithmetic dataflow. beam-sharp's checker
proves facts (ticket 20's `int <= 1 | int >= 3`-style residuals) that are not derivable from local
arithmetic alone. If `bs_emit` ever emitted a structurally different, more specialised instruction
sequence exploiting such a fact — skipping a branch OTP's own inference can't prove dead — that
would be a real "ahead," not parity. **Counterargument:** entirely unmeasured. No such
instruction-sequence difference was built or timed in this session; this is a hypothesis with a
mechanism, not a result, and building it is real compiler work this brief's scope (measurement and
a brief, not a fix) explicitly excludes.

## Recommendation

**A, with B as a cheap hedge.** The measured reality on this toolchain is parity, not a 20% deficit
— five independent passes agree, including a from-scratch rebuild and disassembly down to the
annotation level. There is no evidence-backed case for spending compiler-source effort closing a
gap that isn't currently open. But the gap the ticket originally saw was real *then*, on *some*
build, and §4/§5 hand over a specific, cheap, testable mechanism (export visibility) that could
explain both why it existed and why it's gone — worth a one-line regression check (Option B) far
more than worth the speculative "get ahead" compiler work of Option C, which stays a named,
unbuilt lever for whenever `bs_emit` next touches integer-loop codegen.

## Verification

**No `Agent`/`Task` subagent tool was available in this session** — `ToolSearch` for
"spawn subagent general-purpose task agent" and "Task subagent_type general-purpose launch parallel
agent" both returned only unrelated tools (`TaskStop`, Linear/GitHub agent tools, `SendMessage` to
already-live peers, `EnterWorktree`). I have no way to launch a fresh isolated subagent in this
environment, so instead of fabricating a subagent report, I ran a second, independent verification
pass myself, from a clean state, explicitly checking for the circularity failure modes the task
named:

1. **Rebuilt `bsc` clean** (`rebar3 clean && rebar3 escriptize` in `compiler/`) rather than reusing
   the binary the first pass built — rules out a stale/cached `bsc`.
2. **Rebuilt every artifact in a fresh directory** (`/tmp/verify39`, distinct from
   `bench39`/`/tmp/beam-sharp-bench`), compiling the *actual repo files*
   (`aoc/bench/bench_erl.erl`, `aoc/bench/Day01`, `aoc/bench/bench.erl`) directly rather than
   scratch copies, and re-ran the benchmark **pinned to a different core** (`taskset -c 1` vs `-c
   0`) — three runs, quoted in full in §1. Same shape: beam-sharp tied with Erlang/Elixir, Gleam
   the outlier.
3. **Checked `bench.erl` calls all languages the same way**, by reading it: one `Impls` list, one
   `run/3` applying `timer:tc(F, [Deltas])` uniformly, one `report/1` — no language gets a
   different call path, warm-up, or argument shape. Confirmed by reading the unmodified file
   directly rather than trusting the ticket's or my own paraphrase of it.
4. **Independently re-derived the `no_type_opt` module** in the verification pass
   (`/tmp/verify39/bench_erl_v2.erl`) with a fresh `diff` against the untouched repo source
   showing the only change is the module name and the one `-compile` line, then independently
   confirmed via `beam_disasm` that it produces zero `{tr,...}` tuples — not assumed from the
   first pass's claim. Re-timed in a fresh 4-way + notype harness (`bench_v2.erl`), three runs:
   `Erl-notype` lands at 1.16x/1.24x/1.15x against Gleam's 1.00x base, in the same band as
   `beam-sharp` (1.16x/1.09x/1.10x) and plain `Erlang` (1.11x/1.13x/1.14x) every time — never the
   outlier. This directly checks the one place circularity could hide: that the "stripped
   annotation" module is doing what it claims (verified by disassembly, not assumed) and that it's
   actually timed against the same fold/list/timer machinery as everything else (verified by
   reading `bench_v2.erl`, which reuses the identical `run/3` pattern).
5. **Independently re-verified the record measurement** in a fresh directory
   (`/tmp/verify39/records`, fresh `bsc` build, fresh `rec_erl.erl`/`recbench.erl` compile), two
   more runs: beam-sharp's tagged-map record is 6-32% slower than Erlang's tagged-tuple record
   again, same direction every time.
6. **Flagged, not hidden, the one place this brief's own construction could be circular**: the
   `Erl-no_type_opt` module is *not* literally "beam-sharp's emission shape" (§3) — beam-sharp's
   emission has full annotations on this build, so there was nothing of that shape to copy. I used
   the closest faithful reconstruction of the *ticket's description* of that shape instead (a
   documented OTP compiler flag, not a hand-guess), and said so explicitly rather than presenting
   it as a literal match.

No fabricated numbers, no unexecuted claims. Every table above has a named source file or an
inline transcript from this session's tool calls.
