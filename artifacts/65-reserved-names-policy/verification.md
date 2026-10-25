# Verification of brief.md (ticket 65), independent re-run

Fresh scratch: scratchpad/verify65/ (compiler sources copied from HEAD 1429fdc, patches applied from probes/opt2-patch and opt3-patch with `patch`, rebuilt with leex/yecc/erlc; sources identical to bsc-build).
Raw outputs: scratchpad/verify65/out/. Diffs vs stored .out ignore only the scratch path prefix.

## Probes
REPRODUCED (byte-identical after path normalisation): p1, p2, p3 (HEAD and rebuilt opt3), p4, p4b (D 6/6 crash, A 0/6, elixirc 0), p5, p6, p6b, p7, p7b (9/10), p8 (network 403, same), p9 (4 qualifiers, 30 rows), p10 (81), p11 (HEAD and rebuilt opt2), p12 (50/187/30/181), p13 (HEAD diagnostic, opt3 silent 1000), p15 (1321; Math, Queue).
CANNOT RUN: p14 (no script, git history; squash commit only). p8b has no script (only .out); I re-ran `strings` on the elm binary and "AMBIGUOUS IMPORT" and the "locally defined module" hint are present.
Patch line counts match the brief (opt2 +16/-8, opt3 +12/-3). p3 has no PATH export of its own (needs erl on PATH; rc 127 otherwise).

## Circularity
No probe is circular. Weak spots:
1. Opt3 "silent flip" (p13) is a consequence of the patch's design: `user_wins` skips `reserved_call`, which is the only place the Q6(iii) ambiguity error lives. A user-wins variant that keeps the error when a namespace short-qualifies a claimant is possible and was not prototyped. The flip is shown for this patch, not for option 3 as such.
2. p10 "0 of 81 collide with the five" holds by construction: a corpus that compiles at HEAD cannot contain `module Map/List/Term/Float/Enumerable`. The v1 (_build) output did contain them, as test-generated fixtures of the refusal tests; excluding _build is correct. The informative parts are the roster and OTP-case results, not the 0.
3. Opt3 emitter keys state on {Mod, Line} in the process dictionary. I forced Lib.Count and App.Go onto the same line 7: Via still returned 1, so the "dependency unchanged" result does not depend on the line choice.
4. v1 -> final changes (p1 layout, p2 record syntax, p3 FromList placement, p10 _build, p8 elm.json) fix harness errors; none favours the conclusion (p3 v1 disclosed the same cost).
5. p6 controls: p6b is a separate directory, not the same dir minus lists.beam. Adequate.

## Citations (checked against files)
OK: 96:206-208 (Q6 yes; "answers ticket 65's first question by rule") and 96:252-253; 67:270-271, 424-426, 458-459 (Q6 iii, "nothing is silent"); bs_check 241-254, 339, 1426, 1699, 3238-3260, 3283-3295, 4558-4570; bs_diag 675-677, 1385-1400; bs_lexer.xrl 3-6; bs_emit 1049-1062; erl_lint 3951-3955, 3969-3983; F54:166-172; 87:167-170; F55:173; 63:406; F27:44; LANGUAGE.md:334; F32/F51/F64 done dates 09-04/09-16/09-28; reserved_qualifier_tests 229-245; ticket 48:440 has types.ex:291.
The load-bearing claim holds: 96 Q6 asked exactly "is a module with that short name refused where it would be written as the word" and David answered yes, as 67 Q6 did for List. That is option 1. Caveat: Q6 never compared options 2 and 3, and ticket 65 is still `Status: open`.
Errors:
- `reserved_forms` at ":2099" is bs_emit.erl:2099, not bs_check (brief reads ambiguous).
- Lowering "to lowercase OTP calls" omits `generated` rows (Term.Compare, List.Insert, ...), emitted as local functions. Still no capitalised beam, so conclusion stands.

## Claimed as measured, unsupported or wrong
- "nine more qualifiers" lists eleven (Enum String Int Process GenServer Supervisor Logger System Binary Task Agent); "~14 with the roster" would then be 16. "5 of them (String, Int, Binary, Json, Logger)": Json is not in the roster.
- "option 2 rewrites ~490 sites": the p12 sum is 448. The p12 regex also counts prose in wayfinder/docs and dotted `Shop.List.Sum(`, so these are upper bounds on code sites.
- "cost of one more name is one line + one test" is not a probe. I checked the one line (adding 'String' to reserved_qualifiers/0 in a copy refuses `module String` with the generic message); the test/line totals (15, ~20, ~12) are estimates.
- Gleam "erlc's own warning surfacing" is inferred from the message format, not shown.
- Case-insensitive-FS failure, Elm behaviour, gleam_stdlib collision: stated as unmeasured in the brief, correctly.
