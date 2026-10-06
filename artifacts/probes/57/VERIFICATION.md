# Independent verification of the ticket-57 brief and probes

Verifier work dir: `/tmp/claude-0/-home-user-beam-sharp/c0642514-f9d1-5f22-91e2-015f96c1f119/scratchpad/verify57/`
(copy of `probes/`, my own `lib.sh` edit pointing REPO at `/home/user/beam-sharp` and WORK at `verify57/work`; author's `out/` untouched and
kept in my copy as `author_out_copy/`). Nothing in the repo, `compiler/` or `wayfinder/` was edited; no git.

## What I ran
- `00_build.sh`: five fresh variants (base, g1, g1b, c1, c2) built from a fresh tar copy of `compiler/` + `aoc/`, patches applied from `patches/*.patch`.
- Probes 01-09, 11, 12 from the fresh copy, sequentially (not 10). Raw outputs diffed against the author's `out/` after normalising paths.
- Eunit, SEQUENTIALLY and one at a time on a host with no other `rebar3`/eunit running at the time: `base` then `g1`, each in its own copy.
  base: `All 1312 tests passed.` (339 s). g1: `All 1312 tests passed.` (347 s). I did NOT re-run g1b, c1, c2 eunit (relied on the author's `evidence/eunit/*.txt`, which I read: each says 1312 passed).
- My own scripts in `verify57/mine/` (own AST dump through each variant's `bs_parser`, own signed-domain examples, own beam_lib chunk comparison, mutants).
- Note: another verifier (`verify59`) had an eunit run in flight earlier on the host; I started mine only after `ps` showed no rebar3.

## Raw-output diffs, author `out/` vs mine
Identical (after path normalisation): 00 (conflict counts and patch sizes; binary sizes differ, path-embedded), 01, 02, 04, 05, 07, 08, 11, 12.
Differences:
- 03: one line, the absolute path in the G1 diagnostic. Nothing else.
- 06: two `diff` hunk headers shifted by one line (`23,26c23` vs `22,25c22`): `~p` wrapping of the abstr differs with path length. The compared fragments are identical.
- 09: **timings differ and, more importantly, the brief's timing table is in no raw file** (see Measurements below).
- 10: not re-run by `run.sh` (author's too: `out/10_eunit.txt` is a hand-assembled copy of `evidence/eunit/`, stated in the file's own header and in the brief).

## Per-probe verdict
| Probe | Verdict | Reason |
|---|---|---|
| 00 build | REPRODUCED | 6 s/r, 0 r/r in all five builds (my logs). Patches apply cleanly. Generated parser/lexer excluded from the copy, so parser patches are really rebuilt (I hit the stale-`bs_parser.erl` trap on my own mutant; the author's `build_variant` avoids it). |
| 01 ticket table | REPRODUCED | 5-row table + G(0)/G(1) + all 8 workaround spellings identical. I additionally checked the *reason* for 7 refusals (`not a predicate the checker can read`), so refusals are not for an unrelated cause. Shipped 38b probe: "all 7 probes matched expectation". Not circular: expectations are the ticket's claims, verdict is bsc exit status. Uses the prebuilt repo `bsc` (Oct 5), but probe 04 base (fresh build) agrees row for row. |
| 02 AST | REPRODUCED | `-5` is `{e_neg,{2,29},{e_int,{2,30},5}}` (also from my own escript against base ebin). The ticket's `{e_op,'-',{e_int,0},E}` is refuted; `0 - 5` does produce that e_op form. g1 gives `{e_int,{2,30},-5}`. |
| 03 guard today | REPRODUCED | Guard compiles/runs (`:a/:b/:a`); abstr is `{op,..,'-',{integer,..,5}}`; G1 refused with `Band(<= 5)`. Control G2 (0 instead of -5) accepted; relational-pattern version accepted. Mutant (my own: `5..9 / <5 / >9`, and `0..9`) accepted on base, so the sign of the literal is what flips it. One baseline caveat: G1 vs G2 also change the other bounds (`<-5` vs `<0`), but my positive-bound mutants vary nothing else. |
| 04 matrix | REPRODUCED | Identical. Row verdicts are exit status only, but I confirmed reasons on the refused rows (all "not a predicate"). Sign semantics are real, not just accepted: my subtype test (`>= -3` into `>= -5` accepted, reverse refused with residual `-5..-4`) holds under g1, g1b, c1, c2. Caveat: two expectations were edited after seeing output (CHANGELOG 1, 2); both disclosed; see Circularity. |
| 05 expr typing / DIFF | REPRODUCED | Identical table. N2 `G(-5)`: base refused, g1/c2 accepted. N5/N8: base accepted, g1 and c2 refused (the author's `refused!=accepted` for c2 is an honest unmet prediction). DIFF values identical across variants. My mutant g1mut (fold keeps the sign: `{e_int,IL,N}`) turns this RED: `1 - -5` prints -4 not 6, `N9` (`return -1` into `>= 1`) accepted. So the DIFF and N9 rows are sensitive. |
| 06 emission | REPRODUCED | `Code`, `ImpT`, `ExpT`, `LocT`, `Line`, `AtU8`, `StrT` chunks byte-identical base vs each variant (my `beam_lib:all_chunks` compare, not the author's disassembly). `Dbgi` differs only for g1 (abstract code, expected) and `CInf` differs everywhere (compile path/options). Mutant g1mut gives `Code` DIFFERENT, so the comparison is non-vacuous. |
| 07 residual | REPRODUCED | 6 of 6 pasted residuals compile. My own examples (`-20..40` domain, base int `-3`): `Kind(>= -20 and <= -1)` pasted compiles under g1; base prints `Kind(<= -4)` and it compiles. The ticket's "printed residual the surface cannot accept" is not reproduced for clauses. Caveat on scope: this tests printed *clauses*; the *type* line (`-100..0`) is interval notation that is not surface syntax, which the brief states. R5 (pasting `Band(<= 5)`) is not a meaningful paste test since that residual is the false one. |
| 08 neighbours | REPRODUCED (tool output) | Identical to author's output. Elm correctly claimed nothing. Gleam/Elixir rows are raw tool output with no source cited, as the brief says. |
| 09 measure | DIFFERS (numbers) | AST block identical. Timing table in the brief matches no raw file (details below). Qualitative conclusion (no variant distinguishable) holds in all three data sets I have. |
| 10 eunit | REPRODUCED for base and g1 only; g1b/c1/c2 UNCHECKED by me | See above. |
| 11 incidental | REPRODUCED | `value == 3` and `>= 3 and <= 3` fail `bad range type`; `>= 3 and <= 4` and `!= 3` accepted; g1 `-3` singleton fails the same; my `-4..-3` under g1 accepted. |
| 12 options | REPRODUCED | Table identical; every sentence in the brief's Options about which variant accepts which program matches. |

## Key claims
(a) 5-row refusal table: REPRODUCED on the repo bsc (probe 01) and base fresh build (04 first rows).
(b) AST: REPRODUCED by my own dump: `-5` -> `{e_neg,_,{e_int,_,5}}`; ticket's `{e_op,'-',{e_int,0},E}` form is what `0 - 5` produces. `bs_parser.yrl:944-945` (`negate/2`) and `:589` correct; `:219-221` is the comment (218-220) plus rule (221); `int_lit -> '-' integer` is at `:470` (the brief does not cite it; the ticket's "`bs_parser.yrl` `int_lit`" holds).
(c) E4: REPRODUCED. base refuses `Band(<= 5)`; g1, c1, c2 accept; g1b refuses. Mutants accepted (above).
(d) Residual: REPRODUCED with my own examples (above).
(e) E6/E7: `G(-5)` into `!= 0` refused base/g1b/c1, accepted g1/c2. My extra checks: under g1 `G(-7)` into `!= 7` accepted, `G(7)` refused, `G(-7)` into `!= -7` refused (so the folded literal is the right value). `x / -0` accepted on base, refused on g1 and c2 with the existing "always zero" message; `x / -5` accepted on g1; `x / 0` and `x / -0.0` already refused on base. Judgement: the g1 refusal is CORRECT, not an artefact: `-0` really is the literal 0, and base already refuses the float `-0.0`; the base acceptance is the inconsistency. It is still a behaviour change the ticket did not ask for, as the brief says.
(f) E10: REPRODUCED. `erl_lint.erl:3443` is the `X < Y` line (`check_type_2 range`, 3440-3444 is the clause); message `compile: a.bs:0: bad range type`.
(g) Identical BEAM: REPRODUCED (Code chunk). 1312/1312: REPRODUCED for base and g1 by me; others from author's evidence only.

## Circularity assessment
- Expectations in 01, 02, 05(N1-N9 predicted), 07, 11, 12 are the ticket's or the design's stated claims; "REFUTED" lines are printed and not swallowed. No `|| true` hiding a failure was found in the probes (the only `|| {…; return 1}` is in `build_variant`). Grep checks (01 message, 02 `e_neg`, 03 abstr, 06 `is_ge`) match compiler output, not the author's own echo.
- Verdicts are exit status, with no reason check. I checked the refused rows' reasons and they are the claimed one; the probes themselves do not. The first iteration of 04 (CHANGELOG 4) shows a module/dir mismatch error could silently count as "refused"; the final probes use matching names, and an `INVALID` guard exists only in 05's DIFF block.
- CHANGELOG edits: 1 (`value == -3` swapped) legitimate and the first-run raw is kept; 2 (g1b `--5` expectation flipped accepted->refused) tuned to observed behaviour of a 6-line patch the author wrote; disclosed in the brief, but g1b's weakness is a property of that implementation (a recursive `fold_neg` would accept it), so "g1b refuses `--5`" says nothing about option C itself; 3 legitimate (the first expectation was wrong; the first-run showed an exact cover followed by `_` accepted, the later checks match the cited ticket-12 rule); 4, 6, 7, 8 are authoring/harness fixes; 5 honest (unmet prediction left in); 9, 10 invalid parallel/overlapped eunit runs kept as evidence and labelled; the "Failed: 0. Passed: 228" line in `summary_first_sequential_pass_g1_line_invalid.txt` reads like a pass but the file name and brief label it invalid, and the underlying text says tests were cancelled; 11 legitimate (block drift) but see timing mismatch; 12 additive.
- **By construction, not measured:** Option C's headline "measured disagreement between a refinement and a guard" (g1b refuses the AGREEMENT program). g1b was written to fold only under `refinement`, so the guard cannot read `-5` by design. It does demonstrate the ticket-63 hazard concretely, but it is not an independent finding about an option the ticket's author would implement; a literal-only sub-grammar was never built (the brief says so under "could not verify").
- Baselines: the base variant is a fresh copy, not the repo build; "repo" and base agree on every shared row.

## Measurements: numeric claims
- Patch sizes `+1/-0`, `+6/-1`, `+29/-5`, `+31/-5` come from `grep -c '^+[^+]'`, which **drops blank added lines**. Counting all added lines: g1 +1/-0, g1b +7/-1, c1 +33/-5, c2 +35/-5 (hunk headers: c1 `-4946,15 +4946,43`, i.e. net +28). The brief says "non-header lines" without saying blanks were omitted. Minor, understates c1/c2 by 4, g1b by 1.
- Conflicts 6 s/r in all variants: REPRODUCED. `bs_parser.yrl:726` "a grammar that holds 0" is stale: correct.
- `const_int/1` "9 lines": correct (count of the clause lines in the patch).
- **Compile-time table is unsupported by any raw output.** Brief: base 653/548, 1069/962; g1 656/575, 1077/903; g1b 1038/942; c1 1052/955; c2 1078/974 (P1). The author's current `out/09_measure.txt` (and `out/heavy/times/*`, 15 rounds) says base 594/532, 981/923; g1 609/514, 1027/926; g1b 585/536, 1000/922; c1 606/528, 1005/899; c2 588/499, 974/914. The first-run block file has other numbers again. The table in the brief appears to come from an intermediate run whose output was overwritten when `run.sh` was re-executed. My run: base 576/525, 977/865; g1 566/500, 946/878; g1b 568/512, 933/847; c1 562/521, 937/893; c2 568/552, 968/860 (medians recomputed from raw per-run files, n=15 each). The brief's "within about 3% of base on P1" fails on the author's current raw (g1 +4.7%, c1 +2.4%, g1b +1.9%, c2 -0.7%) and my run has every variant faster than base (-0.9% to -4.5%). The conclusion "not distinguishable, spread within a variant (~100 ms) exceeds spread between variants" holds in all three data sets. Fix: replace the table with one that has a raw file behind it.
- Eunit "1312/1312 for all five": base and g1 reproduced by me; g1b/c1/c2 are the author's logs (UNCHECKED by me). Brief's description of the two invalid runs matches `evidence/`.

## Citation spot-check (all opened)
Correct: `bs_parser.yrl` 221, 585-589, 726, 944-945; `bs_check.erl` 1895-1896, 2586, 2874-2884, 4146-4153, 4916-4925 (function is 4914-4927), 4931-4955; `bs_emit.erl` 669, 743 (`used_vars({e_neg..})`), 1058; `erl_lint.erl:3443` (range clause 3440-3445); `v3_core.erl:2638-2641`; `sys_core_fold.erl:889-906` (fold_call_1 to fold_lit_args); `intervals_tests.erl:46-60`; F51 done 2026-09-16 (F51-float.md Status line); tickets 20 §5, 12 §2, 38 exist; ticket 63's quote is verbatim at lines 336-338 of `63-negation-has-no-spelling.md`.
Slightly off (cosmetic): `intervals_tests.erl:290-297` — the test spans 290-299; ticket-63 "the paragraph after line 335" — the quote is at 336-338 and its paragraph starts at 333; `bs_parser.yrl:219-221` is really 218-221.
Not checkable by me (no git): `2127bb8`, `712b9e9`, "earliest commit that mentions e_neg".

## Unsupported or overstated brief claims
1. Compile-time table (above): no raw source; "within about 3%" does not hold against the current raw file.
2. Patch sizes omit blank lines (+33 not +29 for c1, etc.).
3. "the only option with a measured disagreement between a refinement and a guard" — true but by construction of g1b.
4. "E4 ... the residual it prints (`<= 5`) is wrong": defensible (the program is exhaustive) but it is exactly what the compiler's stated rule ("An unread guard may always fail") should print; the defect is the unread guard, not a bad residual algorithm. Wording only.
5. "the repo's gates" not run: stated by the brief itself, so not overstated.
6. Elixir "Elixir 1.19.5 ... Where folding happens: After expansion" is inferred from erlang_v1 forms; the brief admits no source is read.
Everything else I tested held.

## Overall verdict
**The evidence reproduces.** Every probe re-ran to the same raw output apart from paths and timings. The five key claims (a)-(g) hold on fresh builds, my independent AST dump agrees, my own signed-domain examples agree, and six mutants of the premises turned the corresponding probes RED or flipped the verdict: wrong-sign fold (g1mut) breaks N9, DIFF, Sem and beam identity; positive-bound guards are accepted on base; non-singleton refinements avoid E10; `G(7)`/`G(-7)` stay refused where they should; `x / -5` accepted under g1. Defects are confined to the brief's Measurements: the compile-time table has no raw backing and its 3% statement fails on the current raw file, and patch line counts omit blank lines. Option C's disagreement result is by construction. g1b/c1/c2 eunit results were not re-run by me.
