# Verification of artifacts/65-reserved-names.md

Verifier: independent re-run, 2026-10-22. Scratch dir: /tmp/claude-0/verify65/ (own scratch build in ws/, own outputs *.out). Nothing under artifacts/ modified except this file. Repo HEAD c3d50b9 (git history is shallow, 50 commits).

## Per-probe verdicts

| Probe | Verdict | Notes |
|---|---|---|
| 01 Elixir defmodule Map | REPRODUCED | Only diff vs author output.txt is one trailing line `Logger - error: {removed_failing_handler,...}` (author's file has it, mine does not; timing noise, not quoted in the brief). All brief quotes (warning, `:mine_not_stdlibs`, Map.new/1 undefined, URI.parse wrong values, ParallelChecker crash) match. |
| 02 Erlang builtin type / BIF | REPRODUCED, but brief's generalisation is WRONG (see U1) | Raw output identical. The probe only tests `length/1`, a pre-R14 BIF. |
| 03 Gleam 1.5.0 | REPRODUCED | Identical except compile timings. V1-V3 only show the declarations compile; V2 never uses the prelude `Ok` afterwards, so "user wins" is shown for declaration, not for resolution. |
| 04 Elm | REPRODUCED as NOT RUNNABLE | 403 from proxy, exit 1; the brief says so honestly and makes no claim from it. |
| 05 B# surface | REPRODUCED | Whole diff vs author output empty after path normalisation (all sections A, A+, B, C, D, E). Exit codes match. |
| 06 measurements | REPRODUCED | Byte-identical. M4 totals check: List 12+116+83=211, Map 82, Term 8, Float 25, total 326. |

## The OTP 25 + probe-switch patch: can it manufacture results?

- OTP 25 parts (rebar.config xrl_opts, lexer TokenLoc -> {TokenLine,1}, `~kp`->`~p`): do not touch reserved-name logic. They do force every column to 1 and cause the A10 crash in `bs_diag:message/1` (artefact; the brief says so and the detail field still shows the lexer refusal; the real lexer has no `@` rule, so "unspellable" is sound).
- `reserved_qualifiers()` is rewritten to `probe_base_reserved() -- persistent_term:get(bs_user_claims, [])`. With both env vars unset this is the repo list, and I confirmed the repo gate passes (`check-reserved-qualifiers.sh` exit 0) and ALSO that the gate's `--self-test` passes on the scratch build ("twelve defects seen, correct form accepted"). So sections A, A+ and E are not manufactured.
- Section B (BS_PROBE_EXTRA=Logger): not circular. It really goes through `reserved_module_name`; B0 (switch off) vs B1 (on) is a proper negative control. Caveat: the printed refusal in B1 for "Caller" is reported at `Logger/Logger.bs:1:1`, the declaration of Logger, not at Caller. Caller is not flagged in its own source. Brief's "both files are refused" is loose.
- Section C (BS_PROBE_USER_WINS): this IS a simulation by construction. `probe_user_claims` removes a name from the reserved list per checked module when the module is that name or imports it, via a process-global `persistent_term` that the emitter also reads. The UsesList error ("nothing declares List.Sum") is a direct consequence of deleting the name from the set, not a measurement of a designed Option 2. The brief labels it an approximation (sections 3.5, 7) and admits the emitter re-derivation problem. I tried to break it with a module using user `Map` and standard `List.Sum` together (`Both`) and a chain (`Chain`, depends on UsesMap, calls std List.Sum): both gave correct 2004, so the approximation did not go red in those cases. Verdict for C: APPROXIMATION, honestly disclosed; it shows only that the type checker's error text is unhelpful under that simulation, nothing about cost of a real implementation.
- No assertion in any run.sh can fail on its own: all probes are print-and-read (no expected values compared). Only the repo gate (E) has real red/green logic, and it covers List/Term/Map/Float, not the growth scenario in B.

## Unsupported or wrong claims

U1. **Erlang is "not user-names-win" (3.2, Option 1 evidence, "Erlang for BIF ambiguity")**: overgeneralised. I tested a post-R14 BIF: `floor(_) -> mine. f(X) -> floor(X).` compiles with exit 0 and only a WARNING ("ambiguous call of overridden auto-imported BIF floor/1"), and `nb:f(1.5)` returns `mine` (user wins). Only pre-R14 BIFs (like the probed `length/1`) are an error. So Erlang's BIF rule is itself a "warn, user wins" grace mechanism, which is evidence for Option 3 or 2 that the brief did not find, and the probe chose the one BIF class that supports Option 1. Probe 02 should add a post-R14 case.
U2. **Option 1 cost "one rename" (section 6.2)** is understated. I ran `module Shop.Logger` with `BS_PROBE_EXTRA=Logger`: a caller with `using Shop` calling `Logger.Info(n)` is refused at the call site ("`Logger` means two things here ... write the module's full path"), and `using Shop.Logger` + `Logger.Info` is refused too. Every call site must be rewritten to `Shop.Logger.Info(...)`. This is 67 Q6 (iii), which the brief cites only in passing. Probe 05 never tested the callers of the renamed module.
U3. "The ticket's table shows Haskell, Rust and Erlang all moved away from it" and the Scala/Haskell/Rust/Elm rows: not re-verified by the brief (it says so, section 7); not verified by me either.
U4. "Gleam also refuses module names" cited as Option 1 evidence: Gleam's refusal is for BEAM atom collision (`lists`, `string`) and the name `gleam`, while `list.gleam` compiled (V6). The brief does explain this in 3.3, but listing it as Option 1 evidence is a stretch.
U5. Growth dates ("Map 2026-08-25, List/Term 2026-09-03, Float 2026-09-16"): not checkable by git here (shallow history); consistent with tickets 48, 67 (resolved 2026-09-03) and F51 (F51 file line 46, 71 states Float reserved). Accepted via tickets.
U6. `bs_diag.erl:707` cited for "warnings exist only for body diagnostics": that line is the generic `built/2` clause for `{Sev,...}` with error|warning (lines 705-709), so the claim is loosely supported. The claim that the declared pass has no warning channel (Option 3) was not prototyped and I did not independently confirm it.

## Citations (all grepped)

Confirmed: bs_check.erl 244-257, 342 (reserved_module_name call), 247, 1701, 1832-1840, 3243-3250, 3486-3492, 3244; bs_emit.erl 1050, 2102; bs_diag.erl 675, 1385; erl_lint.erl 2985-2998, 3187, 439-441; LANGUAGE.md:584 (Float shipped F51), 2160-2163 ("Three names are reserved: List, Map and Term" - stale doc drift is real, four are reserved); 67 lines 149-152, 270-271, 229, 388; 96 lines 207-209, 252-253; 63 lines 405-407; 87:168; 98:45. bs_check.erl:1350 is the "lowercase prelude aliases cannot collide" comment (approximately right). The OCaml 4.5-year figure and "no edition in tickets except 65" both check out (only 65 matches "edition").

## Ticket-stale claim

CONFIRMED. Ticket 65 says "B# reserves no name today" and "nothing declares module Map"; at HEAD `reserved_qualifiers() -> ['List','Map','Term','Float']` (bs_check.erl:1701), protocol names are refused, and 67 Q1 / 96 Q6 explicitly say they answer 65's closedness question while leaving the policy to 65. The brief's reading of both is accurate (67 Q6 chose (iii), call-site refusal, which the brief paraphrases as rejecting (ii); fine).

## Options/recommendation vs probe backing

- Option 1 mechanics and gate: backed (05 A, B, E). Its cost claim: understated (U2).
- Option 2 behaviour: only a simulation (05 C); "no BEAM-level clash" backed by 05 D (Linux only, disclosed). Elixir URI.parse comparison backed by 01.
- Option 3: not prototyped; Erlang precedent exists but is wider than the brief says (U1), including a warning-and-user-wins path already live in OTP 25.
- "Foreclosed (d)" rewrite bill: backed by 06 M4 (upper bounds, disclosed).
- Recommendation D2 (reserve when ticket resolves) is a judgement, not probe-backed; consistent with the Map precedent text.
- Re-open trigger "Option 3 is the answer, not Option 2" is unsupported by any probe.

## Overall verdict

All six probes REPRODUCE; no mismatches against quoted output. No circularity in the patch for sections A, A+, B, E (gate and its self-test pass on the scratch build). Section C is a disclosed by-construction simulation, not a measurement. The brief's main weaknesses are evidence selection and cost understatement: Erlang BIF shadowing was probed only on the one BIF class that errors (post-R14 BIFs warn and let user win), and Option 1's "one rename" omits that every caller must be rewritten to the full path. The recommendation (Option 1) still stands on the evidence, but D1's cost paragraph and the Erlang row should be corrected before David reads it.
