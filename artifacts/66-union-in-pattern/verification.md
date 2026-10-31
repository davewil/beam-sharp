# Verification of the ticket 66 decision brief

Verifier run, 2026-10-30. Probes were copied to a fresh `/tmp/ver66/probes`; the PLT was built at `/tmp/p66.plt`
(`dialyzer --build_plt --output_plt /tmp/p66.plt --apps erts kernel stdlib`, 23 s). The brief and probes were not edited.
Environment: OTP 25 (compiler-8.2.6.3), Elixir 1.14.0. Nothing about bsc/B# source was executed by me either (bsc cannot be built).

## Verdict

**The probes are sound and the headline measurements reproduce exactly. The brief is mostly accurate, with five misstatements, none of which flips a conclusion.**
No probe is circular. One probe (03) asserts nothing though the brief says every probe exits non-zero on a failed assertion. One control (`no_share_opt`) is weaker evidence than the brief presents.
The brief's "run-time is indistinguishable" is slightly too conservative: in five reruns the duplicated lowering was consistently 3-5% slower on medians.

## Task 1. Fresh reruns versus saved outputs

| probe | command | fresh vs saved `.out` | rc |
|---|---|---|---|
| 01 | `escript 01_lowering_size.escript` | byte-identical (`diff` empty) | 0 |
| 02 | `bash 02_unreachable_precedent.sh` | differs only in dialyzer wall time (0.11s vs 0.13s) and the absolute path in the Elixir warning; every PASS line and exit code identical | 0 |
| 03 | `escript 03_shared_body_and_runtime.escript` | Part A byte-identical; Part B timings differ (expected), see Task 2b | 0 (x5) |
| 04 | `escript 04_mixed_union_lowering.escript` | byte-identical | 0 |

## Task 2. Circularity review and mutation

**Probe 01 + `lib_gen.erl` (PASS, not circular).** Sizes are read from compiled artefacts (`byte_size` of the stripped beam via `beam_lib:strip`, instruction count from `to_asm`), and slopes are least-squares over N=2,5,10,20. Nothing is hard-coded. The verdict lines are computed from the numbers. `check_behaviour/4` is a real differential against the `dup` lowering on all members, `none`, and a foreign-Kind map.
- Mutation: `guard_semi` made to drop its last tag. Probe 01 printed `BEHAVIOUR MISMATCH guard_semi N=2 B=1` and exited 1. The differential can fail.
- Reproduced per-member costs: dup 17.6 / 50.3 / 194.5 bytes and 8 / 38 / 134 ins at B=1/8/32; guard disjunction 5.2 / 5.2 / 4.9 bytes and 0 ins. The 20-member, B=32 totals (4385 vs 812 stripped) also match the `.out` rows.
- "0 instructions per member" is real but needs reading: erlc compiles the guard disjunction to one `select_val` whose jump table grows. The cost is table data (about 5 bytes per tag), not instructions. The brief's wording is accurate.
- `guard_semi` and `guard_orelse` are identical in size; `outline` is also about 5 bytes per member. The `outline` result means the "duplication cost" is paid only if the RHS is copied, as the brief says.

**Does erlc keep one body? (PASS, confirmed by my own `erlc -S` reading).** I generated `lib_gen:source(dup,20,8)` and `source(guard_semi,20,8)` and ran `erlc -S`. `grep -c phash2` gives 160 for dup and 8 for the guard disjunction. The disjunction output has one `select_val` and a single body. Confirmed.

**`no_share_opt` control (WEAK, not circular).** The brief says compiling dup with `no_share_opt` changes nothing, so erlc's own sharing does not rescue the duplication. The numbers are identical, but the control is inert in general. In OTP 25, `no_share_opt` disables only the `beam_ssa_share` pass (`compile.erl:864`), and `beam_ssa_share.erl`'s own header says "a similar optimization is done in beam_jump", which stays on. I built three small shareable programs (`/tmp/ver66/s/{s,t,u,v}.erl`) and none produced a different `-S` output with and without `+no_share_opt`. So I could not show the flag has an observable effect on any shape, and "identical with the flag" does not by itself show "erlc does not share". The weaker supporting fact does hold: the default build leaves 160 copies, so erlc did not merge these bodies. The brief does state the shape limitation; it does not state that the control is inert.

**Probe 04 (PASS, not circular, but narrow).** The four lowerings are hand-written Erlang, not generated from lib_gen. That is acceptable for a "does the shape behave on hostile inputs" test, though it is weaker than the brief's "lowering is semantically safe" suggests.
- Mutation 1: ga's guard reduced to `K =:= 'T.A'`. Result: `lowering ga: DISAGREES`, rc=1.
- Mutation 2: ga's guard changed to `'T.A'; 'T.E'`. Result: DISAGREES, rc=1.
- It can fail. The result on 12 hostile inputs (non-maps, Kind-less map, foreign Kind, `none`) is reproduced. Note gc (no `is_map`) agreeing means a `map_get` failure in a guard is silent, as the brief says. It covers N=2 only.

**Probe 03 (not circular, but asserts nothing).**
- Part A counts `{extfunc,erlang,phash2,1}` in the real asm. Not hard-coded. Mutation: `guard_semi` made to emit one clause per tag. The probe printed `{guard_semi,20}` (truthful) and exited 0.
- The header comment says "Asserts: behaviour identical to dup". That is false: 03 has no assertion and no behaviour check (`check_behaviour` lives only in 01). The brief's Reproducing section ("Each exits non-zero on a failed assertion") overstates for 03. The figures are honest; the probe cannot go red.

**Probe 02 (PASS, not circular).** `chk` compares observed exit codes and grep counts. Mutation: shadow.erl's second clause changed to a different Kind. Result: FAIL on "warning emitted" and FAIL on "opt-in strict", script rc=1.
- Observed: erlc 25 shadowed clause is `Warning: this clause cannot match because a previous clause at line 4 always matches`, rc=0; with `+warnings_as_errors` rc=1. Elixir 1.14: same message, rc=0; `--warnings-as-errors` rc=1 ("Compilation failed due to warnings"). The exemplar-5-shaped file (a clause outside the `-spec`/`@spec`): erlc silent rc=0, Elixir silent rc=0, dialyzer default flags and `-Wunderspecs` silent rc=0.
- Fallback: if `/tmp/p66.plt` is missing, the dialyzer section prints SKIP and the script still exits 0. That is a documented skip, not a hidden pass, but a reader of the exit code alone would not see it.
- Overreach check: the brief says dialyzer is silent "with default flags and with `-Wunderspecs`". True, and stated that narrowly. My additional run: `-Woverspecs` silent; **`-Wspecdiffs` does warn** (`(c()) -> atom() is not equal to the success typing: ... 'Kind' := 'T.A' | 'T.B' | 'T.E'`). That is a spec-versus-code difference, not a per-clause "vacuous" report, so "no precedent for a clause outside the declared spec" is still a fair summary, but dialyzer does have an opt-in flag that surfaces the mismatch (at function, not clause, level). The brief never ran it.

## Task 2b. Probe 03 timing, five reruns

Medians (microseconds), 20 members, 25 reps per run; within-run spread% in parentheses.

| B | variant | run1 | run2 | run3 | run4 | run5 |
|---|---|---|---|---|---|---|
| 1 | dup | 78754 (11) | 78214 (58) | 78343 (27) | 77512 (68) | 79351 (33) |
| 1 | guard_semi | 75005 (18) | 75435 (70) | 75425 (42) | 73930 (58) | 76499 (56) |
| 1 | guard_orelse | 74680 | 74318 | 74626 | 74081 | 77313 |
| 1 | outline | 76352 | 75952 | 76529 | 76979 | 76704 |
| 8 | dup | 573769 (14) | 584059 (28) | 580272 (40) | 576290 (34) | 575658 (25) |
| 8 | guard_semi | 553850 (31) | 558356 (32) | 553402 (37) | 565353 (35) | 558519 (25) |
| 8 | guard_orelse | 556438 | 571891 | 553525 | 576257 | 566286 |
| 8 | outline | 559755 | 557834 | 549599 | 559368 | 562789 |

Within-run spread (max-min over median) ranged 11-84%, consistent with the brief's 34-84% (my range is wider on the low side). Between-run median drift is only about 1-3%. In 5/5 runs at B=1 and at B=8, dup has a higher median than guard_semi, by about 3-5%.
- The brief's claim is "medians within ~5% ... I do not claim any run-time difference either way". That is literally true and does not claim more than observed. But "not distinguishable" understates what the reruns show: a small but repeatable ordering (dup slowest). I did not establish whether it is real or an ordering/code-layout artefact, and 5 runs of one box is not a test. The brief should say "within about 5%, with dup nominally slowest in every rerun". No conclusion depends on it.

## Task 3. Claims table and file:line spot-checks

Verified by reading the repo at HEAD `c07bb7f` (the brief inherits verdicts at `6728799`, which is not an object in this working tree, so I cannot check that SHA).

| cited | result |
|---|---|
| `bs_check.erl:1874,1876` `not_a_record` | CORRECT (both raise sites; `record_of/3` begins at 1860) |
| `bs_check.erl:1886-1915` `resolve/3` returns structural types | CORRECT: `resolve({t_ref,N},...)` returns the declared map or `bs_types:mu(...)`; no alias provenance is kept |
| `bs_check.erl:4785` `vacuous_clause` as warning | CORRECT |
| `bs_check.erl:4812` `redundancy/4` tests against `Declared` | CORRECT |
| `bs_check.erl:4905`, `bs_emit.erl:664-671` `p_or` interval-only | CORRECT as read (`rel_combine` with `bs_types:union`; `rel_expr` over `p_rel`) |
| `bs_check.erl:2095,3914,3953` `record_names(Env)` | CORRECT (also 4533, 4790) |
| `bs_emit.erl:543` | CORRECT; the `none` case raises `not_a_record` |
| `bs_diag.erl:1896` rendering | CORRECT |
| `bs_diag.erl:1165` vacuous_clause text says "warning:" | CORRECT |
| **`bs_diag.erl:1053` as "the parallel arm site"** | **MISSTATED.** Line 1053 is the text of the `vacuous_arm` message (rendering). The severity is set at `bs_check.erl:3942` (`{warning, AL, ..., {vacuous_arm, N, Declared}}`). A reader following the brief's delta ("change 4785 and bs_diag:1053") would miss the actual arm site. |
| ticket 04 Answer finding 3 "Redundancy must warn, never error" | CORRECT (line 48; the rationale is non-compositionality under overloaded arrows) |
| ticket 12 "a warning is something an agent in a loop steps over" | CORRECT (line 119) |
| F53 ~l.119, arm vacuous only a warning | CORRECT (lines 117-121) |
| `CONTEXT.md` Alias | CORRECT: "the name never enters the type algebra, so two names over the same set are the same type" |
| `CONTEXT.md` Type prefix, "argument position only, never nested" | CORRECT text; but see nesting note below |
| `check-residual-pasteable.sh:804` `RecordUnion -> Which(Invoice i) -> ...` | CORRECT (gate text; not run by me) |
| ticket 85 Q1 defers (c) to 66, "66 is inside that rule" | CORRECT (quote verified) |
| Option B/C compiler-delta items | design reasoning, not executed (the brief says so) |

**(i) Ticket 66's `bs_diag.erl:952` is stale: CONFIRMED.** Ticket 66 line 92 says `not_a_record` is "rendered at `bs_diag.erl:952`". Line 952 now is the `relational_in_bind` message. `not_a_record` renders at `bs_diag.erl:1896` (built at 562-563).

**(ii) Is severity (exemplar 5) already ruled by ticket 89 A2? Partly, not fully.** What A2 says: "Warning". A four-element `DOWN` clause over a `Down` parameter "is the `vacuous_clause` warning every vacuous clause gets, as F60 ships ... naming the type is what makes the mis-shape speak, and the warning is that speech. No compiler delta." The error alternative that was declined was explicitly scoped: a `vacuous_clause` whose pattern is a tuple with a view's tag over a parameter holding that view, "every other vacuous clause stays a warning".
- For exemplar 5 (`Bad(E e)`, a type-prefixed record pattern disjoint from the declared `C`), the same tag (`vacuous_clause`) and mechanism apply, and "the warning every vacuous clause gets" reads as a general statement. A2 together with ticket 04 finding 3 are strong precedent. But A2 decided the DOWN-tuple case, and exemplar 5 is a different pattern kind (a named-type prefix, where the mistake is arguably more deliberate). So "probably already decided" is fair and the brief hedges appropriately; "already ruled" would be too strong. The brief's own hedge ("David may want exemplar 5 distinguished") is right.
- **Misattribution**: section 4 attributes "it is always a mistake" to "ticket 89 A2's own wording". A grep of ticket 89 for "mistake" finds nothing; A2's wording is "naming the type is what makes the mis-shape speak". The brief paraphrased and presented the paraphrase as A2's wording.

**(iii) Are 66 and 85 the same question? Largely yes, with a labelling slip.** Ticket 85 Q1 lists three name kinds: (a) alias to a part union, (b) refinement, (c) union of records "ticket 66's question, ASKED THERE AND NOT RE-ASKED HERE", and says 66 is "inside that rule" if the answer is a rule about names. So 66 == 85(c) by the tickets' own words, and resolving together is supported. The brief writes "66(c) and 85(a) are one question": ticket 66 has no sub-item (c) (it has S1-S4 as numbered items 1-4); the equation of 66 with 85(a) is the brief's own inference ("a union whose members are each decided by a test") rather than anything 85 states. The inference is reasonable, but is not what the tickets say. Treat as: 66 = 85(c); 85(a) and 85(c) are plausibly one rule, unproven.

**Nesting asymmetry (flag).** The brief says a record prefix nests today (F22.9) while a part prefix does not, citing CONTEXT's last sentence for the part rule. F22.9 (`F22-...md:57`, "binder nested in a tuple") supports the record side. But CONTEXT.md's Type prefix entry states the argument-position-only rule for the type prefix as a whole, without a record exception, so the two documents disagree on the record case. The brief presents an asymmetry as established; it is at best an unresolved doc/feature conflict, unexecuted.

## Statements of measurement vs execution

- Executed and reproduced: everything in probes 01-04 as described above.
- Stated as measured but weaker than stated: "erlc does not rescue the duplicate shape (`no_share_opt` identical)" is supported by the 160-copy default output, not by the inert control. "Run-time cost is not distinguishable" understates a repeatable 3-5% ordering.
- "Each exits non-zero on a failed assertion" is false for probe 03 (no assertions).
- Not executed, correctly labelled by the brief: B# exemplar verdicts, Options A/B/C snippets, part-union lowering (`is_integer orelse is_float`), S4 "no interaction", other-language claims, Elixir 1.20.
- Not labelled: "`02` demonstrably failed twice during development" is a claim about history I cannot check. I did show by mutation that it fails when its expectations are broken.

## Misstated claims, collected

1. `bs_diag.erl:1053` named as the `vacuous_arm` site; the severity site is `bs_check.erl:3942`.
2. "ticket 89 A2's own wording" for "always a mistake"; no such wording in A2.
3. "Each [probe] exits non-zero on a failed assertion"; probe 03 has none.
4. `no_share_opt` offered as evidence that sharing does not rescue dup; the flag disables only one of two sharing passes and I could not show it changes any output.
5. "66(c) and 85(a) are one question": labels are off; 66 is 85(c). The merge of (a) and (c) is the brief's inference.
6. Run-time "indistinguishable": reruns show dup nominally 3-5% slower every time.
7. Dialyzer "silent": true for the flags tried; `-Wspecdiffs` (untried) does report the spec/code mismatch at function level.
