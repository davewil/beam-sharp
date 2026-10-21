# Verifier report: probes 59, 60, 62, 64, 65

Run: `RESULTS=artifacts/verification/results ./run_all.sh` (all 19 ran; every `exit=0`, but see PROBLEM 8: that code is uninformative).
Diff: `diff_results.sh` / `diff_results.out` (mktemp paths normalised, timing digits compared by eye).
My scripts and outputs: `f1/` ... `f6/` in this directory.

## Table

| probe | reproduces? | circular? | reason (file:line) |
|---|---|---|---|
| 59-p1 | yes, identical | no | emitted forms come from `bsc` + `dump_abstr.escript:3-8` (p1_emitted_guards.sh:4-5) |
| 59-p2 | yes, identical | no | forged args go through real bsc; `tail -1` (p2:7-14) drops the stack, so "crashed in the private callee" is not shown by the probe. I confirmed it (F2) |
| 59-p3 | yes, identical | no (caveat) | `compile_corpus.sh` real; `p3_guard_census.sh:4` `tail -3` hides 5 of 7 not-buildable dirs; `escript:21` counts the author's own `when is_integer`, so the `int/kind=46` column mixes emitted and hand-written tests (header admits the upper bound) |
| 59-p4 | yes (timing within noise) | misleading header | hand-written Erlang (declared), but header line 3 says "default compiler options (as bsc uses)" and bsc uses `debug_info` (`compiler/src/bsc.erl:843`); probe compiles `[binary]` (escript:53-54). Byte figures roughly double with debug_info (F6) |
| 59-p5 | yes, identical | no | real Elixir compile, debug_info forms read back (p5:8-12) |
| 60-p1 | yes (compile time digits) | no | real gleam builds; `echo "exit=$?"` (p1:40) reports `head`'s status, not gleam's. I read gleam source: no import enforcement |
| 60-p2 | yes, identical | no | header line 3 says Elixir runs on a system OTP without 28; it actually ran on OTP 28 (output "compiled with Erlang/OTP 28", `env.sh:5` puts otp28 first). Probe shows callability only, never "hidden from docs" |
| 60-p3 | yes, identical | no | real bsc refusal text for private; public call returns 12; Elixir call is real |
| 62-p1 | yes, but saved file stale | no | saved `62-p1.txt` lacks the last section (formatter / `Q.go`); current script prints it. Conclusion unchanged |
| 62-p2 | yes | no | Gleam's own `.erl` output is grepped (p2:33); the casing claim does not rest on the Python port |
| 62-p3 | yes, identical | partly | regex `[^()=\n]*?` (p3:20) skips signatures whose return type is a tuple (`(:ok, State) Init(...)`): finds 101 names, my broader regex finds 107 across the same 29 modules. 0 collisions and no digit/acronym names survive. Port of `to_snake_case` matches `strings.rs:70-96` |
| 62-p4 | yes (tmp names differ) | measured on synthetic aliases (declared) | `compile:forms [binary, return_errors]` (escript:41) without debug_info; header "only the aliases differ" is true, but absolute bytes are not bsc's. 34.1 B/alias becomes 65.0 B with debug_info; 9.8% growth becomes 10.5% |
| 64-p1 | yes (timing within noise) | partly | `repr_cost.erl:18-25` `ambiguity()` is hard-coded funs that return `nothing` by construction, so "distinguishable? false" is a tautology and not bsc behaviour. Timing: `put/2` into the process dictionary (`:30`) makes the tuple live data, so 11.6 ns/op is not the cost of a returned `{some,V}` (F6b: 0.6-1.1 ns) |
| 64-p2 | yes | no | real Elixir and Gleam |
| 64-p3 | yes, but saved file stale | no | saved rows for accepted types print just `module X`; current script prints the signature. Verdicts (A refused, B/C/D accepted) identical |
| 64-p4 | yes, identical | no | real bsc runs of B# code |
| 65-p1 | yes, identical | no (caveat) | rows C1 and C3 are refused with `syntax error before: option/term` (lowercase type names do not parse), not with a reservation error, so they say nothing about reserved names |
| 65-p2 | yes | no (caveats) | `(exit $?)` (p2:21) is `tr`'s status. The Gleam same-path case only prints "Compiled": the two-beam / path-order effect is not demonstrated (see F5) |
| 65-p3 | yes (VM crash) | staged | crash is forced by `:code.purge/delete` plus `prepend_path` (p3:11-12). The "load B# Elixir.Enum" line never prints. A control run (F4c) with the same sequence minus the B# dir survives, so the B# beam is the cause |

## Circularity audit

a. Expected results made by the probe's own setup:
- `repr_cost.erl:18-25` is the only forced result: both finders are written in the probe and the bare one returns `nothing` for both cases by construction. 64-p4 is the real test and gives the same answer.
- 59-p4, 62-p4, 64-p1 timing use hand-built Erlang or alias forms. Each says so in its header.
- No probe edits a bsc output and then reports it as the compiler's behaviour.

b. Swallowed failures:
- `59/p2:7-14` `tail -1`.
- `59/p3:4`, `62/p4:3` `| tail -3 &&`: the `&&` tests `tail`, not the corpus build.
- `60/p1:40`, `65/p2:21`: `exit=$?` and `(exit $?)` report the status of `head` / `tr`.
- `run_all.sh:5`: `exit=$?` is the last pipeline stage, so all 19 print `exit=0`, including probes whose last step is an expected failure (62-p2 b2).
- `65/p2:21`: `[ -x $E ] &&` skips a missing erlc silently.
- Each of these still prints the failing text where one exists. None turns a failure into a pass-looking line.

c. Timing and size:
- Distinct module names are used where two modules are loaded (`59-p4:33`, `:61`). Both loops use the same options.
- The compiler cannot delete the measured work. I disassembled the guarded and unguarded int `f1`: it stays a real `call` and the guard is three live tests (F6).
- Like for like on options, but not bsc's options: `debug_info` is missing (PROBLEM 1).

d. Toolchain versions: only `60-p2` header is wrong (PROBLEM 6). 65-p2's OTP 25 vs 28 comparison is deliberate and labelled.

## Falsification

**F1 (Elixir call syntax)**, `f1/f1.out`. `:Shop."New"(1)` runs and returns the map. `:Shop.New(1)` is a SyntaxError ("unexpected ( after alias New"). Also `:"Shop".New(1)` fails and `:"Shop"."New"(1)` runs. For my module `'Hy'`: `:Hy."PKCS-1"(1)` -> `{:pkcs,1}`, `:Hy."1st"(1)` -> `{:first,1}` and `:Hy."A b"(1)` -> `{:ab,1}` all run. The unquoted `:Hy.PKCS-1(1)` and `:Hy.1st(1)` are SyntaxErrors. Quoted form works for any atom. Claim survives.

**F2 (forged inputs against Nested)**, `f2/f2.out`, `f2/st.out` (stack traces from escript).
- Wrong Kind: Direct crashes in `Direct/1` (exported guard); ViaTuple and ViaList crash in the private `PrivTotal/1` (its guard); Inline returns 999.
- Right Kind but missing `Total`: Direct, ViaTuple, ViaList crash `badkey Total` inside `PrivTotal`; Inline crashes `badkey` inside the exported `Inline`. The tag guard checks only `Kind`, not fields.
- Non-map `5`: Direct, ViaTuple, ViaList give function_clause; Inline gives `badmap`.
- Octet: OctetDirect(100.5 / 300 / -1) crash in the exported head. OctetViaTuple returns 100.5, 300, -1, and even `:a`. OctetViaTuple(:a) alone (not a tuple) crashes.
- Emitted Erlang matches: exported Direct and OctetDirect have guards; ViaTuple, ViaList, Inline, OctetViaTuple, PrivOctet have none; PrivTotal has the tag guard. Claim survives.

**F3 (`--api` and term)**, `f3/f3.out`.
- Refused: `option<term>`, `result<term,binary>`, `result<term,term>`.
- Accepted: `result<int,term>`, `result<binary,term>`, `option<map<string,term>>`.
- Mine: record field `option<list<term>>` accepted, `option<int>` field accepted, `option<term>` field and `list<option<term>>` field refused. `type Maybe<T> = (:just,T)|:nothing` at `term` accepted (`:nothing | (:just, term)`); at `int` accepted. `option<Maybe<term>>`, `option<option<term>>`, `result<option<term>,binary>`, `type Wrap<T> = option<T>` at `term`, and `(:w, option<T>)` at `term` all refused (the last with a different error site, `Go.2`). Claim survives.

**F4 (reserved roots)**, `f4/f4.out`, `f4b.out`, `f4c.out`.
- `module Elixir.Enum` compiles and emits `Elixir.Enum.beam`; the beam's module name is `'Elixir.Enum'`.
- `Erlang.Lists`, `Elixir`, `Erlang`, `Gleam.List`, `Elixir.Enum.Foo` also compile, emitting files named `Erlang.Lists.beam` etc. These do not collide with `lists`.
- Lowercase roots `erlang.lists`, `lists`, `kernel` are refused with "syntax error before: lists" (a parse error, not a reservation message).
- Putting the B# beam first via `-pa` does not clobber `Enum`: Enum is already loaded at boot, `Enum.map` still works. Only the probe's explicit `purge`/`delete` triggers the crash, and the control shows that without the B# beam the same sequence works. Claim survives, but it is a staged event.

**F5 (Gleam same-path module)**, derived without the author's script. `f5/f5.out`. `src/gleam/list.gleam` beside the stdlib dependency builds with no warning or error and produces two files, `build/dev/erlang/g/ebin/gleam@list.beam` and `.../gleam_stdlib/ebin/gleam@list.beam` (different md5). `g:main()` returned 3 or 99 depending on which ebin dir came first on the code path. Path-order dependence is real. 65-p2 does not show it.

**F6 (guard cost)**, `f6/run1..5.txt`. Five more runs plus two saved/rerun:
- Tag test per-call delta: 1.48, 1.53, 1.56, 1.67, 1.70, 1.72, 1.72 ns. Min 1.48, median 1.67. Stable well above the noise (plain loop varies ±5 ms of 485; delta is ~80 ms).
- Int test delta: 0.42, 0.50, 0.59, 0.60, 0.62, 0.675, 0.69 ns. Min 0.42, median 0.60. Positive but spread ±0.13 against a mean 0.6, so only roughly stable. The brief's "~0.75 ns" is above every run I saw.
- Bytes without debug_info: tag 14.1 B/guard, int 21.1 B (reproduced).
- Bytes with debug_info (the options bsc uses, `f6/p4_debuginfo.escript`): tag 26.4 B, int 48.1 B at 100 fns.
- `f6/p4a_debuginfo.escript`: aliases 65.0 B each, 10.5% growth.
- bsc's own 31 beams total 69,340 B, near the debug_info probe's "before" total of 67,316 B, so debug_info is the realistic setting.
- F6b (`f6/rc2.erl`): returned-and-matched `{some,V}` costs 0.59-1.13 ns/op, against 11.6 ns in 64-p1.

## PROBLEMS

1. **59-p4 and 62-p4 header/size claim false.** "Default compiler options (as bsc uses)": bsc builds with `debug_info` (`bsc.erl:843`) and the probes do not. Real byte costs are about 1.9x for the tag test (26.4 vs 14.1 B), 2.3x for the int test (48.1 vs 21.1 B) and 1.9x for aliases (65.0 vs 34.1 B). The brief's "14.1 B" and "21 B" figures, and any claim that matches ticket 26a, need rework. Percent growth barely moves (9.8 -> 10.5%).
2. **Int-guard timing in the brief (~0.75 ns)** is above all seven of my measurements (0.42-0.69, median 0.60). The sign holds; the digits don't. The tag-test figure (~1.6 ns) holds.
3. **64-p1 timing is misleading.** 11.6 ns/op measures a tuple stored in the process dictionary (live data surviving GC). A returned-and-matched `{some,V}` costs about 1 ns. The 3-word size figure is fine.
4. **64-p1 `ambiguity()` is a tautology** (hard-coded finders at `repr_cost.erl:18-25`), not evidence about bsc. 64-p4 is the real evidence.
5. **Two saved result files are stale** against current scripts: `62-p1.txt` lacks its last section and `64-p3.txt` shows `module X` where the script now prints the signature. Verdicts unchanged.
6. **60-p2 header** says Elixir runs on a system OTP without 28. It ran on OTP 28. The probe also never shows "hidden from docs", only callability.
7. **62-p3 regex** misses public functions with tuple return types (101 vs 107+ names). The zero-collision conclusion holds on the broader set.
8. **Exit codes carry no information**: `run_all.sh:5` records the last pipeline stage, and `60/p1:40` and `65/p2:21` print `head`'s and `tr`'s status as if it were the tool's. Every result file ends `exit=0` regardless of outcome. `59/p3:4` and `62/p4:3` hide 5 of 7 not-buildable dirs via `tail -3`.
9. **65-p1 rows C1, C3** (`type option<T>`, `type term`) are parse errors on lowercase type names, not evidence of reservation. **65-p2** does not show the Gleam path-order effect, which F5 shows is real. **65-p3** is staged by an explicit purge/delete and has no control; my control (F4c) supports it.
10. `env.sh:6` sets `BSC` from `${BASH_SOURCE:-$0}`; sourced from `sh` outside the probes dir, BSC points at the wrong path (I hit this). Without env.sh the bsc escript runs on the system OTP and every corpus dir fails to compile (`failed-dirs=35`).

No claim failed falsification. F1-F5 reproduce the authors' conclusions. Claims that did not survive as written: byte figures (PROBLEM 1), the ~0.75 ns int figure (2), and the 11.6 ns tagged-success cost if used as a general cost (3).
