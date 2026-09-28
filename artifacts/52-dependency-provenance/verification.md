# Verification of brief.md (ticket 52) — independent

Method: copied probes/ to scratchpad, ran every script fresh (`fresh/*.out`), diffed against checked-in `.out`;
opened every cited source; read every script. No bsc run, no Gleam/OTP28/rebar3. No git. Nothing edited except this file.

## Overall verdict: CONFIRMED-WITH-CAVEATS. Fix the listed items before it goes to a human; none flips the recommendation.

## 1. Probe re-runs
| Probe | Runs | Fresh vs checked-in .out | Supports brief sentence |
|---|---|---|---|
| versions.sh | yes | identical | yes. "bsc needs OTP 28" is a hard-coded echo, not a measurement (see L1) |
| p1_missing_module | yes | identical | E1, E2 yes (caller frame absent from stack confirmed) |
| p1b_xref | yes | identical | E3 yes. I also re-ran p1's caller *without* +debug_info: UM/XC/XU all `[]`, so the debug_info explanation reproduces |
| p2_elixir_missing | yes | identical | E4, E5 yes |
| p3 (fixtures+escript) | yes | only timing lines differ | E6-E10 yes (deterministic lines identical). Timing: see 3/E13 |
| p4_appfiles | yes | identical | E14, E15, E16 yes; **E17 second half NOT in the .out** (see F1) |
| p4b_mix_beam | yes | identical | E18: function list yes; "0 .ex files" not in any .out (I ran `find /usr/lib/elixir -name '*.ex'` = 0, true) |
| p5_elm | yes | identical | E19 yes |
| p6 | yes | timing lines only | E6 (real Elixir dirs), sizes 21/32/14 yes |

## 2. Findings

**F1 (REFUTED as captured, true as behaviour). E17 "mix refuses the build when the dep is 0.9.0 ... got \"0.9.0\"".**
The final section of p4_appfiles.out is empty, in the checked-in file and in my fresh run (mix compile prints nothing, rc 0; `mix deps` still
says dep_run 1.2.3). The script's `sed -i` + immediate `mix compile` does not trigger mix's dep re-check. The exact message the brief quotes
reproduces only if the dep's mix.exs is touched / `_build` removed (I did both by hand: `the dependency does not match the requirement "~> 1.2",
got "0.9.0"`, "Can't continue due to errors on dependencies"). So the claim is true but the cited probe does not evidence it. Fix: change the script
(`touch` or `rm -rf _build` before the compile), regenerate p4_appfiles.out.

**F2 (E13 numbers do not match any captured output).** Brief vs checked-in / my fresh:
which(lists) 5.3 vs 6.43 / 4.28; which miss **708** vs 1069 / 932; app scan 8,500-9,000 vs 8,231 / 7,158-7,710; load cold 417 vs 354 / 623;
ensure_loaded 758 vs 697 / 660; lib_dir hit 2.5-3.0 vs 2.80-3.67 / 4.29-4.53; 9-app check ~61 vs 68.45 / 43.56; erlc 213-290 vs 230-267 / 215-228.
The brief's figures come from some other run not checked in. Orders of magnitude agree, and the brief itself says "order of magnitude, not the digits",
but the 708 µs is repeated in Option A as if measured, and it is outside both sets of captured values (~0.9-1.1 ms). Fix: quote ranges that
contain the checked-in values, or cite the .out numbers. Also the "44-entry path" applies to p3; p6's 9-app check ran with no ERL_LIBS (shorter path),
and lib_dir is a name-db lookup, so path length is irrelevant anyway.

**F3 (E3 partial evidence).** "without it every query returned []" — only one query (undefined_function_calls) is in an .out (p1). The "every query"
part rests on a first p1b attempt that was not preserved; the p1b header narrates it. I reproduced it (UM/XC/XU all empty), so CONFIRMED, but the checked-in evidence
alone is one query.

**F4 (E22 overstated "only").** bsc.erl:691-692, bs_run.erl:19-20, bs_batch.erl:170,202 exist and say what is claimed. But "the only `code:` uses" is not
true literally: bs_repl.erl:65-68 (purge/delete/ensure_loaded of own output) and bs_batch.erl:225-237 (root_dir, all_loaded, purge, delete) also call `code:`.
None is a presence check, so the substance (no foreign-module presence check) holds. Say "no `code:` use is a presence check".

**F5 (premise 1 "exactly").** bs_parser.yrl:165-166 is as cited, but the grammar has a second `using` production, `using_decl -> 'using' modpath : {import,...}`
(line 180, used at `decl -> using_decl`, line 100). "The shipped grammar has exactly `using atom_lit {...}`" should read "exactly one *foreign* `using` form". The "no `[`-prefixed
declaration production" claim is true (the `[` uses are only list patterns/expressions at 539-570, 769-770). Also the ticket said "something like", so "contradicts" is stronger than the ticket's text.

**F6 (supersession source).** LANGUAGE.md:2741-2770 does show `using :ets { }` (exists at those lines). LANGUAGE.md itself never says it supersedes 32 (grep for supersed: none);
the supersession statement is in ticket 106's "Why this is raised" (RECORDED, confirmed there). The brief labels it correctly as SOURCE+RECORDED; just don't attribute the word "superseded" to §11.

**F7 (E10 is by construction, and its use in (b) is a stretch).** The `foo-1.0/ebin/bar.app` fixture was built so dir name != .app name; `mod_to_app_parse` is the author's own function, and
`{not_in_an_ebin,...}` (E8) is a value the author's function invents. Both show that *a path-parse heuristic* can fail on a pathological layout; neither measures that mix/rebar3 ever
produce such a layout (they name dirs by app). Sub-decision (b) says "module→app is not derivable by name in general, E10": the name-based case that matters (`Elixir.Req.Request` → `req`)
is not probed at all. Not a fabricated result, but E10 is weaker support for Option C's "once per module" than the brief presents. E9 (duplicate `shared`) is likewise a constructed fixture; it demonstrates
order-dependence, not prevalence.

**F8 (p1b header is not a clean prediction).** p1b's PREDICTION was written after p1's result and after a failed first attempt (its own header says so), so it is hindsight, not a test. It was also
partly wrong (it hedged that undefined_function_calls "may stay []"; it did not). The brief does not lean on p1b's prediction, only on its output. p1's header (xref "WOULD report it") is retained and is
contradicted by p1's own output, and its "caller follows callee on the stack" is also contradicted (tail call) — consistent with an unedited header; without git I cannot prove it was never edited, but nothing in it was fitted to the result.
p3's P5 ("tens of microseconds") was also wrong (single digits) and not acknowledged; trivial.

**No simulated failures found.** The undef (p1), Elixir warnings/errors (p2), mix inference (p4), Elm network failure (p5) are all triggered for real by the real tools. p3's `add_pathz(loose)` is disclosed in the script comment.

## 3. Label discipline
- Every MEASURED item E1-E19 maps to a real output except the parts noted in F1, F2, F3 and E18's "0 files".
- SOURCE OTP lines verified against installed kernel-8.5.4.2: code.erl:810-816 (which: is_loaded first) yes; code_server.erl:609-618 (get_name) yes; :1015-1018 is the `do_dir({lib_dir,Name})` clause that calls `lookup_name` (lookup_name itself is defined elsewhere; cite is to the caller, fine); :103 is inside `get_user_lib_dirs` reading ERL_LIBS (whether that is "at boot" only was not checked, plausible).
  bs_check.erl:606 `{foreign,_,Mod,Sigs}` walk: yes.
- RECORDED verified: ticket 50 resolved 2026-08-26, lines 290-318 say shape 1 unbuilt, no new surface. Ticket 106 resolved 2026-09-25, alias `term GetOrCrash(binary url) = :'get!'`, "Unbuilt — ENG-250"; grammar line 165 confirms no alias yet. Ticket 51 lines 69-133 say ERL_LIBS alone, one dir per app, rebar_mix vendors elixir not eex, 16 apps. Ticket 52 file matches the brief's restatement of the question.
- Gleam: only "not probed" (E20, versions.out). Elm: only the failure. No overreach found.
- bsc: every delta is labelled as read from source. Unlabelled assertions: L1 below.
- L1 unlabelled: "bsc cannot be built here (needs OTP 28)" is stated without a label; versions.sh just echoes it. Plausible (bs_lexer.xrl uses `TokenLoc`), I did not verify. Label it RECORDED/unverified.
- L2: "check is ~3 µs ... tiny against 200+ ms compile" compares a warm in-VM call to `erlc`'s VM startup; the brief's own p6 header concedes bsc is already a running VM, so the ratio is fair only as an upper bound on cost. The claim "stronger than either neighbour's compiler" (c) is an inference, not a measurement (Elixir does warn on calls, error on struct/import; erlc silent) — fine, but it is a comparison of behaviours, not of strength on the same input.
- L3: "LSP/--check would error on a box without deps" is correctly marked UNVERIFIED.

## 4. Verdict table
| Item | Verdict |
|---|---|
| E1, E2 (erlc silent, undef, tail-call frame) | CONFIRMED |
| E3 (xref needs debug_info) | CONFIRMED (extra probe by me); brief's "every query" lacks checked-in evidence (F3) |
| E4, E5 (Elixir warn / hard errors) | CONFIRMED |
| E6-E9 (lib_dir, dir-name vs .app, which, duplicates) | CONFIRMED (fixtures constructed; F7) |
| E10 (parse wrong vs .app) | CONFIRMED-WITH-CAVEAT (by-construction fixture, author's own parser) |
| E11, E12 (OTP source) | CONFIRMED |
| E13 (cost numbers) | CONFIRMED-WITH-CAVEAT: order of magnitude yes; exact figures (708, 8,500-9,000, 417, 758, 61, 213-290) not in any output (F2) |
| E14, E15 | CONFIRMED |
| E16 (mix inference) | CONFIRMED |
| E17 | first half CONFIRMED; second half REFUTED-as-captured / true when re-triggered (F1) |
| E18 | CONFIRMED (0 .ex files not in an .out) |
| E19 | CONFIRMED |
| E20 Gleam not probed | CONFIRMED (no Gleam claims anywhere) |
| E21 (ticket 51) | CONFIRMED |
| E22 (no presence check in bsc) | CONFIRMED-WITH-CAVEAT ("only" overstated, F4) |
| Premise 1 (grammar, no attribute, §11 supersedes 32) | CONFIRMED-WITH-CAVEAT (F5, F6) |
| Premise 2 (50 resolved, no FFI change; 106 alias) | CONFIRMED |
| Circularity | No simulated failures or self-inspecting checks; two constructed fixtures (F7) and one post-hoc prediction header (F8) |
| Recommendation (C, name only, lib_dir check) | Follows from the evidence as far as evidence goes; the "once per module" reason leans on F7 |

## 5. Required corrections before it goes to a human
1. Fix p4_appfiles.sh so the 0.9.0 violation actually triggers, regenerate the .out (F1), or relabel E17b as manual/UNCAPTURED.
2. Replace E13 figures (and Option A's "~708 µs") with values from a captured output, as ranges (F2).
3. Soften E22 "only" and premise-1 "exactly" (F4, F5); add label to the OTP 28 claim (L1).
4. In (b) say E10 shows a path-parse failing on a hand-built layout, not that real toolchains produce one; name-based derivation is unprobed (F7).
