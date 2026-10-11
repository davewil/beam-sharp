# Verification of the ticket 59 brief

Verifier: independent run, 2026-10-11. Brief was not modified. Compiler source at HEAD `5e98ae7`; `git diff 019533d HEAD -- compiler/src` is empty, so the brief's rev `019533d` and mine compile the same compiler.

Method: copied `probes/` to `$S/verify59/probes`, deleted only generated `out*`, `corpus_*`, `ctl_*` and `neighbours/*.out`, rebuilt the three scratch compilers from `compiler/src` with the author's `build-variants.sh`, re-ran every probe, diffed against the committed `.out`. (I also deleted `neighbours/gl` in my copy by mistake and restored it from the original before running probe h.)

**Overall verdict: VERIFIED WITH CORRECTIONS.** Every probe reproduces and the numbers cite correctly. But one forged-value program the author did not try (an exported parameter of union type) refutes the brief's headline reading of section 5 and the premise of the recommendation sentence. See "Finding that changes the argument".

## 1. Per-probe verdict

| probe | result | detail |
|---|---|---|
| a_asymmetry | reproduces | Only diff is `.beam bytes:` lines (1488 vs 1448, 1456 vs 1420, 1504 vs 1468), a constant +36..40 from my longer `--src-root` path in the embedded debug_info. Guard table identical. Brief does not quote those bytes. |
| b_forged | reproduces | byte-identical |
| c_cost bytes | reproduces | Code=161/149/161, 125/113/125, 142/142/147; deltas 12, 12, 5; stripped 8, 9, 0. File sizes shift by the same path effect. |
| c_cost time | reproduces in sign and order, not in exact value | Three reruns (the first was contaminated by running beside probe e). Clean reruns, median ns/call, base vs notag, 3-field: 21.2 vs 15.8 and 21.2 vs 16.5 (delta 4.7-5.4, brief says 3.8); 8-field: 19.7 vs 17.2 and 19.2 vs 17.3 (delta 2.0-2.5, brief says 2.3). Int provable and unprovable: widen within noise in all runs (11.6 vs 12.2, 10.5 vs 10.5, 56.6 vs 54.5, 54.0 vs 52.5; the unprovable case is +1.5..2 on a 52 base, same size as the base re-run spread of 2-3). Absolute ns drift 10-15% with machine load. Brief's "2.3-3.8" is the low end of what I saw; "2-5 ns" would be safer. The conclusion (tag test measurable, int test not) holds. |
| e_corpus | reproduces | byte-identical; 24 modules, 128 functions, 45 private, 0 private tag tests, 9 would gain a kind test, positive control sees 1/1. |
| i_suite | reproduces | byte-identical. Extra check by me: `clause_block`, `body_check`, `validate_as` (excluded by the brief) have identical failure sets on base and notag, so the "zero tests pin the tag test" claim holds for them too. Not run for widen. |
| f_erlang_entry | reproduces | byte-identical |
| g_elixir | reproduces | byte-identical |
| h_gleam | reproduces | only the compile-time line differs (`Compiled in 0.69s` vs `0.44s`, plus a `Compiling scope` line because my copy had no build dir) |

No probe "cannot run".

## 2. Claim ledger and number checks

| item | check | result |
|---|---|---|
| `guard_one` at `bs_emit.erl:275` | `grep -n` | ok |
| "`guard_one/8`" (sections 1 and 6 Option 2) | arity of the function at 275 | **wrong: it is `guard_one/7`** (Pat, Param, Accept, I, Line, Ctx, Public). `function/2`, `clause/4`, `boundary_guards/6` are correct. |
| `none when Public` at line 284 | read | ok |
| comment at `bs_emit.erl:330-333` | read | ok ("Exported functions only..." at 330, "that asymmetry is deliberate" at 333) |
| `beam_ssa_type.erl:122-123` | read from conda `compiler-10.0.6` | ok (source text reads "start out a 'any'", brief quotes it as "as"; trivial) |
| `beam_ssa_type.erl:444-449` | read | ok (comment spans 445-448) |
| `beam_ssa_type.erl:451` and `745-746` | read | lines exist and say what is claimed, but the brief's quotation joins two separate comments: 451 says "can't infer the parameter types of exported functions", "can receive anything" is at 746 in the other comment ("can't narrow the argument types"). Cosmetic. |
| four tests table, F24.6, F37.5 test names | grep in `compiler/test` | ok (`boundary_kind_tests.erl:88`, `boundary_range_tests.erl:122`) |
| 18 §1 "un-exported has the test elided entirely" | `18-boundary-defence.md:613-616` | quoted correctly; the brief's "partly" rating is right (ent3: `loc_known` 0, `loc_unknown` 1) |
| 26a "+14, flat" and 18 "+3-5, +/-0.09" | tickets 26:302/381, 18:438/602 | ok |
| 26 §1 "nothing measurable" | `26-data-modelling.md:313` | exists, but it compares an exported guarded tuple (7.04) with a tagged map (8.78), a 1.7 ns difference, not a private-call tag test. Ledger row 8 "refuted for a 2-function toy" compares different quantities; soften to "not comparable". |
| 12 bytes at 3 and 8 fields, 0 / 5 bytes int | my rerun | confirmed |
| 24 modules, 128 / 45 / 0 / 9 | my rerun | confirmed |
| test counts (6, 10, 7, 18, 12, 21, 32, 18, 19, 25; widen fails exactly F24.6, F37.5) | my rerun | confirmed |
| section 5 values `9`, `14`, `4.5`, `function_clause`, `badkey 'Total'` | probe b rerun | confirmed |
| Elixir `FunctionClauseError` in `priv/1`, control `2.5`, tag pattern rejected | probe g | confirmed. The prose "Elixir never elides a user-written guard on privacy" is broader than the probe: Elixir hands the guard to erlc, which can drop a defp guard when all callers are provable (ent3 shows this). Semantics are unchanged, so "guards are semantics" stands, but "never elides" is not shown. |
| Gleam: no guards on any function, control counts 1 | probe h | confirmed |
| "No Elixir source ships, only ebin" | `find lib/elixir -name '*.ex'` empty | confirmed |

## 3. Circularity audit

- **notag / widen variants.** `diff -r` against `compiler/src` shows exactly one changed line each (`orelse not Public` at 278; deleting `when Public` at 284). `variants.patch` matches those diffs and contains nothing else. Not manufactured.
- **Negative controls seen go red.** probe a: `PrivInt` shows `[]` on base and notag and `[is_integer]` on widen; `PrivRec` flips on notag. probe b: base vs notag differ in sections 1 and 2; widen vs base differ in section 4. probe e: positive control sees the planted private functions. probe i: widen goes red on exactly the two opposite-asserting tests; base/notag green. probe c: base-vs-base byte delta 0, noise-floor row. probe f: `is_integer` count drops 2 to 1 when the guard is removed.
- **Weak spots, not fatal.** (a) probe i's widen failures are by construction (the tests assert the opposite) and prove nothing beyond "these two tests pin the scope". The brief says so. (b) The probe c noise floor is measured as separate sequential re-loads, not interleaved with the pair; in my runs it sometimes sat 1 ns from the base median, which is the size of the 8-field effect. (c) The Direct control in probe b trivially has base == notag because there is no private function; it only shows inline projection is unchecked. That is its stated purpose.
- **Forged-record programs fail for the stated reason.** I read the diagnostics: `Fwd`, `Fwd2`, `Fwd3`, `Narrow` are refused with "argument 1 is not covered by Inner's declared type" naming `term`, `map<atom, term>`, `{ Kind: :'Narrow.Order' }`. These are type-mismatch refusals, not typos. The programs are well formed (module, record, clause all present).

## 4. Finding that changes the argument (my own forged-value programs)

The brief's claim 2 ("bsc refuses to hand a term to a record-typed function") is true for the shapes tried (`term`, `map<atom,term>`, `Order | map`, narrowed `term`). I tried others, in `$S/verify59/probes/src/U1..U6`. All compile on base.

```
U1: public int Entry(Order | :nothing m)   Entry(:nothing) -> 0 ; Entry(m) -> Inner(m)   // Inner private (Order o)
U5: same with option<Order>
          forged Invoice        well-formed Order
[base]    function_clause       9
[notag]   9  (silent)           9
U6: public int Entry(int | :nothing m) -> Bump(m), Bump private (int n)
[base]    Entry 1.5 -> 2.5 (silent)    [widen] function_clause
U3: public int Entry((int, Order) p)  Entry((n, o)) -> n + Inner(o)   // tuple-nested
[base]    (1, forged Invoice) -> function_clause   [notag] 10 (silent)
U2: public int Entry(Order | Invoice m) -> Total(m), Total private (Order | Invoice)
[base]    forged Kind :Other -> 9 (no guard anywhere; unrelated to scope)
U4: foreign `Order hd(list<term>)` is refused at the declaration ("Erlang cannot produce its Kind").
```

The emitted `Entry` for U1 has no guard at all (`'Entry'(M) -> 'Inner'(M).`): an exported union parameter containing a record is not tag-tested. So a **top-level** foreign value (not nested) reaches the private function, and the private tag test is the only thing that stops it. This is the route ticket 59 described ("a forged record can reach a private function by being passed through an exported one"), and it is **confirmed** for `option<Order>`, which is an ordinary shape. The same holds for `int | :nothing` and the int rule (U6).

Consequences for the brief:
1. Ledger row 2 ("refuted in the form written") should become **partly refuted**: refuted for `term`/`map`/narrowed values, confirmed for union-typed exported parameters.
2. Ledger row 3 / section 5 ("accident of call shape", "not 18 §4 working") is still true that the same value read inline (`m.Total` on U1's `Entry`) is silent, but it undersells the private test: for a union parameter it is the only defence on the path and it fires on provenance (value came from outside), not on a nested value.
3. The recommendation sentence "a private function inherits its callers' proofs" is false when the exported caller's parameter is a union that the exported guard does not test. Option 1 turns U1/U5 from `function_clause` into a silent `9`, the same failure class the brief reports for `Batch.First`, but now on a top-level argument of a common type. This weakens "smallest change, nothing breaks" (no existing test or corpus module exercises it) and is a point in favour of Option 3 (keep the split) or Option 1 plus a separate decision to guard union parameters.
4. The proposed follow-up ticket ("contents of an exported parameter are unchecked") should also name "exported parameters of union type containing a record or int are untested", since that is cheaper than the nested case (it is a top-level O(1) test, so it does fit 18 §2).

I did not examine whether an exported union guard is intended to be absent by an existing decision; grep of 18 and 26 for "union" was not done in depth. That should be checked before the ticket is written.

## 5. Corrections for the orchestrator (do not edit brief.md myself)

1. `guard_one/8` should be `guard_one/7` (section 1 intro, Option 2 delta).
2. Add the union-parameter result (section 4 above) to claim 2 and section 5, and revisit Recommendation wording and "what would change it": the stated trigger ("private record functions fed from containers") is incomplete, since private record functions fed from union-typed exported parameters also lose their only guard.
3. Ledger row 8: the 26 §1 "nothing measurable" quote is about 7.04 vs 8.78 ns (a 1.7 ns tag cost on an exported projection), not the private-call toy; say "not comparable" rather than "refuted".
4. Ledger row 8 and section 4 time figures: state the tag effect as roughly 2-5 ns/call on this VM; my reruns gave 4.7-5.4 (3-field) and 2.0-2.5 (8-field), and absolute values drift about 10-15% with load.
5. Section 3 Elixir: replace "Elixir never elides a user-written guard on privacy" with "a defp guard is semantics in the source; erlc can still drop it when every caller is provable".
6. Section 3 Erlang: the quote attributed to 451/745-746 joins two comments; cite 451 for "can't infer ... exported functions" and 745-746 for "can receive anything".
7. Section 4 ("Tests") could add that `clause_block`, `body_check`, `validate_as` have identical failures on base and notag (I checked); the exclusion does not hide a notag regression.
8. Limitations line about undeleted generated dirs: the dirs (`out`, `out_*`, `corpus_*`, `ctl_*`) are still in `probes/`; remove before commit.

No probe in the brief was found circular or manufactured.
