# Verifier report, brief 59 (independent rebuild)

Built from `git archive HEAD compiler` (HEAD a0199d6; compiler tree identical to 0dddf8b) in /tmp/v59.*, OTP 27, patches applied with `patch -p1`.
Raw outputs: p14.out, p235.out, v1.out, new probes v1_new_probes.sh + prog/V1. Timings are noisy (concurrent eunit), direction only.

## Claim verdicts
- guard_one/7 receives Public; tag branch ignores it; kind/range/float gated `none when Public`: REPRODUCED (bs_emit.erl:267-281; Public = is_public(F) at :155).
- "one-line change": DIFFERS slightly. kind patch is +3 -5 lines (not +2 -4), and `Public` is renamed `_Public`, not removed; boundary_guards/clause still thread it. Tag-narrow patch is +2 only. Both minimal.
- p1 table (HEAD: Good 7, Forged function_clause, Direct function_clause; tag-exported-only: 7 / 100 / function_clause): REPRODUCED, also with the prebuilt bsc.
- p4 (HEAD Total([100.5]) = 2; widened = function_clause; BandOut guarded): REPRODUCED. Tag-narrow variant leaves it at 2.
- Bytes: Shop59 1516 vs 1480 (+36) and One/1 8 vs 6 instrs: REPRODUCED. Kind59 1340 -> 1376 (+36): REPRODUCED. The "+40 B relative path (1260->1300)" figure was not re-run (path-dependent size; delta of +36 absolute-path matches): NOT CHECKABLE as stated.
- Call time ns (+2.3 / +1.0 ns, medians 18.6 vs 16.4, 13.4 vs 14.4): NOT CHECKABLE on this box (medians 25-67 ns under load). Mins: tag 18.7/19.5 vs 16.9/16.0 (direction agrees); kind mins 26.6/14.4/18.9 vs 17.8/16.2/14.3 (no consistent direction). Kind-test cost direction is NOT supported here.
- p3 neighbours (Elixir FunctionClauseError vs 100; Gleam case_clause for both forged shapes): REPRODUCED. Elm: unmeasured, as the brief says.
- Option C "removes the only check on the nested path": REPRODUCED, and wider than stated (see new probes).
- eunit: author saw 4 baseline failures; I saw 5 (extra: diagnostic_term_tests:the_diagnostics_gate_passes_test, rc 1, passed in the widened run, so likely load/flaky). Baseline: body_check every_aoc..., cli_tests batch_runs..., diagnostic_json a_path_is_utf8..., diagnostic_term the_diagnostics_gate..., non_numeric_operand a_non_ascii_literal.... 1298 pass.
  Kind-widened: 6 failures = baseline minus the flaky one, plus 2 flips: `boundary_kind_tests:a_private_function_is_not_guarded_test` (F24.6, line 95) and `boundary_range_tests:a_private_function_carries_no_range_guard_test` (F37.5, line 129). Both assert the current scope; the brief must name them as tests that encode the status quo and need rewriting.

## Circularity
- Forged-element probe: not circular. Patch C removes only the tag test; the question is whether anything else catches the forged element. Nothing does (100). Discriminating control: Direct(Forged) stays function_clause under C (entry guard remains), so the difference is attributable to private One/1 alone. Mild caveat: SumAll([Forged]) failing at HEAD is inferred to come from One/1 (confirmed only by the variant result).
- Widened refusal of Total([100.5]): follows from the setup by design (Band's `>= 9` is not a type test), but it is the real shape of ticket 58's bug, and BandOut is the discriminating control. Fine.
- Legitimacy of channel: ticket 18 says elision for non-exported functions "is not an alternative - a foreign value entering through an exported function reaches private ones unchallenged", and 18 s4's function-local analysis treats a value handed to another function as unchecked. Foreign callers (mailbox, ETS, code_change, Erlang callers) are the stated threat. So the channel is legitimate. Caveat: no pure-B# program can forge an Invoice-tagged map; it needs a foreign caller or an unchecked foreign return. The brief should say so. Also 18 s4's own text says the exported function's analysis goes "no further"; ticket 59's "not a defect" reading relies on that.

## New probes (v1_new_probes.sh, prog/V1), HEAD / tag-exported-only / kind-widened
- SumOct(list<Octet>) -> private Dbl(Octet): HEAD [300] -> 600, [2.5] -> 5.0 (silent); tag variant same; widened -> function_clause for both. Exported control DblOut guarded in all. So the widened scope also closes the range hole (ticket 37), not only the float one; the brief mentions only the kind test and float.
- ViaTuple((int, Order)) -> private One: forged element in tuple field: HEAD function_clause; tag-narrow 101 (silent); widened function_clause.
- ViaField(Box b) -> One(b.O) (nested record field): HEAD function_clause; tag-narrow 100 (silent). Confirms and strengthens the caveat: the nested-field path is unguarded at the entry, and only the private tag test catches it at HEAD.
- A map<int,Order> probe was dropped (no suitable stdlib call found); not run.

## Corrections needed
1. "+2 -4" -> "+3 -5, and `Public` is kept as `_Public`".
2. Add the F24.6 and F37.5 tests (named above) as the eunit flips for B; baseline had 5 failures here, one flaky.
3. Soften or drop the kind-test call-time figure (+1.0 ns); not reproduced.
4. Say the widened variant also fixes the refined-range hole (SumOct [300] -> 600 at HEAD) and that C also opens tuple-field and record-field channels.
5. State that the forging channel requires a foreign caller; HEAD hash in the brief is 0dddf8b but compiler source is unchanged at a0199d6.
