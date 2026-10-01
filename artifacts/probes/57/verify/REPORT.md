# Independent verification of the ticket-57 brief

Verifier run 2026-10-01, HEAD 0dddf8b, OTP 27.3.4. Own scratch dir (not the author's). Nothing in the tree or compiler/ was modified.
Files here: `v6_new_probes.sh` (my probes), `v6_{HEAD,A,B,C}.out` (outputs), `v3_rerun.out`, `base_eunit.log`, `variantA_eunit.log`, `variantB_eunit.log`.

## Per-claim verdicts

| Claim in brief | Verdict |
|---|---|
| p1: refusals `>= -5`, `!= -1`, `== -1`, `-5 <= value`, `-(5)`, `2 + 3`; accepts `<= 3 or >= 10`, `!= 0` | REPRODUCED (diff of rc lines vs p1.out identical) |
| Pattern `Sign(<= -1)` accepted | REPRODUCED |
| Ticket mechanism stale: unary minus is `e_neg` (`bs_parser.yrl:589`, `negate/2` `:944`) | REPRODUCED (ticket text still says `0 - e`; source says e_neg, float folded) |
| `alternatives/1`, `comparison/1` at `bs_check.erl:4923`, `:4941` shared by refinements and guards | REPRODUCED (also called at :1892 and :4910) |
| p2: G1 refused at HEAD; G2, G3, G4 accepted | REPRODUCED |
| `negate/2` already folds a float literal | REPRODUCED |
| p3 table (A/B/C acceptance of refinement table, `2 + 3`, guard G1) | REPRODUCED (rebuilt each variant from `git archive HEAD` + patch; output diff identical to p3.out) |
| Line counts 1 / 2 / 22 | REPRODUCED (patch +lines) |
| p4: under A and B, accepts -5, 0, 5; rejects -6, 6 with function_clause | REPRODUCED (A and B; identical to stored .out). On HEAD p4 fails to compile, so it discriminates |
| Full eunit, A and B: 1299 passed / 4 failed, same four | REPRODUCED for A and for B (failing sets identical to each other) |
| Baseline 1298 passed / 5 failed | REPRODUCED (5 failed) |
| "Fifth is a flaky diagnostic_term_tests gate" | DIFFERS: not flaky. See below. |
| Four failures "environmental, unexplained"; guesses locale / aoc outside compiler/ | Guesses CORRECT, now explained (below) |
| Erlang: parser keeps `{op,_,'-',{integer,_,5}}` in guard and pattern | REPRODUCED |
| `erl_parse.yrl:1799 normalise({op,_,'-',{integer,_,I}}) -> -I` | REPRODUCED verbatim (OTP 27.3.4 source line 1799). Caveat: `normalise/1` is the abstract-form-to-term converter, not a folding pass of the compiler; the sentence "folding happens later" is correct for the compiler overall but this line is not evidence of compile-time folding. |
| `erlc -S` of `X >= 2 + 3` emits `{integer,5}` | REPRODUCED (`{test,is_ge,..,[{x,0},{integer,5}]}`); `-5` likewise `{integer,-5}` |
| Elixir 1.14: `x >= -5` is `{:-, _, [5]}`; `-5` and `2+3` work in guards | REPRODUCED (also a `-5` case pattern is a unary node) |
| Gleam 1.18.1: `-5 ->`, `n if n >= -5`, `n if n >= 2 + 3` compile | REPRODUCED. Extra observation: generated Erlang keeps `N >= (2 + 3)` unfolded and emits `-5` as a literal. Whether Gleam folds `-5` at parse is NOT CHECKABLE (no sources), so "both BEAM neighbours keep the unary node" is only about Erlang/Elixir; do not extend to Gleam. |
| Elm not measured | NOT CHECKABLE (stated as such by the brief) |
| Recommendation B "matches how Erlang and Elixir do it" | Judgement; see correction 1 |

### Why the baseline failures fail (from the eunit log)
- `every_aoc_program_still_compiles`: `length(Dirs) >= 3` is false. The test reads `<parent of compiler/>/aoc`, which a `git archive HEAD compiler` copy lacks. Guess right; purely an artefact of copying only `compiler/`.
- `batch_runs_every_entry_in_one_vm...` (expected `"hÃ©llo"`... got `"héllo"`), `a_path_is_utf8_on_the_wire` (looks for `cafÃ©.bs`), `a_non_ascii_literal_is_advised_as_written` (expected `cafÃ©`, got `café`): the test sources' UTF-8 literals are read as latin1 because the sandbox locale is POSIX/empty (`LANG=`). Guess right.
- Fifth, `diagnostic_term_tests:the_diagnostics_gate_passes_test`: `bin/check-diagnostics.sh` exits 1 with "no built bsc at .../_build/default/bin/bsc — run rebar3 escriptize". An eunit-only baseline copy has no escript; variant dirs passed because p3 had escriptized them. After `rebar3 escriptize` in my baseline copy the gate prints `diagnostics: ok`. So it is deterministic, and the baseline/variant comparison for it was asymmetric by construction, not flake.

## Circularity hunt
- Patches contain no probe-specific text; p1/p2 reused unchanged on every build. Not circular.
- p1 discriminates (HEAD red, variants green). p2 G2/G3/G4 are controls that are green at HEAD and so do not discriminate patch from no patch; they only localise the cause to the literal. Acceptable, but p2 has no *over-acceptance* control: "variant fixes guards" is true by construction (B edits `comparison/1`, the shared function; A changes the AST). The brief never shows the fix does not accept guards that have a gap. I added those (H1-H4, below): all correct, so the claim survives, but it was untested.
- p4 is not circular (a variant that dropped or mis-signed the bound would accept -6/6). It only covers one range, `and`-form.
- eunit "no regression" is weak evidence about the change: no existing test pins a refusal of a negative refinement (`intervals_tests` opaque_refinement cases at :53, :60 use other shapes), so a green suite says little about `-5`. Fine as a "no collateral damage" claim, not as support for correctness.

## New probes (`v6_new_probes.sh`; results v6_*.out)
- `>= -0`, `>= -1000000000000000000000`: refused HEAD; accepted A, B, C.
- Guards, flipped operands and strictness: `-5 <= n` / `-5 > n`, `n > -5` / `n <= -5`, `n >= -5` / `n < 5` accepted under A, B, C; gap cases `n > -5` + `n < -5`, `n >= -5` + `n < -6`, `n >= 5` + `n < -5` correctly REFUSED under A, B, C; unreachable-clause warning correct. Runtime: F(-6)=:b, F(-5)=:a, F(0)=:a. No variant emits a wrong boundary.
- Arithmetic with negative literals under A (`n - -5 + -3*2`, `-2147483648 - 1`, pattern `K(-5)`): correct values; folding does not alter codegen.
- Union `value >= 1 or value <= -1` under B: Id(0) rejects. Fine.

### Findings the brief missed
1. **A and B are not equivalent for call sites.** With `type Neg = int where value <= -1`, `Take(-3)` is ACCEPTED under A (the literal is `e_int`, typed as the singleton range); B REFUSES it ("Go hands Take an argument it does not accept; argument 1 is not covered ... int >= 0"), because `type_of({e_neg,..})` returns plain `int`. `Take(3)` for `Pos = int where value >= 1` is accepted at HEAD. So under B a refinement with a negative bound is declarable but cannot be satisfied by a negative literal argument; the caller must add a `Go(<= -1)` clause or similar. The brief's table tests declarations only, and its counterargument against A ("AST rewrite loses the distinction") omits that this is exactly what makes A behave like the non-negative case. C also refuses (checked: C output equals B's). This weakens the recommendation of B; either pick A, or B must also teach `type_of` that `e_neg` over an int literal is a singleton range.
2. `- -5` and `-(-5)`: A accepts (folds twice, value >= 5; semantics verified: Id(4) function_clause, Id(5) ok); B and C(at declaration) differ: B refuses `- -5`; C accepts `-(2 + 3)`; A and B refuse `-(2 + 3)`. Not covered by brief's table.
3. Pre-existing, unrelated: mixed `and`/`or` refinements such as `value >= 5 and value <= 8 or value == 100` (and `value >= 5 or value == 1`) fail at HEAD with `compile: ...:0: bad range type` when the type is used by an exported function. Not caused by any variant, but it limits what "all accepted" means and deserves its own ticket.

## Corrections required in the brief
1. Add finding 1 above; reconsider or caveat the B recommendation (B leaves negative literals typed `int`).
2. Replace "a fifth, flaky `diagnostic_term_tests` gate" with: that gate needs an escriptized bsc, absent in an eunit-only copy (passes after `rebar3 escriptize`).
3. Replace "did not diagnose why they fail" with the causes above (aoc dir outside `compiler/`; POSIX locale reading UTF-8 test sources as latin1).
4. Qualify `erl_parse.yrl:1799`: it is `normalise/1` (term conversion), not a constant folder; support the "Erlang folds after parse" claim with the `erlc -S` measurement instead.
5. Do not group Gleam with "both BEAM neighbours keep the unary node": measured Gleam output emits `-5` as a literal and leaves `2 + 3` as `(2 + 3)`; its parser behaviour is unverified.
6. State that eunit green says nothing about negative refinements (no test pins them) and that p2 lacks gap controls; cite H1-H4 as added.
