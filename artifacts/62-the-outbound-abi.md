# Ticket 62: the outbound ABI, function-name casing as seen from Elixir

Ticket: [62](../wayfinder/issues/62-the-outbound-abi.md), [ENG-252](https://linear.app/davewil/issue/ENG-252)
Date: 2026-09-29. Compiler at `41b47c2`. OTP 25, Elixir 1.14.0, Gleam 1.12.0 (the ticket cites OTP 28, gleam 1.18.1).
Status: decision open, for human review.

Scope. The prefix question and the `Kind`-contract documentation are answered in the ticket
("The prefix question is answered and should not be re-opened", "Answered 2026-08-25 ... LANGUAGE.md §12")
and are not reopened here. Only function-name casing is open.

## The headline finding

**The ticket's premise is incomplete: Elixir can call a PascalCase export with dot syntax.**
`:Api."New"(1)` (quoted function name) parses, compiles inside a `defmodule`, survives
`Code.format_string!`, emits no warning, pipes, captures (`&:Api."New"/1`), and combines with
`alias :Api, as: Api` to give `Api."New"(1)` (p1, p1b, p1c). The ticket's §1 table and
LANGUAGE.md §12 (lines 3123-3126: "`apply(:Shop, :New, [1])  # the way in`") do not list it.
Elixir's own error messages render such a function as `:Api."Total"/1` (p1b), i.e. Elixir treats the
quoted form as the canonical spelling of a non-conventional name.
This changes sub-decision (a): the zero-cost answer is not "use `apply/3`", it is "use the quoted call".

## 1) Sub-decisions, gating first

| # | Question | Gates |
|---|---|---|
| a | Is incremental adoption inside an Elixir codebase a goal at all, and if so, does `Api."New"(1)` serve it? | everything below; if yes-and-served, b, c and d are never asked |
| b | If not served: extra alias exports, different emission, or a snake_case source convention? | c, d |
| c | If aliases: the derivation rule, and automatic or per-function opt-in | d |
| d | Who owns a collision and how is it diagnosed | none |

Prior decisions checked (grep of `wayfinder/issues/*.md`, `CONTEXT.md`, `LANGUAGE.md`):
- Ticket 32 §3: "There is no snake_case ⇄ PascalCase rule anywhere in the language" (32-ffi-surface.md:204, :344). That was decided for the inbound direction, on the evidence that a mapping "cannot spell 'PKCS-1' ... or a quarter of Elixir's function names". Outbound is additive, so that evidence does not transfer, but option B is the first such rule in the language.
- Ticket 87 (87-an-export-the-author-did-not-write.md:83-86): an emitted module may export a function the author did not write, under the compiler's `bs@` prefix. An alias is a different class: unprefixed, author-visible, collidable.
- Ticket 26: functions are PascalCase (26-data-modelling.md:475-488); `uident` is `{UPPER}{ALNUM}*` with `ALNUM = [a-zA-Z0-9_]` (bs_lexer.xrl:14-16, :150), so `Get_x` is a legal name.
- Ticket 10 §7 (10-atoms-in-a-csharp-skin.md:335) is the source of the "Gleam downcases" claim. See probe 4: it concerns constructors, not functions.
- CONTEXT.md has no entry for "alias" or "snake"; no term is coined below beyond "alias export" (a plain description).

## 2) Probes

All under `artifacts/probes/62/`; `run.sh` runs them all (~30 s) and prints PASS/FAIL. Expectations are
written in each file's header before the first run. p6 is red on purpose (wrong expectation); p3 is red intermittently (E4 load-time, noise); see notes.

| id | claim tested | expected before run | observed | file |
|---|---|---|---|---|
| p1 | Elixir 1.14 parse/run table for `'Api':'New'/1` | `:Api.New(1)` and the ticket's other rows SYNTAX_ERROR; `:Api."New"(1)` parses and runs (hypothesis); `apply/3`, `Kernel.apply`, `Function.capture` run; `unquote` form not runnable; `&:Api.New/1` SYNTAX_ERROR | all matched. `:Api."New"(1)`, `:"Api"."New"(1)`, `mod."New"(1)`, `(&:Api."New"/1).(1)` run. `:"Api".unquote(:New)(1)` parses then CompileError. `mod.New(1)` SYNTAX_ERROR (no prediction made) | `p1_elixir_parse.exs`, `expected_p1.txt`, `out/p1.txt` |
| p1b | quoted call survives real tooling | compiles with no warning, formatter keeps quotes, pipe and capture work | matched; stack trace prints `:Api."Total"(%{...})` and `src/Api/api.bs:22` | `p1b_elixir_in_module.exs`, `out/p1b.txt` |
| p1c | `alias :Api, as: Api`; and what the caller types when aliases exist | alias works in both builds; snake names absent in plain build, present in alias build; `HTTPGet` becomes `h_t_t_p_get` | matched (`Api."New"(1)` works; `:Api.get_x(1)`=2, `:Api.h_t_t_p_get(1)`=3, `:Api.http_get` undefined) | `p1c_elixir_alias_and_snake.exs`, `out/p1c_*.txt` |
| p2 | a real B# module (built with the reference compiler) called from Erlang | exports are PascalCase plus `bs@type_atoms/0`; `'Api':'New'(1)` works; `get_x` is `undef` | matched. First run FAILed only because my hand-written expected list was mis-sorted (`GetX` < `Get_X`); comparison now sorts, noted in the file | `p2_erlang_call.escript`, `src/Api/api.bs`, `out/p2.txt` |
| p3 | cost of a snake_case wrapper beside each export (patched compiler copy) | see section 4 | E1-E3, E5, E6 matched; E4 (alias slower, all n) is noise-flaky: it FAILed in most of my 5 runs and PASSed in the last (at n<=10 the ratio ranged 0.89-1.13) | `p3_measure_alias.escript`, `p3loop.erl`, `alias.patch`, `out/p3.txt` |
| p3b | two export names sharing one code label (beam rewrite of AtU8+ExpT) | loads, same value, stack names callee, +1 export | matched | `p3b_label_alias.escript`, `out/p3b.txt` |
| p3c | wrapper in stack traces and call tracing | alias absent from stacktrace; two trace events per alias call | matched | `p3c_trace_stack.escript`, `out/p3c.txt` |
| p4 | what Gleam 1.12 emits for `pub fn` and constructor names | functions unchanged; `MyVariant`->`my_variant`; `HTTPGet`->`h_t_t_p_get`; PascalCase function is a compile error | matched | `gleam_names/`, `gleam_bad/`, `out/gnames.erl`, `out/gleam_bad.txt` |
| p5 | how Elixir names `def` functions | snake atoms with `?`/`!`; PascalCase only via `unquote(:New)`; bare `def New` a syntax error | matched | `p5_elixir_def_names.exs`, `out/p5.txt` |
| p6 | derivation rules R1 (Gleam's) and R2 (acronym-aware); collision census over the repo's `.bs` corpus | R1 reproduces Gleam's 9 atoms; synthetic collisions as predicted; 0 real collisions; corpus has >=1 acronym name | first four matched. **ACR-real FAILED**: 0 of 155 distinct public names have two consecutive capitals; my expectation was wrong and is left red | `p6_rule.escript`, `out/p6.txt` |
| p6b | real compile of `GetX` + `Get_x` with and without aliases | reference compiler compiles; alias copy fails naming `get_x` and both names | matched, but the failure is a raw Erlang crash from the experiment, not a B# diagnostic | `p6b_collision.sh`, `src/Coll/coll.bs`, `out/p6b.txt` |
| p7 | Gleam calls `'Api':'New'` and `'Api':'Get_X'` for real | compiles and runs, prints the map and 4 | matched: `gleam run` printed `new: #{'Id' => 1,'Kind' => 'Api.Order','Total' => 0}` and `get_x_pascal: 4`. The ticket's "compiled, not run" is superseded | `gleam_ext/`, `out/p7.txt` |
| p8 | "different emission": emit snake_case only (patch `bs_emit:emitted_name/3`) | Shop compiles; `Shop.Billing` compiles but fails at run time (`undef`); Erlang callers of `'New'` break | matched: `Billing.label -> undef 'Shop':'Which'` | `p8_rename_emission.sh`, `out/p8.txt` |

## 3) Neighbouring languages

- **Gleam.** Binary only, no source installed. Behaviour probed (p4, p7).
  - Functions are never converted. `pub fn GetX` is refused: `I'm expecting a lowercase name here` (`out/gleam_bad.txt`). So "Gleam downcases when it emits" (ticket 62 §"The decision"; 10 §7) is true of **constructors only** (`out/gnames.erl`: `MyVariant` -> `{my_variant, integer()}`, `HTTPGet` -> `h_t_t_p_get`, `X1Y` -> `x1_y`, `Parse2Ints` -> `parse2_ints`). Gleam never had a PascalCase function to convert, so it is no precedent for aliasing functions for interop.
  - Gleam's rule, as observed and reproduced 9/9 by `r1/1` in `p6_rule.escript`: every capital is lowercased and preceded by `_` unless first. Acronyms are not kept together.
  - `@external(erlang, "Api", "New")` compiles and **runs** (p7). Gleam callers are unaffected by PascalCase. The ticket's note is out of date on 1.12.
- **Elixir.** Source not installed (`/usr/lib/elixir/lib/elixir` holds only `ebin`), so nothing is cited from source. Behaviour probed (p1, p5): an ordinary `def` yields snake atoms (`get_x`, `valid?`, `fetch!`); a PascalCase function exists only through `def unquote(:New)(x)`, exports `New/1`, and is called as `Naming."New"(1)`. So the quoted form is the Elixir-sanctioned spelling for exactly this case.
- **Erlang.** Source not needed; `'Api':'New'(1)` works (p2). The compiler's own precedent for PascalCase-to-snake is an **explicit table**, not a rule: `bs_otp.erl:40-49` (`HandleCall`->`handle_call`, `FormatStatus`->`format_status`), applied at `bs_otp.erl:83-89` via `bs_emit.erl:124-128`.
- **Elm.** Compiles to JS, not BEAM: not applicable. Not probed.

## 4) Measurements (OTP 25, JIT, 4 cores; `out/p3.txt`)

Subject: modules `N<n>` of n public functions, each two clauses (`GetItem<i>(0) -> 0; GetItem<i>(x) -> x + i`).
"plain" is the patched compiler copy with the patch inert; its `.abstr` is byte-identical to the reference
compiler's for all four sizes. "alias" is `BS_ALIAS=wrapper`.

| n | .beam bytes plain | alias | ratio | exports plain | alias | load us plain | alias | ratio |
|---|---|---|---|---|---|---|---|---|
| 1 | 976 | 1048 | 1.07 | 4 | 5 | 614 | 621 | 1.01 |
| 10 | 2016 | 2528 | 1.25 | 13 | 23 | 600 | 644 | 1.07 |
| 100 | 12724 | 17812 | 1.40 | 103 | 203 | 1136 | 1291 | 1.14 |
| 1000 | 119920 | 172876 | 1.44 | 1003 | 2003 | 4632 | 6675 | 1.44 |

Bytes are exact for a fixed output path (the CInf chunk embeds it; a build in another directory gave 2012 instead of 2016 bytes at n=10). Load time is the median of 30 `timer:tc(code, load_binary, ...)` runs, and is
noisy: across five runs n=100 gave ratios 1.14-1.55 and n=1000 1.32-1.68; at n<=10 the ratio ranged 0.89-1.13, so alias was sometimes faster.
Export count is `length(Mod:module_info(exports))`, so alias adds exactly n.

- **Wrapper is a tail call.** `beam_disasm` of `get_item5/1`: `{func_info,...}`, `{call_only,1,{'N10','GetItem5',1}}`, nothing else. It is one extra function and no frame.
- **Call overhead.** 1e7 external calls, 7 runs after a warm-up: direct 8.12-8.57 ns median, alias 8.19-8.42 ns median, alias minus direct median -0.22 ns (range -0.89 to +0.17 in the last run; +0.07 in an earlier one). Not distinguishable from zero on OTP 25/JIT. Loop overhead alone is ~4.2 ns.
- **Stack traces (p3c).** A crash entered through the alias shows `'GetItem5'` as the first frame and no `get_item5` frame, so the wrapper does not clutter traces, but a caller who wrote `get_item5` sees a name they did not call.
- **Call tracing (p3c).** One alias call yields two call events (`get_item5`, then `'GetItem5'`); one direct call yields one. `eprof`/`cprof`-style tools would count each alias call twice (tracing shown; profilers not run).
- **Second export label (p3b).** Two names at one code label is possible in the beam format: after rewriting the `AtU8` and `ExpT` chunks the module loads, `get_item5(1) =:= 'GetItem5'(1)`, exports grow by one, and no code is duplicated. But the compiler emits Abstract Format and calls `compile:file` with `from_abstr` (bsc.erl:843), and an `-export` cannot name one body twice, so this route needs a post-compile beam-rewriting pass. Not built beyond the probe.

## 5) Options

Every option leaves Erlang callers on `'Api':'New'(1)` and leaves the record/`Kind` contract untouched
(aliases do nothing for §2 and §3 of the ticket).

### Option A. Keep PascalCase, no compiler change; document the quoted call

B# program (unchanged):
```
module Api
record Order { Id: int, Total: int }
public Order New(int id)
New(id) -> Order{ Id = id, Total = 0 }
```
Elixir caller:
```elixir
alias :Api, as: Api
Api."New"(1)                # or :Api."New"(1), 1 |> Api."New"(), &Api."New"/1
```
Refused under this option: nothing new. `:Api.New(1)` stays a SyntaxError.

Compiler delta: none. Docs delta: LANGUAGE.md §12, "Function names are exported PascalCase" (lines 3115-3129), replace the `apply(:Shop, :New, [1])  # the way in` line and the sentence "costs Elixir its call syntax" with the quoted-call spelling; the ticket's §1 table gets the missing row. Zero bytes, zero exports, zero call cost.

Evidence: p1, p1b, p1c, p5. Also answers sub-decision (a): incremental adoption is served, at the cost of two quote characters per call site.

Strongest counterargument: every Elixir call site carries `"..."` around a name Elixir style guides would write bare, forever, and it reads as a hack to the reviewers of the codebase being adopted into. The ticket names incremental adoption "the likeliest way anyone tries it", and the first thing that adopter sees is unidiomatic quoting. Nothing here measures how an Elixir developer weighs that; this is the judgement the option turns on. Not measured: IEx tab completion of `:Api.` (would list PascalCase names), credo/dialyzer behaviour on quoted calls.

### Option B. Automatic snake_case alias export for every public function

B# program (unchanged source; the compiler adds the aliases):
```
public int GetX(int x)
GetX(x) -> x + 1
public int HTTPGet(int x)
HTTPGet(x) -> x + 2
```
Elixir caller: `:Api.get_x(1)`; under Gleam's rule `HTTPGet` is `:Api.h_t_t_p_get(1)` (p1c). Under the
acronym-aware rule R2 it would be `:Api.http_get(1)`.
Refused under this option (and compiles without it): a module with public `GetX` and `Get_x` (p6b), and,
under R2, `HTTPGet` next to `HttpGet`.

Compiler delta, all measured in the copy (`alias.patch`, 78 lines against `bs_emit.erl`):
- `bs_emit:forms/1` (line 31): append `alias_exports/3` to the `export` attribute built at line 76.
- new `snake/1` (the rule), `alias_pairs/3`, `alias_forms/3`: one `{function, _, Alias, N, [{clause, _, Vars, [], [{call, _, {atom, _, Name}, Vars}]}]}` per public function.
- collision check inside `alias_pairs/3`: currently `erlang:error({alias_collision, ...})`. A shipped version needs a `bs_diag` term naming both spans, a symbol-table entry (aliases beside `exports` in the module world) so B# callers and `--api` know the alias, and a rule for aliases of callback names (`HandleCall` is already emitted as `handle_call`, so it is skipped).
- `-spec` for the wrapper (not emitted in the copy).
- LANGUAGE.md §12 gains the rule and a collision rule.

Evidence: section 4. +7% to +44% `.beam` bytes for B#-emitted modules (ratio grows with n; the verifier's pure-Erlang one-wrapper-per-function control grew 1.64x at n=100 and 1.76x at n=1000, so the ratio depends on the baseline module), export table doubles, load time ratio 0.98-1.25 at n=100 and 1.33-1.62 at n=1000 across author and verifier runs (about +2 ms at 1000, noisy), call overhead under 1 ns (author's loop 0.0, verifier's loop +0.6 ns), tail call, alias vanishes from stack traces but appears twice in call tracing. Rule: R1 reproduces Gleam's constructor atoms 9/9; over the repo's 155 distinct public names there are 0 collisions under R1 or R2, and 0 names with an acronym, so no real program yet exercises either the ugly R1 cases or the R2 collisions.

Strongest counterarguments:
1. **Two exports per function**, visible to xref, dialyzer, `module_info`, IEx completion and Erlang tooling, in an unprefixed namespace (ticket 87 put compiler-added exports under `bs@` precisely so authors' names are never confused with them). The alias set becomes part of the ABI: renaming a B# function now changes two public names.
2. **Collisions.** `GetX`/`Get_x` is a legal B# pair that collides under R1 (p6, p6b); R2 trades that for `HTTPGet`/`HttpGet`. Any rule has a legal source pair that collides, so a diagnostic and an owner are required.
3. **R1 is the wrong rule for Elixir callers.** Gleam's rule is measured to give `h_t_t_p_get`; nobody would guess it from `HTTPGet`. R2 gives what Elixir authors expect but is not Gleam's rule and so loses the "a neighbour already ships it" argument in the ticket.
4. **It hides a cost in observability** (p3c): one alias call is two trace events, and a caller sees a name in profiles that the stack never shows.

### Option C. Per-function opt-in alias, or the alternatives to aliasing

C1, opt-in alias. B# program:
```
public alias int GetX(int x)      // syntax invented for this brief; not in the grammar
GetX(x) -> x + 1
```
Delta: everything in B, scoped to marked functions, plus a new declaration modifier. The grammar has no attribute or modifier position today: `signature -> visibility type_expr uident '(' params ')'` (bs_parser.yrl:308) and `visibility` is `public | private` (bs_parser.yrl:323). So: a lexer reserved word or bracket form, a `signature` production, a `#fn` field, and the checker/emitter reads. Not built; cost unmeasured beyond option B's emission cost, which scales with the number of marked functions.
Counterargument: the author must predict which functions Elixir callers use and remembers to mark them; the module's ABI is inconsistent (some functions have two names). It adds surface to a language whose CLAUDE.md forbids checks that guard tracking rather than the language, so the mark itself needs a reason to exist beyond convenience.

C2, different emission (snake_case only). `bs_emit:emitted_name/3` (bs_emit.erl:124) is "the one place" a name becomes an Erlang one (header comment, lines 107-110), so the one-line patch is trivial. p8 measures what else breaks: `Shop` then exports `amount, band, bump, new, pay, squared`, but `Shop.Billing`, compiled by the same patched compiler, calls `'Shop':'Which'` and fails at run time with `undef`, because `bs_check:remote_names/1` (bs_check.erl:572) records callee names only for OTP callbacks and `bs_emit:remote/5` falls back to the written name. A real change therefore also edits `bs_check`. It also breaks every existing Erlang caller of `'Shop':'New'` and contradicts ticket 26's PascalCase functions. Counterargument is the whole ticket's: it is the "largest blast radius" candidate, and it needs a new decision about what casing the source language has, since B# then reads PascalCase and emits snake_case.

C3, snake_case source convention. Not built or probed. Blast radius counted, not tested: 161 `.bs` files in 120 module directories and 252 public function definitions use PascalCase (p6); `uident` (bs_lexer.xrl:150) and ticket 26's casing rule (lowercase is a value and projects, PascalCase qualifies: 26-data-modelling.md:475-488) would both change. Counterargument: it removes the syntax that separates a call from a projection.

## 6) Recommendation

**Option A now: accept PascalCase and document the quoted call.** Reasons, in order:
1. The evidence removes the ticket's stated harm. `apply/3` is not the only way in; a dotted, formatter-stable, warning-free call exists, and Elixir itself prints such functions in that form.
2. Every alternative costs something measured or unbuilt: B costs 7-44% more bytes, a doubled export table, load time, an ABI set to maintain and a collision diagnostic that does not exist; C2 breaks cross-module calls until `bs_check` changes; C1 needs new syntax; C3 fights ticket 26.
3. A is reversible. Aliases can be added later without breaking any caller, because they only add exports; the reverse (removing aliases people call) is not reversible. That asymmetry favours waiting.
4. CLAUDE.md asks for a second occurrence before adding machinery. There is not one: the corpus has no acronym names and no collisions, and no Elixir user has been measured disliking the quoted spelling.

This is a taste judgement that only David can make: whether `Api."New"(1)` is pleasant enough. If it is not, choose B with rule R2 and an owner-side collision error (the B# author owns the collision, diagnosed at the second declaration with both spans, by name-derived error), not R1, since R1's `h_t_t_p_get` was measured. Sub-decision (d), if reached: the B# author owns it, because the aliases are B#'s emission and only the compiler sees both names.

Proposed follow-ups that are not decisions: correct LANGUAGE.md §12 and the ticket's §1 table (the false "apply/3 is the way in"), and drop "compiled, not run" from the Gleam note.

## 7) Not measured, limits

- **Toolchain versions.** Probes ran on OTP 25, Elixir 1.14.0, Gleam 1.12.0; the ticket used OTP 28, gleam 1.18.1. The parse table matches the ticket's rows, but parser behaviour on Elixir 1.19+ and OTP 28 was not re-run. Load-time and call-overhead numbers are OTP 25 JIT on a 4-core VM and will differ.
- **Compiler copy.** `alias.patch` is applied to a copy of `compiler/src`; the lexer generator is the OTP-25-patched one from the scratchpad build. The repo's `compiler/` was not edited. The copy's `.abstr` is identical to the reference compiler's with the patch inert, but `.beam` bytes differ by up to 4 bytes (CInf chunk), so the plain column comes from the copy, not the reference compiler.
- **Expectation hygiene.** p3's .beam byte sizes had been seen once before its expectations were written (noted in the file), so E2 is not independent. E4 is flaky by nature (pre-stated for all n, fails at small n by noise); E4b was written after seeing that and is post-hoc, descriptive only, and also flaky; `run.sh` can print FAIL for p3 (E4 passed 3 of 7 verifier executions). p2's first run failed on my mis-sorted expected list. p6's ACR-real is red because my expectation was wrong. Nothing was patched to turn a red green.
- **Not measured:** how Elixir developers judge the quoted spelling; IEx completion and credo/dialyzer on quoted calls; `eprof`/`cprof` output (tracing only); memory per loaded module; `mix compile` xref warnings for `:Api."New"` when the module is unavailable at compile time; Elm (not BEAM); behaviour of the alias under hot code loading; any B#-side symbol-table or `--api` change for aliases; the cost of the invented C1 syntax; C3.
- Elixir and Gleam sources are not installed, so no `file:line` is cited for either; every claim about them rests on a probe.

## 8) Reproduce

```
artifacts/probes/62/run.sh          # all probes; ends with a PASS/FAIL summary (p6 red by design)
# individually, after run.sh has built the work dir (W=$SP/work/62, SP = the scratchpad):
BS_EBIN=$W/out elixir artifacts/probes/62/p1_elixir_parse.exs
escript artifacts/probes/62/p3_measure_alias.escript $W/b_ctrl $W/b_alias
artifacts/probes/62/p6b_collision.sh $SP/bsc.sh $W/alias-bsc/ebin $W/coll
```
`run.sh` copies `compiler/src`, applies `alias.patch` to the copy, builds it with `build_compiler.sh`, and
generates the n=1/10/100/1000 modules with `gen_modules.py`. Captured outputs are in `artifacts/probes/62/out/`.

## Verifier corrections (independent re-run, 2026-09-29)

Central claim `:Api."New"(1)` works on Elixir 1.14 REPRODUCED (own beam, real B# module, ticket's Shop table). Gleam claims REPRODUCED (`pub fn GetX` rejected; `HTTPGet`->`h_t_t_p_get`; `@external` runs). Corpus counts REPRODUCED (161 files, 252 public lines, 155 names, 0 acronyms, 0 collisions), with two caveats: no public name contains `_`, so the `Get_x`/`Get_X` collision is synthetic, and private functions are uncounted.
- p6b's alias half is tautological (the collision error is raised by the author's own patch); only the reference-compiler half (`GetX` and `Get_x` compile) says anything about B#.
- R1 was inferred from the same 9 constructors it is reproduced against; held-out constructors (`HTTPServerError`->`h_t_t_p_server_error`, `XMLHttp`->`x_m_l_http`, `IOError2`->`i_o_error2`) also match.
- p1's `expected_p1.txt` holds rows the `.exs` header did not predict (`HTTPGet`, `:erlang.apply`, capture, `Function.capture`, `mod.New(1)`); the SYNTAX_ERROR rows were predicted.
- p3 E2 (byte band) and E5 (<10 ns) are too loose to fail.
- A real snake_case-only emission must also touch `bs_emit.erl:1070`, a second remote-name lookup not covered above.
- Elixir tested was 1.14.0 only; 1.19+ parser behaviour is not measured.
