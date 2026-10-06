# Independent verification of artifacts/62-the-outbound-abi.md and probes/62

Verifier worked from a copy (scratchpad/verify62/probes, lib.sh SCRATCH repointed), full `run.sh` re-run, then own modules/projects. Author's files untouched.

## Overall verdict

**The brief's evidence is REPRODUCED. Every headline claim survived a clean re-run and independent re-test.** The recommendation (Option A) rests on facts that hold. Defects are confined to: two unsupported/missing raw artefacts, one overbroad sentence, one weak verdict test, and mislabelled attribution to ticket 10. None flips a conclusion.

## 1. Re-run diff (fresh copy, all 18 probes + verdict.sh, no FATAL, all exit=0)

Identical to author's out/ after normalising the scratch path: p01, p02, p03, p04, p07, p09, p12, p13, p14, p15, p16, p17, and every CLAIM line of verdict.out (all 28 identical).

Differences found, all benign:
- p05: only `Compiled in N s` timings and a path-wrap line.
- p06: one extra `=CRASH REPORT=== ... crasher:` log line after the gen_server call (OTP log, nondeterministic); the `{error,{bad_return_value,7}}` result is identical.
- p08 / p08b: absolute beam byte sizes differ by about +24 B per unstripped beam (author N=100 none 20648, mine 20672; corpus total 45980 vs 46112). Cause: the source path is embedded in the beam (debug_info), and my scratch path is longer. Stripped sizes differ by 3-11 B in p08 and are identical in p08b (13285/14733/15554). Percentages are unchanged (corpus thin +10.5% -> mine +10.46%; N=100 thin +30.6% vs +30.7%). **The brief's "bytes, deterministic" holds per path only, not across checkouts.** Exports, ExpT, Code, AtU8 columns are byte-identical.
- p10 (timing): see below. p11 (timing): see below.

### p10 (call cost) and the noise gate
Mine passed the gate on attempt 1 (null spread 0.81 ns): null -0.15 [-0.30..0.51], **thin 1.59 [1.06..1.77]**, dup 0.72 [0.16..1.84]. verdict: thin HOLDS (min 1.06 > null max 0.51), dup REFUTED. Same conclusion as the brief (thin about +1.2..+1.6 ns, dup unresolved). Thin's median is slightly above the brief's "1.2 to 1.5" range.

Could the gate/retry manufacture a favourable result? Judged no:
- The gate tests only the null (`none`) column's spread, not thin, so it cannot pick runs for large thin. The decision rule is thin-min > null-max, the conservative direction.
- Thin's effect is positive in every attempt including rejected noisy ones (median 2.05 and 1.85 in the author's rejected attempts). The retries select quiet windows, not a sign.
- Dup, the unfavourable result for the "dup is slightly costly" story, was reported as unresolved and reproduces as REFUTED.
- Residual weakness: only 9 rounds, one shared 4-core host, JIT only, max 3 retries. The gate does throw away attempts where thin's min was negative (-0.22), but there null was equally wide, so nothing was resolvable there either.

### p11 (load time), my run
N=100 prep median: none 535 [503..589], none2 543, **thin 693 (+158, +30%)**, **dup 998 (+463, +87%)**. N=10: none 125, none2 142, thin 153, dup 186, so thin's +28 is within the none/none2 gap (+17), dup resolved. N=1: unresolved. finish_loading: no resolvable difference. This supports every conclusion in the brief. Brief ranges "none 507-570, thin 660-720, dup 1014-1041" come from three runs; only one run's data is retained, and my dup (998 [960..1025]) sits just under the brief's quoted dup range. See section 5.

## 2. Per-probe verdict

| Probe | Verdict | Reason |
|---|---|---|
| p01 (rerun 62a) | REPRODUCED | Unmodified 62a; rows and "NOT REPRODUCED Gleam" (hex.pm blocked, text in out/p01.out lines 69-70) identical. Not circular: greps the prototype's own output. |
| p02 (quoted call) | REPRODUCED | All 18 rows identical; my own bsc module `Mine` gave `:Mine."Make"(1)` -> 10, `&:Mine."Make"/1` -> 20, `Enum.map(.., &:Mine."Make"/1)` ok. Unquoted `:Mine.Make(1)` and `:Mine.Make/1` fail parse; `import :Mine, only: [Make: 1]; Make(1)` and `"Make"(1)` and `import :Mine; Make(1)` are SyntaxError, import alone ok. Rows are run, not only parsed. CHANGELOG fix of `Totals` is legitimate (Totals is a file; Reports exports Restate/Counted/Fully, confirmed in Totals.bs). |
| p03 (parser text) | REPRODUCED | Real `Code.string_to_quoted` messages. |
| p04 (elixirc/formatter) | REPRODUCED | xref warnings for typo, wrong arity; formatter keeps quotes on "New". |
| p05 (Gleam) | REPRODUCED | My own Gleam 1.18.1 project, no deps: `pub fn Foo()` -> "I'm expecting a lowercase name here"; `FOO_bar` same; constructors `HTTPGet ToJSON Vec3Dot Add2 IOList GetHTTPResponse A B2C` -> `h_t_t_p_get to_j_s_o_n vec3_dot add2 i_o_list get_h_t_t_p_response a b2_c`: per-capital, not acronym-aware. @external run against a bsc beam works. |
| p06 (alias patch, collisions) | REPRODUCED | I rebuilt the patched compiler from compiler-alias.patch (applies cleanly to current compiler/src). Own modules: C1 `HttpGet`+`HTTPGet` -> `alias_collision http_get`; C2 `Module_Info` -> `alias_shadows_existing module_info 1`; C3 `Foo_Bar`+`FooBar` collide; baseline bsc accepts all (exit 0); `BS_ALIAS=none` accepts C1. `erlc` on an Erlang module defining module_info/1 plus an alias fails "function module_info/1 already defined", so the shadow claim is a real hazard, not an artefact. Section C (Init/1 captured by gen_server -> `bad_return_value`; baseline `undef`) reproduces. Circularity: the collision cases are by construction of Rule S (author's own rule), see section 4. |
| p07 (Elixir calls aliases) | REPRODUCED | All 22 incl. do/end/fn/nil/true/when/and/not/case parse unquoted and run; mutation (baseline-compiled Casing) gives UndefinedFunctionError and `undefined function http_get/1 (there is no such import)`. |
| p08 (size) | REPRODUCED (path-dependent absolutes) | Exports 13->23, 103->203 exact; all derived per-function numbers in brief recompute from raw (63 B, 30.7%, 37.0%, 105 B, 51%, AtU8 +17.8, ExpT +12, Code +17/+55, Dbgi +16.5/+12.5). |
| p08b (corpus) | REPRODUCED | +10.5% / +15.6% beam, +10.9% / +17.1% stripped recompute; Label stripped thin 707 > dup 696 is the only thin>dup row; Counter equal. |
| p09 (disasm) | REPRODUCED | `[line,label,func_info,label,call_only]`, no allocate. |
| p10 (call cost) | REPRODUCED (timing) | See above. |
| p11 (load) | REPRODUCED (timing) | See above. |
| p12 (specs) | REPRODUCED | Specs visible for alias iff thin. Dialyzer not run (the brief says so). |
| p13 (stacktrace) | REPRODUCED | thin names Pascal fn, dup names alias. |
| p14 (corpus names) | REPRODUCED | I recomputed names independently: clause-head names (224 distinct) contain no name with two adjacent capitals, `_`, or digit. |
| p15 (defdelegate) | REPRODUCED | My own `defdelegate make(n), to: :Mine, as: :Make` and `http_get ... as: :HTTPGet` work; mutation `as: :make` fails at call. |
| p16 (blast radius) | REPRODUCED | 161 files, 362 signature lines, 604 clause heads recomputed with an independent grep; also 50 `uident` lines in bs_parser.yrl. Undercount direction: block-bodied functions and call sites are not counted, so the real radius is larger, supporting the brief. |
| p17 (callbacks) | REPRODUCED | Counter exports `[{bs@type_atoms,0},{handle_call,3},{handle_cast,2},{init,1}]`. Mutation: same source minus the `behaviour GenServer` line exports `HandleCall/3, HandleCast/2, Init/1` (Pascal). |
| verdict.sh | MOSTLY SOUND, one weak test | See section 4. |

## 3. Mutation tests (premise broken, outcome RED as it should be)

1. Elixir alias calls vs a baseline-compiled Casing: verdict N10 and N17 flip to REFUTED (N18 stays HOLDS).
2. `BS_ALIAS=none` through the alias compiler: exports stay 13 (not 23), size equals baseline; T9's premise fails.
3. Counter minus `behaviour GenServer`: Pascal exports appear; verdict N13 fed that output -> REFUTED.
4. `defdelegate ... as: :make` (wrong target): call fails; verdict N5 fed a broken output -> REFUTED.
5. Gleam `pub fn Foo()` rejected; removing the error phrase from p05.out flips T7 (the inverted test works).
6. Patched compiler with unset/none mode accepts colliding names (collision errors come only from aliasing, not from the baseline).
7. Weak test found (N9, below): fed a fake output where the alias compiler "failed to open file", N9 still prints HOLDS.

## 4. Circularity assessment

- **N9 (private Foo_bar beside public FooBar does not collide)**: verdict.sh passes when the string `exception error` is absent from the Clash4 section. Absence-based: a missing or broken alias compiler would also print HOLDS (mutation 7). Also nearly trivial: the alias of `FooBar` is `foo_bar`, never `Foo_bar`, so the private name can never collide. The result is true but the test cannot fail for the stated reason. Note the unreported converse: a **public** `Foo_bar` beside `FooBar` does collide (my C4: `alias_collision Foo_bar FooBar foo_bar`).
- **N13 regex** `\{handle_call,3\}.*\{init,1\}|\{init,1\}`: the second alternative matches any output containing `{init,1}`, including a Pascal-only export list that has `{'Init',1}`? No (quotes differ), but it is looser than intended. In practice p17.out has the full list, and mutation 3 shows it still goes RED.
- **Collision claims (N6-N8)**: the expected result is partly by construction (Rule S is the author's rule, and `Existing` explicitly seeds module_info/0,1). The facts underneath (baseline accepts both names; B# alphabet admits `_`; module_info/1 clash is a real erlc error) are independent and confirmed, so not circular on the fact, only on the rule.
- **Patched probes**: p06-p13 use the experimental compiler by design and label it so. Baseline vs patched differ only in the variable (BS_ALIAS=none equals baseline).
- **p10 baseline**: `none` has an identical-function null control with two loop copies per target; design sound.
- **p14**: "S and G agree on all 155 names" is a property of a corpus without acronyms, correctly stated as such.
- No `|| true` swallowing that changes a verdict; `head`/`grep -v` filters in p02/p07 drop warnings only (see the p07 finding in section 5).
- **CHANGELOG**: every edit is plausible and none turns a red into a green. The p02 `Totals` -> `Restate` edit is justified by the repo tree. The p10 noise gate is disclosed and reproduced above. Two statements in it are not verifiable (section 5).

## 5. Brief claims not supported by retained raw outputs

1. `out/p10_run1_noisy_in_run_sh.out` (cited in the Measurements table and CHANGELOG as "raw kept") **does not exist** in out/. That row (-0.34 [-1.74..2.23], 1.85, 1.57) is unverifiable. The table's two "raw not retained" rows are honestly flagged; this one is not.
2. "Elixir 1.19 warns `found quoted call "http_get" but the quotes are not required`", cited to p07 in E5: p07.out contains no such text (the script filters those lines out, per CHANGELOG). **The claim is true** (I reproduced it with `:Casing."http_get"(1)` and `:lists."reverse"([1])`), but no retained raw file shows it.
3. Load-time "three full runs" ranges (none 507-570, none2 499-557, dup 1014-1041, N=10 ranges) come from runs not retained; only the final run's data is in p11_raw.txt/p11.out. My run is consistent in direction and within about 2% except dup (998 vs 1014-1041).
4. §1 "no total rule over this alphabet is injective" (E12) is **overbroad as written**: the identity map, or Gleam's rule with `_` doubled, is a total injective rule. Only readable rules collide. Evidence in raw shows S collides, and G collides on `Foo_bar`/`FooBar` (but not on `Foo_Bar`/`FooBar`, which G keeps distinct as `foo__bar`/`foo_bar`). The brief should say "no *readable* mapping".
5. E8 attributes the refuted Gleam claim to "Ticket 10 §7 ... and ticket 62 candidate 2". Ticket 10 line 334-335 says "Fieldless variants compile to atoms ... PascalCase to snake_case" about **constructors**, which is correct (E7 confirms). Only ticket 62 line 116-117 applies it to function aliasing. Ticket 10 is not refuted.
6. "Deterministic" sizes (p08 header): path-dependent (see section 1).
7. E17 "Dialyzer/ElixirLS see the alias typed" is inference from `-spec` presence; the brief states Dialyzer was not run. OK as disclosed.

## 6. Citation spot-check (all line numbers read in the repo)

Correct: ticket 32:204; bs_otp.erl:8; bs_lexer.xrl:150, 153, 16; ticket 35:130 (also 83, 238); LANGUAGE.md:3120 (§12 heading), 3128-3131 (actual 3129-3130 inside), 3264 (§13 callback table); ticket 40:308; bs_emit.erl:31; bsc.erl:843; bs_check.erl:41; ticket 10:335 (sentence spans 334-335); erl_scan.erl:626-627, 1601-1625; erl_lint.erl:642; bs_alias.erl is 95 lines; tickets 50, 87 contents match (`!`/`?` ruled out at 50:142-150, 337; `bs@type_atoms` at 87:69-76).
Mis-cited: none by line number. Mis-attributed: ticket 10 §7 (item 5 above). §12 contains no callback caveat (grep of lines 3103-3230 for callback/behaviour/snake finds nothing), so "§12 line 3120 is already false for callbacks and does not say so (§13 does)" is **true**.
Spot-checked Counter: callbacks export snake_case only (`handle_call/3, handle_cast/2, init/1` plus `bs@type_atoms/0`), so the brief's key claim (e) holds.

## 7. Key-claim results

- (a) `:Shop."New"(1)` runs in Elixir; my own module, capture, `Enum.map` capture, defdelegate all work; unquoted forms and unqualified import calls are SyntaxErrors. CONFIRMED.
- (b) Gleam rejects PascalCase functions and snake_cases constructors per capital (`h_t_t_p_get`, `b2_c`). CONFIRMED.
- (c) Alias collisions and `Module_Info` vs `module_info/1` CONFIRMED with my own sources on a self-built patched compiler.
- (d) Size percentages and 161/362/604 CONFIRMED (the 161/362/604 numbers are undercounts of a rewrite).
- (e) Callbacks export snake_case only; LANGUAGE.md §12 is silent on it. CONFIRMED.
