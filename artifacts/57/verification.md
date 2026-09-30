# Verification of artifacts/57/brief.md (ticket 57, ENG-239)

Verifier run 2026-09-30, OTP 25, compiler tree unchanged since `0dddf8b` (`git diff 0dddf8b HEAD -- compiler` empty).
Nothing in the repo was edited or overwritten. Everything ran from a copy of `probes/` in
`/tmp/claude-0/-home-user-beam-sharp/2e35dc52-b5e4-5ac3-801c-9c12d8324568/scratchpad/verify57/`
(`probes/` copy with `/tmp/bsc57*`, `/tmp/src57*`, `/tmp/run57*`, `/tmp/tests57` rewritten to that dir; outputs in `out/`;
my own programs in `hand/`). All six compilers (baseline, A1, A2, B1, B2, B3) were rebuilt from scratch: baseline via
`build_bsc.sh`, each variant from a fresh `cp -r compiler/src` plus its patch (all five patches applied cleanly).
The only reused external artifact is `/tmp/leexnew` (maint-26 leex, not re-fetched).

## 1. Probe reproduction

Committed `.out` files carry `$W` in place of the mktemp directory (a post-hoc sed that no script performs) and a
compile-time stamp. After normalising those two things:

| probe | per-variant runs | verdict |
|---|---|---|
| 57a refinement table | base, A1, A2, B1, B2, B3 | REPRODUCED (byte-identical after normalisation) |
| 57b ast shape | base | REPRODUCED |
| 57c guards/literals | base, A1, A2, B1, B2, B3 | REPRODUCED |
| 57d emit and runtime | base, A2 | REPRODUCED |
| 57e paste the residual | base, A1, A2, B1, B2, B3 | REPRODUCED |
| 57f signed domain | base, A1, A2, B1, B2, B3 | REPRODUCED |
| 57g Erlang/Elixir | - | REPRODUCED |
| 57h Gleam/Elm | - | REPRODUCED (Elm half is honestly "NOT PROBED") |
| eunit suite, 1303 tests | base, A2, B1, B2, B3 | REPRODUCED: 54 errors each, failing SET identical to base and to committed `suite_base.out` |
| eunit suite | A1 | **DIFFERS**: 55 errors, see F1 |

Numbers in the brief's Measurements table (A2 accepts R1-R3, V3-V7; B1 accepts R1-R3, V3, V5-V7; B2 adds V1, V2, V4, V8;
A1 makes V1-V4, V8 syntax errors; `Clamp` compiles only under A2 and B3; `10 / -0` becomes an error under A2 and B3
only) all match the real outputs. `bs_parser.yrl` reports "6 shift/reduce" in all six builds.
The suite was first started twice by mistake (two racing runners); I killed both, cleaned, and reran one runner; the
numbers above are from the clean run. Nothing was restored because nothing committed was written.

## 2. Findings

### F1 (HIGH, brief is wrong): "54 failures on baseline and on every variant" is false for A1

`run_suite.sh` lists `base | A2 | B1 | B2`; there is no committed `suite_A1.out`, so the A1 suite row was never measured
and the Measurements table's "same 54" in the A1 row is unsupported. I ran it: **55 errors**, one extra:
`intervals_tests:an_unreadable_refinement_predicate_is_an_error_test`
(`compiler/test/intervals_tests.erl:46-53`). It expects `opaque_refinement` for `type Email = int where WellFormed(value)`;
under A1 that is a syntax error, so the documented "O(n) tier" diagnostic (also quoted in the `opaque_refinement` text)
is lost. This strengthens the case against C and does not touch A or B, but the brief's table must change.

### F2 (MEDIUM, omission): A2 changes two more parse sites, not mentioned

`to_match/1` (`bs_parser.yrl:882`, `-1 = x`) and `to_param/1` (`:930`, lambda `(-5) => ...`) accept `{e_int,_,N}`.
With A2 both now parse (`-1 = x` reaches the checker and reports "this bind can fail"; baseline said "must be a
literal pattern"). Arguably an improvement (patterns already admit `-5`), but it is a surface change beyond the
"one added line" story and belongs in the brief. Verified with `hand/w/Sf`.

### F3 (LOW, overclaim): Option B "equals A on every probe I wrote"

False on V4 (`value >= - -5`): A2 accepts, B3 refuses (57a_table_A2 vs B3). The Measurements table itself shows this
(A2 "V3-V7", B3 "as B1"), so the table and prose disagree. Also `-(5)` (V3) agrees only because parens leave no node.

### F4 (LOW, cause attribution incomplete): the 54 failures are not only `json:encode/1` and `maps:iterator/2`

Of the 54 (same in every variant except A1): 17 `maps:iterator/2`, 11 `json:encode/1`, 5 `json:decode/1`, plus
`-0.0` vs `0.0` matching (`float_tests` line 104 etc., OTP 27 semantics), `io_lib ~k`, and some `badmatch,[]` that
follow from the same env gaps. The `-0.0` failures matter: they sit next to the negation code A2 touches, so the suite is
blind in exactly the `e_neg`/literal area on OTP 25. The brief does say the suite is weak and owes a clean OTP 28.5 pair.

### F5 (LOW, citation drift): `bs_parser.yrl:219`

The refinement rule is at `:221`; the explaining comment is `:217-220`. Survey text cites `:942-944` for the float fold
and elsewhere `:944-945`; the real lines are `:944` (float) and `:945` (`e_neg`). Harmless.

### F6 (LOW, presentation): probe design

- `common.sh:9-11` `probe()` counts any output at all (including a warning) as "refused"; every refused row in 57a
  shows an `error:` line, so no conclusion depends on it.
- 57a's `expected` column is the ticket's table (the brief says so); variant tables print `!!` when a variant changes
  the answer. That is a correct signal, but the `.out` files read as failures. No swallowed failures, no stderr
  discarded (`2>&1` throughout), no hardcoded outputs, no detection of the patch: every probe judges by real `bsc`
  output, `.abstr`, `beam_disasm` and runtime results.
- 57f base output lines `Direction(-100) =>   reasoned about...` come from `tail -1` of an error block: cosmetic.
- 57c R1 wrong `expected`: annotated honestly at `57c_guards_and_literals.sh:40` (not inside the `.out`). It does not
  feed any conclusion; the brief's claim about residual spelling rests on R0 and 57f E.
- 57e lacks a control (pasted *non-negative* guard in the nested position). I supplied it (below).
- `57d` compares `beam_disasm` of `Lit` only. I compared all functions in a module with `Lit`, `Mul`, `Sub`, `Paren`:
  disassembly is identical base vs A2 (whole-file bytes differ only in the debug/abstract chunks).

### Is A2 circular? No.
A2 is judged by the same unmodified checker plus real runtime; no probe greps for the patch. The one circularity risk,
that the 57a "expected" column echoes the ticket, is disclosed and does not gate any variant verdict.

## 3. Independent hand-written checks (`hand/w/*/a.bs`)

| my program | result |
|---|---|
| `type Nz = int where value != 0`; `Half(-5)` and `Half(5)` | base: `Half(-5)` refused ("not covered: 0"); A2 and B3: accepted; runtime `Go()` = -20 on both |
| `type NonPos = int where value <= 0`; `Down(-7)`, `Down(3)` | base: both refused (`Down(-7)` wrongly: "int >= 1"); A2/B3: only `Down(3)` refused, correctly |
| nested guards in `(:ok, int) | (:error, atom)`: `when n < 0`, `when n <= 0`, `when n >= -3` / `n < -3` | base accepts the two non-negative-bound forms (control), refuses the `-3` form with residual `n <= 0`; A2/B3 accept |
| `n >= 0 - 0`, `n < -0` residual | still unreadable under A2/B3 (consistent with "Q2 lapses, `2 + 3` stays refused") |
| paste loop (57e) with my own negative bound | fixed point exists only for negative bounds, top-level residual prints as a legal pattern `Sign(<= -1)` (57c G2), nested prints as a guard and cannot be written as a pattern (57e P3) |
| precedence: `-5 - 3`, `-2 + 3`, `2 - -3 - -4`, `-2 * -3`, `-x + -3 - -2` | identical results base vs A2 (-8, 1, 9, 6, -5) |

## 4. Citations and numbers

- `bs_parser.yrl:589` (`'-' expr_low : negate`), `:944-945` (negate clauses): CONFIRMED.
- `bs_check.erl:1892` (`refine` -> `alternatives`), `:4910` (`apply_guard`), `:4941-4942` (`comparison`), `:2867` (`type_of e_neg`): CONFIRMED.
- `bs_emit.erl:455` (`cmp/4`), `:661` (`rel_expr`), `:698-700` (`kind_expr`): CONFIRMED.
- `bs_diag.erl:1954` (`opaque_refinement` message): CONFIRMED.
- LANGUAGE.md: the `Classify` program is in section 2 (`:212-217`) and reused in section 3 (`:440` heading;
  program at `:453-458`, with `expect-after: delete Classify((:ok, n)) -> :negative` and the residual
  `Classify((:ok, n)) when n <= -1 -> ...` at `:465`). The brief's "section 3's own Classify" is right; the language doc
  itself documents the residual the compiler cannot take back.
- F51: Status done 2026-09-16; "a float refinement, refused as opaque" is in its Leaves; it records `-` folding into
  float literals and `e_neg`. CONFIRMED. "Every F2 scenario is non-negative": no negative bound in F2's scenarios
  (only residual examples), plausible and CONFIRMED by reading.
- Ticket 57's `0 - 5` mechanism claim is stale as the brief says (yrl now `negate/2` -> `e_neg`). CONFIRMED.
- Ticket 38 sect. 2 supports the "divisor is always zero" side effect (`n / 0` refused). CONFIRMED.
- F51 and 1303 total tests: CONFIRMED.

## 5. Evidence table verdicts

| row | verdict |
|---|---|
| Every negative-literal refinement refused; `<=3 or >=10`, `!=0` accepted | CONFIRMED |
| `-5` parses to `0 - 5` | CONFIRMED REFUTED (it is `e_neg`) |
| Diagnostic recommends the form it rejects | CONFIRMED |
| Guards with a negative literal unreadable | CONFIRMED |
| Pasted residual reprints the same error | CONFIRMED (nested position only; needed the control I added) |
| `Half(-5)` refused, `-5` typed `int` | CONFIRMED (own program) |
| Residual "cannot be accepted by the surface" partly refuted | CONFIRMED |
| Float refinements refused | CONFIRMED |
| `erlc` output unchanged under A2 | CONFIRMED (stronger than the brief measured) |
| Negative `e_int` already built by the compiler | CONFIRMED |
| Nothing regresses, same 54 | CONFIRMED for A2, B1, B2, B3; **NOT CONFIRMED for A1 (55, F1)**; cause list incomplete (F4) |

No row is CIRCULAR.

## 6. Does the recommendation still follow?

- **Option A (parser fold), yes.** Every measured claim about A2 reproduced, including with my own programs; semantics
  of `-5 - 3` etc. are preserved. Add F2 (lambda parameter and bare-`=` now accept `-N`) to the brief's side effects.
- **B3 acceptable, yes**, as two-site checker fold only; B1 alone is insufficient (`Clamp` refused, `Half(-5)` refused),
  confirmed. Correct the "equals A on every probe" sentence (F3).
- **C declined, yes, and more strongly than the brief says**: A1 also breaks an existing test and removes the
  `opaque_refinement` diagnostic for the `WellFormed(value)` tier (F1).
