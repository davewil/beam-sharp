# Verification of the ticket 57 brief (independent re-run)

Date 2026-10-12. Repo HEAD `8115a9c`; `compiler/src` unchanged since the brief's rev `019533d` (`git log 019533d..HEAD -- compiler/src` is empty).
Work dir: `$S/verify57/` (fresh copies of `compiler/src`, patches applied with `patch -p0`, built with the same leex/yecc/erlc recipe into new `ebin-{ref,A,B,Barith}`; `$S/57/ebin-*` not used).

**Overall verdict: VERIFIED WITH CORRECTIONS.** Every probe reproduced. Corrections are small: two diff-size counts, one eunit count, one missing table column, and a downgraded caveat on the singleton defect (it is NOT downgraded; it is real on OTP 25/28/29).

## 1. Per-probe verdicts

| probe | fresh run vs committed `.out` | verdict |
|---|---|---|
| `corpus.sh` x4 builds (34 programs) | byte-identical to `corpus.{reference,A,B,Barith}.out` | reproduced |
| `matrix.py` | follows from the above; N*, F1, P3 refused in all four | reproduced |
| `semantics.sh` x4 | identical to `semantics.{base,A,B,Barith}.out` | reproduced |
| `arith_diff.sh` | identical; control fires | reproduced |
| `options_program.sh` | identical | reproduced |
| `shape.sh` | identical except whole-`.beam` md5 and abstr sha differ run to run (path-dependent); sizes 1280/1264, flat sizes 14/7 and 30/23, Code-chunk md5 `qYemaZfXzTTl` identical; B and Barith whole-beam md5 equal ref's in my run | reproduced (the md5 of the whole beam should not be quoted) |
| `parse_shape.sh` | ref gives `e_neg`; A gives `{e_int,..,-5}`, `-(-5)` gives `5`, `-0xFF` gives `-255`, `0 - 5` stays `e_op` | reproduced |
| `f25_negative.sh` | committed `.out` has only ref, A, B. I ran ref, A, B, Barith: Barith is the same as A and B. Rows match | reproduced; brief's Barith column was not backed by the committed output |
| `neighbour_erlang.sh`, `neighbour_gleam.sh`, `neighbour_elixir.exs` | same except temp-dir names (gleam) and a locale warning (elixir) | reproduced |
| `timing.sh` (5 interleaved rounds x 40) | medians within noise (table in section 4) | reproduced |
| eunit differential | see section 3 | reproduced with a count difference |

## 2. The headline surprises, re-tested with my own programs

**(a) `value == K` -> `bad range type`: REAL, not an OTP-29 artefact.** The cause is `erl_lint` rejecting a one-point range type, and that check is old.
* OTP 29: `-type t() :: 5..5.` -> `r.erl:3:14: bad range type`; source `stdlib-8.1/src/erl_lint.erl:4051-4055` (`when X < Y`).
* OTP 25.3.2.8 (`/usr/lib/erlang`, apt): same message for the same file.
* OTP 28 (installed via micromamba into `$S/verify57/otp28`): same message; the guard `when X < Y` is at `erl_lint.erl:3443` of that release. I rebuilt unpatched bsc on OTP 28 and compiled `type T = int where value == 5` and `== 0`: both die with `compile: .../a.bs:0: bad range type`. Controls `value >= 5 and value <= 6` and `value >= 5` compile. So the "separate defect" claim stands in full, on the OTP the repo targets.
* Cited lines: `erl_lint.erl:4052-4054` is correct (case on `partial_eval`, the `X < Y` clause at 4053). `bs_emit.erl:1607` is the `{type,..,range,..}` line of `int_part/1` (function head at 1606): correct.

**(b) guard `n <= -1` unread: confirmed.** Reference: `Sign is not exhaustive / no clause matches: Sign(<= -1) -> ...` for `Sign(n) when n <= -1 / Sign(n) when n >= 0`. A, B, Barith accept it. Control `n < 0` is accepted everywhere.

**(c) literal `-5` is `int`, not `-5..-5`: confirmed.** `type Neg = int where value < 0; Lit() -> -5` on the unpatched compiler: `not covered by the declared return type: int >= 0`. A and Barith accept, B still refuses. Extra sign checks I wrote: under A, `type T = int where value >= -(-5)` accepts a body of `5` and refuses `4`; `value >= -5` accepts `-5`, refuses `-6`; `value >= -9223372036854775808` accepts that value and refuses `...809`. So the fold is not off by sign anywhere I looked.

**(d) `n / -0`: confirmed.** Reference and B accept; A and Barith refuse with `the right-hand side of `/` in D is always zero`. `n / -1` is accepted in all four.

## 3. Numbers and citations

| claim | result |
|---|---|
| patch sizes 1 / 8 / 15 lines | **1 / 9 / 16 added lines** by `diff`; the brief's 8 and 15 exclude one blank line in each patch. Hunk headers: B `+5024,18` from `-5024,9`; Barith 2 + 14. Correct to 9 and 16, or say "non-blank" |
| each build contains its patch | confirmed by behaviour: A parse tree folds; B and Barith leave `e_neg` in the tree yet accept `value >= -5`; only Barith accepts `0 - 5` and `2 + 3`; only Barith/A type `-5` as a singleton. Beams differ byte-wise only through embedded paths, so compared by behaviour |
| yecc conflicts `6 shift/reduce` | confirmed in my build output (`bs_parser.yrl: Warning: conflicts: 6 shift/reduce, 0 reduce/reduce`, OTP 28 build) |
| 1437 pass / 11 fail, identical sets | **I get 1438 pass / 10 fail in every build, with identical failing sets across ref/A/B/Barith (md5 equal).** The one-test difference from the brief is `cli_tests:escript_entry_point_exists_test`, which passes for me because I copied `rebar.config` into the tree. Headline (no existing test breaks under any patch, 10 environmental failures are the same list) is confirmed; the count in section 4.6 and section 7 should say "1437/11 in the author's tree, 1438/10 with `rebar.config` present". Each build used its own escript: my trees put `_build/default/bin/bsc` built by `mkesc.escript` from that build's ebin, and I checked that the four escripts behave differently on `value >= -5` (ref refuses, others accept). The author's tree layout has the same structure (`tree-A/_build/default/bin/bsc`) and the project_root logic picks it up |
| `bs_parser.yrl:219-221` | correct (comment then `refinement -> expr_low`, 221) |
| `bs_parser.yrl:397,401,444,463-466,471-472,947` | all correct |
| `bs_check.erl:1910`, `:4985`, `:2889`, `:5016-5017` | all correct |
| `intervals_tests.erl:293` | correct: lives in `compiler/test/`; `Classify(<= -1)` as a pattern |
| F51 `e_neg` shape | confirmed, `{e_neg,{2,29},{e_int,{2,30},5}}` |
| compile time unchanged | backed by interleaved rounds (loop is round-major, builds inside). My rerun, 5 rounds x 40, in-VM parse/check only: parse examples ref 1549 / A 1557 / B 1498 / Barith 1531; check examples 6522 / 6894 / 6499 / 6625; synth-pos parse 864/883/884/863; synth-pos check 1949/1972/1957/2009. Spreads of 5-30 percent, so nothing separates. Caveat: this times lex/parse/check in one VM, not `bsc` end to end. The brief omits the `check synth-neg` row, which differs a lot (ref 1493 vs A 2375): that is the reference refusing early, not a cost, and the omission should be stated |

## 4. Circularity audit

* **Negative controls go red where they should.** I saw `value >= n`, `value >= x + 1`, `value >= value`, `value >= F(1)`, `int where value >= 1.5` and float `value >= -1.5` stay refused with the `not a predicate the checker can read` text in all three patched builds, and `Sign(<= -(1))` stay a syntax error. They are refused for the stated reason, not a side effect. Also refused in every patched build, by my own programs: `value >= -n`, `value >= -value`, `-value <= 5`, `value + 1`, bare `value`, `value >= -5.0`.
* **Corpus matrix compares like with like.** Same source revision, same build recipe and OTP for all four; the reference ebin I rebuilt gives the same results as the brief's `bsc-ebin`. The `refused` classification is "any output", which is weak, but I read the first diagnostic line of each patched control and they are the intended error. The harness aborts on a VM crash, as claimed.
* **Weakness: "want" column and the F1/P3 rows.** The `want` column is the post-fix wish written by the author, so the `!!` count is not an independent test; but the acceptances I cared about were separately re-checked for sign and bound correctness (section 2c).
* **Extra inputs the author did not use, all four builds** (ref refuses all; patched builds):
  `value >= -(-5)`, `value >= - 5`, `value >= -0x10`, `value >= -9223372036854775808`, `value >= -(-(-5))`, `value >= --5`, `value >= -5 and value <= -(-5)`: accepted by A, B, Barith. `value >= -(1+2)`: accepted only by Barith. `-0b101`: syntax error everywhere (no such literal in B#).
  Negation in a record-field refinement (`type Depth = int where value <= -1 and value >= -50; record Well {Name: string, Z: Depth}`): constructing `Well{Z = -3}` is accepted by A and Barith; B rejects it with `int <= -51 | int >= 0`, which is exactly the "literal is still `int`" gap the brief attributes to option 2. `Z = 3` is refused by A, B, Barith. (My attempt at a record pattern `Well { Z = -1 }` was a syntax error in all builds including ref: my syntax, not a finding.)
  Double negative in a pattern: `Z(--5)` and `Z(-(-5))` are syntax errors in all builds (A leaves the pattern grammar alone); `Z(- 5)` is accepted in all, including the reference (the brief says nothing about the space in patterns).
* **Not circular but unstated:** option A changes a diagnostic column by one on every `-N` literal (brief states this).

## 5. Corrections for the orchestrator (do not edit `brief.md` from here)

1. Section 4.3 and the options: diff sizes are 1 / 9 / 16 added lines (8 / 15 exclude a blank).
2. Sections 4.6 and 7: eunit is 1437/11 in the author's tree and 1438/10 in mine (the `escript_entry_point_exists_test` case depends on `rebar.config`). Failing set identical across builds in both.
3. Section 4.2 F2.5 row cites a Barith column that `f25_negative.out` does not contain. Re-generate the committed output with all four builds (my run supports the claim).
4. Section 4.4: do not rely on whole-`.beam` md5 values (they are run-dependent); the Code-chunk md5 and byte sizes are stable.
5. Section 4.5: say the timing is in-VM lex/parse/check, and either drop `check synth-neg` explicitly or mention that the reference refuses early there.
6. Claim 14 / "separate defect": keep it as is. Add one sentence: reproduced on OTP 25 and 28, the same `erl_lint` check, so it is not a toolchain artefact.
7. Optional: note that pattern `- 5` (with space) is already accepted by the reference, a precedent for A's `value >= - 5`.

Artifacts of this verification: `$S/verify57/` (fresh outputs in `probes/fresh/`, `timing.fresh.out`, `eunit-*.log`, `fails-*.txt`, OTP 28 env in `otp28/`).
