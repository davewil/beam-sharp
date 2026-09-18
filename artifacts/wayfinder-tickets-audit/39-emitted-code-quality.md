# Audit of ticket 39 — emitted code quality (research only)

**This does not resolve ticket 39.** No ticket `Status:` line, no Linear state, and no
`wayfinder/issues/39-emitted-code-quality.md` content were changed by this audit. It is a
gathering of real, executed evidence toward the ticket's open question, per a request to grill
the ticket rather than close it.

Environment actually used: OTP 25 (erts-13.2.2.5), Elixir 1.14.0 — **not** the ticket's OTP 28 /
Elixir 1.19.5. `.tool-versions` pins `erlang 28.5`; this machine has 25. Where that gap matters,
it is called out below. `bsc` could not be built here (see §0) — this is a hard blocker, stated
once, not repeated as a hedge on every finding.

## §0. Blocker: `bsc` does not build on this machine

`cd compiler && rebar3 compile` (and `rebar3 escriptize`) both fail, reproducibly, clean-checkout
and rerun:

```
{leex,file,
      ["/home/user/beam-sharp/compiler/src/bs_lexer.xrl",
       [{return,true},{error_location,column}]],
      [{file,"leex.erl"},{line,137}]}
badarg
```

`bs_lexer.xrl`'s `{xrl_opts, [{error_location, column}]}` (compiler/rebar.config) calls a `leex`
option this OTP 25's `leex:file/2` does not accept at all — it isn't a soft warning, it's a
`badarg` inside `leex.erl` itself. This matches `.tool-versions`' `erlang 28.5` pin exactly: the
per-column error-location feature is newer than 25. **No `bsc` build, no real `.abstr` for the
actual `Day01` module, and no re-run of `aoc/bench/` was possible in this session.** Per the
brief's brief, the numbers below are the recorded ones from `aoc/bench/README.md` and
`wayfinder/issues/39-emitted-code-quality.md`; nothing here fabricates a new beam-sharp timing.

## Sub-questions

### (a) Why does beam-sharp's compiler emit fewer type-range annotations than Erlang's for structurally identical code?

**What `{tr, {x,N}, Type}` actually is, confirmed from real OTP source and real local
disassembly, not assumed:**

- Reproduced the annotation cold, on this machine, from a plain `wrap/spin` pair transliterated
  from `aoc/bench/bench_erl.erl`: `erlc +to_asm wrap1.erl` produces
  `{gc_bif,'+',{f,0},1,[{y,2},{tr,{x,0},{t_integer,{-99,99}}}],{x,0}}` (full output in the probe
  transcript below). This is the same tag family the ticket quotes, on OTP 25 rather than 28 —
  the mechanism is not new to 28.
- Fetched real OTP compiler source (`lib/compiler/src/beam_ssa_type.erl`,
  `lib/compiler/src/beam_ssa_codegen.erl` from `github.com/erlang/otp`, `master`, via WebFetch).
  `beam_ssa_type.erl` computes `result_type` and `arg_types` **as whole-module/per-function
  data-flow annotations on the SSA form**, independent of `-spec` — it is a fixpoint success-typing
  pass, not a spec reader. `beam_ssa_codegen.erl`'s `typed_arg/3` is what actually builds the `#tr{}`
  record from the `arg_types` annotation when lowering SSA to the loadable form:
  ```erlang
  typed_arg(#b_var{}=Arg, Anno, St) ->
      case maps:get(arg_types, Anno, #{}) of
          ArgTypes when map_size(ArgTypes) > 0 ->
              N = arg_index(Arg, Anno),
              case ArgTypes of
                  #{N := Type} -> #tr{r=beam_arg(Arg, St), t=Type};
                  #{}          -> beam_arg(Arg, St)
              end;
          #{} -> beam_arg(Arg, St)
      end;
  ```
  (WebFetch summarizes rather than verbatim-quotes; treat the shape, not every character, as
  confirmed — it is corroborated independently by `beam_ssa_type.erl`'s own description of
  `arg_types`/`result_type` annotations.)
- **Consequence: this is a standard-library optimizer pass that runs on *any* module entering the
  normal `compile` pipeline, triggered purely by what the abstract forms/Core Erlang say the code
  does — not by anything a front-end has to opt into or declare.** Erlang, Elixir and Gleam get it
  "for free" because their compiled output is structurally the kind of code this pass already
  knows how to narrow (arithmetic on `rem`, guards, `case` dispatch on integers).

**Three concrete hypotheses for why beam-sharp's forms fail to trigger the same inference — each
tested by direct execution, each refuted:**

1. **The widened `-spec` defeats it.** Already refuted in the ticket itself (stripping specs left
   the loop byte-identical, 6.51 ms / 6.54 ms). Independently reconfirmed here:
   `wrap2.erl` (a `-spec wrap(integer()) -> integer().` added to the exact baseline) disassembles
   to the identical `{tr,{x,0},{t_integer,{-99,99}}}` as the spec-free `wrap1.erl`. `-spec` is
   consulted by Dialyzer, not by `beam_ssa_type` — confirmed both empirically and by what the
   fetched `beam_ssa_type.erl` source says it reads.
2. **Every abstract-format node carrying line `0` (`bs_emit.erl:20`, `-define(A, 0).`, used at
   >180 call sites including `bs_emit.erl:146`'s `{function, ?A, Name, Arity, [clause(...)]}`)
   breaks the pass.** Tested directly: took `wrap1.erl`'s real parsed abstract forms
   (`epp:parse_file`), zeroed every node's annotation exactly the way `bs_emit` does (a
   tag-whitelisted walker so `-export`'s plain `{Name,Arity}` data tuples are left alone — see
   `zero_line_test2.erl` in the probe transcript), and ran it through `compile:forms/2`. Result:
   `{tr,{x,0},{{t_integer,any},18446744073709551517,99}}` (i.e. `{-99,99}`, the huge number is an
   artifact of `beam_disasm`'s pretty-printer rendering a negative bound as unsigned) — **the
   annotation survives all-zero line numbers intact.** Refuted.
3. **The FFI shape — `:erlang.rem(...)` as an explicit remote call, vs. hand-Erlang's infix `rem`
   operator — produces different Core Erlang that the pass doesn't recognize the same way.**
   Tested directly by hand-building abstract forms with `{call,0,{remote,0,{atom,0,erlang},
   {atom,0,'rem'}},[...]}` in place of `{op,0,'rem',...}` (this cannot be written as literal
   Erlang *source* — `rem` is a reserved word, `erlang:rem(A,B)` is a parser syntax error — so it
   was built as a term directly, the same place `bs_emit` sits, never through `erl_scan`/`erl_parse`).
   Compiled via `compile:forms/2`: identical `{tr,{x,0},{t_integer,{-99,99}}}`. Refuted — Core
   Erlang has no infix operators at all; `N rem 100` and `erlang:rem(N,100)` normalize to the
   same `call 'erlang':'rem'/2` before `beam_ssa_type` ever runs.
4. **The most faithful reproduction attempted:** wrote the zero-lined, remote-call-shaped forms to
   a `.abstr` text file and called `compile:file(AbstrPath, [from_abstr, debug_info,
   {outdir,"."}, report_errors, report_warnings])` — **the exact function and exact option list
   `bsc.erl:827-831` calls**, not a simplified substitute. Same result: annotation present.

**So: for this minimal two-function shape, every mechanical hypothesis testable without building
`bsc` itself is refuted.** The `from_abstr` entry point, the option list, all-zero source
positions, and the FFI-call spelling of `rem` are all, individually and together, insufficient to
suppress the annotation. Whatever actually suppresses it in the real `Day01` module must be either
(i) something in the fuller call graph (`Spin` calling both `Wrap` *and* `Hit`, `Clicks` calling
`Spin` and `Sign`/`Size`, vs. this audit's isolated two-function probe) that only shows up at that
scale, or (ii) a real divergence in `bs_emit`'s output for the actual module that this audit could
not extract without OTP 28. Confirmed separately: even hand-Erlang's own *real* transliteration
(`aoc/bench/bench_erl.erl`, not this audit's simplified `wrap1.erl`) only shows the `{tr,...}` tag
on `Hit`'s return (`{t_integer,{0,1}}`, consumed by `Zeros + hit(Next)`) — `Wrap`'s own return
(`Next`) is consumed as a bare function argument to `Hit` and to the recursive `Spin` call, not by
an arithmetic BIF inside `Spin` itself, so it carries no printed `tr` tag at all in *this* shape.
The ticket's own quoted `{tr,{x,0},{t_integer,{0,99}}}` therefore likely comes from a call-site or
register this audit's probes did not reproduce exactly — pinning that down needs the real
`.abstr`/`.beam`, which needs OTP 28.

### (b) Fixable by changing what abstract forms beam-sharp emits, or does it need a `-spec`/annotation the JIT reads?

**Not a `-spec`, confirmed twice over** (the ticket's own strip test, and (a)'s independent
`wrap2.erl` reconstruction). There is also **no user-facing Abstract Format attribute that
`beam_ssa_type` reads as an externally-supplied type hint** — `arg_types`/`result_type` are
internal SSA annotations the pass computes itself; nothing in the fetched `beam_ssa_type.erl`
takes them as input from an earlier stage. So "supply an annotation the JIT reads" is not a real
lever available at the Abstract Format boundary — the only lever is **shaping the emitted forms so
that `beam_ssa_type`'s own inference derives the same fact Erlang's does**, which is a "what forms
we emit" question, not a "what extra tag we bolt on" one.

### (c) What would the fix cost in the compiler?

See the three candidates below — none of them is a menu; each is falsifiable and only one asks
anything of `bs_emit`.

## Candidate fixes

**Candidate 1 — diff the real SSA before touching `bs_emit`.**
Compiler delta: a `bin/dump-ssa.sh` (or a `bsc --dump-ssa` flag reusing the debug-dump options
`compile:file` already exposes — `to_ssa` alongside the existing `from_abstr`) that captures the
`beam_ssa` IR for the real `Day01` module's `Wrap`/`Spin`/`Hit`, dumped from the same `.abstr`
`bsc.erl:815-831` already writes, alongside the equivalent dump for `bench_erl.erl`. Diff the two
SSA listings function-by-function; the first point of divergence is where `beam_ssa_type`'s
inference actually forks. This is the fix to *not knowing*, not a design change — it costs a
build target and an OTP-28 machine, and (a)'s four refuted hypotheses show it is genuinely needed:
nothing cheaper localizes the cause further. **Why it might not close the gap:** it only produces
a diagnosis, not a fix — if the divergence turns out to be in how the multi-function call graph
(not any single function's shape) defeats interprocedural narrowing, the actual fix is still
unknown after this step.

**Candidate 2 — restructure `bs_emit`'s output so the pass's own inference has what it needs,
without inventing a new IR.**
Compiler delta: if Candidate 1 locates a genuine shape divergence (e.g. an extra intermediate
binding, a different clause order, a different guard encoding than `erlc`'s own front-end would
produce for the same source), change `bs_emit.erl`'s clause/expression construction to match the
shape `v3_core`/`beam_ssa_type` already narrows well — for instance, if multi-clause functions
with a literal-vs-variable head order matter to the pass's fixpoint, reorder clause emission to
put the narrowing clause first, or avoid an SSA-visible temporary the checker's lowering
introduces that hand-written Erlang wouldn't. This is a pure `bs_emit.erl` change: no new pass,
no new attribute, nothing in `bs_check`/`bs_types` moves. Cost is small *if* Candidate 1 finds a
single, local divergence; open-ended if it doesn't. **Why it might not close the gap:** this
audit's own probes (§(a), points 2-4) already reproduced `bsc`'s exact `from_abstr` pipeline, zero
line numbers, and FFI-call shape without losing the annotation on a two-function case — so the
"one shape tweak fixes it" premise may simply be false, and the real cause may only exist at the
scale of the actual multi-function module.

**Candidate 3 — accept the JIT boundary as a ceiling `bs_emit` cannot reach, and stop paying for
the attempt.**
Compiler delta: none to `bs_emit`'s type handling; instead, treat ticket 13's widened `-spec`
emission and this ticket as decided independently, since (a) already shows they don't interact.
No code changes to the hot path at all — this "fix" is closing ticket 39 as "not a code defect,"
on the ground that the annotation is an OTP-internal optimizer artifact with no supported
front-end lever, and the 20% is the price of `beam_ssa_type` not recognizing beam-sharp's forms
as a pattern it narrows, which may never be closeable without patching `beam_ssa_type` itself
(out of scope for a language front-end). **Why it might not be justified:** ticket 39 §2 already
established the gap should not exist in principle — beam-sharp's checker holds a *stronger* fact
(`ticket 20`'s exact intervals) than Erlang's analyser reconstructs, so declaring a ceiling here
means asserting Erlang's decades-old success-typing pass is unreachable by construction, which
this audit did not establish — it only ran out of cheap mechanical hypotheses to test without
`bsc` itself.

## What a from-scratch re-check (in place of a separate agent) found

No agent-spawning tool was available in this session (no `Task`/general subagent tool was present
in the toolset given to this run — `SendMessage` requires an existing peer agent, which none was).
In its place, the two load-bearing claims were re-run **from a clean state**, independently of the
first pass's working files:

- **Baseline `{tr,...}` reproduction**: re-copied `wrap1.erl` into a fresh directory and re-ran
  `erlc +to_asm`, counting `tr,` occurrences with `grep -c` rather than eyeballing — 1 match,
  consistent with the first run.
- **`bsc` build failure**: re-ran from `rebar3 clean` (not just a fresh shell) with
  `DIAGNOSTIC=1`, and got the underlying stack trace directly rather than the earlier truncated
  warning dump: `{leex,file,[...,{error_location,column}],...}` → `badarg`, from
  `leex.erl:137` — this is `leex` itself rejecting the option, not a downstream symptom. This is a
  *harder* form of the same finding, not merely a repeat of it.

**Neither hand-edited a disassembly or a result to fit an expected answer** — every number and
instruction listing in this brief and its probe transcript came from an invoked `erlc`, `elixir`,
`compile:forms`, or `beam_disasm` call, shown with its command. The one place this brief
paraphrases rather than quotes verbatim is the two OTP source snippets pulled via WebFetch
(`beam_ssa_type.erl`, `beam_ssa_codegen.erl`), which are stated as summarized, not verbatim, and
flagged as such above.

## Sources consulted

- `wayfinder/issues/39-emitted-code-quality.md`, `aoc/bench/README.md`, `aoc/bench/bench_erl.erl`,
  `aoc/bench/Day01/bench_bs.bs`, `aoc/bench/gleam/src/bench_gleam.gleam`.
- `compiler/src/bsc.erl:810-854` (the `.abstr` write + `compile:file` call), `compiler/src/
  bs_emit.erl:1-20,146` (`-define(A, 0)`, the `{function, ?A, ...}` construction).
- `github.com/erlang/otp` `lib/compiler/src/beam_ssa_type.erl`,
  `lib/compiler/src/beam_ssa_codegen.erl` (fetched live, `master` branch).
- `github.com/gleam-lang/gleam` `compiler-core/src/erlang.rs`, `function_spec_attribute` (fetched
  live) — confirms Gleam emits `-spec` for its own reasons, and that this is irrelevant to the
  JIT annotation for the same reason beam-sharp's own `-spec` is (§(a)/1).
- `/usr/lib/elixir/lib/elixir/ebin/*.beam`, decompiled via `beam_lib:chunks(.., [abstract_code])`
  since no `.ex` source tree is installed on this machine (checked: only `ebin/` exists under
  `/usr/lib/elixir`) — real function names and line numbers recovered from the `file` attribute
  embedded in the compiled abstract code (`lib/module/types.ex`, `src/elixir_erl_compiler.erl`).
  `elixir_erl_compiler.erl:33-44` (`erl_to_core/2`, calling `v3_core:module/2` directly) and
  `:45-65` (`compile/3`, `CompileOpts = [no_spawn_compiler_process | Opts]`, then
  `compile:noenv_forms(CoreForms, CompileOpts)`) show Elixir enters the standard pipeline one
  stage later than beam-sharp's `from_abstr` (at Core Erlang rather than Abstract Format) but
  through the same `beam_ssa_opt`/`beam_ssa_type` machinery — this rules out "Elixir passes a
  special compile option" as an explanation for Elixir's parity with Erlang, symmetric to (a)'s
  finding for beam-sharp.

---

No plain sentence of personal opinion follows a rule that bans recommendations here, but one is
allowed, separated from the evidence: my honest read is that Candidate 1 is the only one of the
three actually worth doing before anything else, because every hypothesis reachable without an
OTP-28 `bsc` build has now been executed and refuted.
