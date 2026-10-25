# Verification of brief.md (ticket 66), independent re-run

Fresh builds in `scratchpad/verify66/` (stock from `compiler/src` at HEAD 8237fbc, compiler commit 1429fdc, via leex+yecc+erlc; each `.diff` applied to its own fresh copy of `compiler/src`; probes copied and re-pointed at the fresh builds). Repo `compiler/`, `wayfinder/`, git and Linear untouched.

## Circularity flags (first)
No probe is patched-to-pass, hard-coded or filtered. Each patch applies cleanly (proto 36 added lines, proto2 +17 more, promo 1 line, promoall 7 sites, promonamed about 10). Closest to circular, all mild:

1. **3c matrix (`severity_matrix`)**: E5 and E6 are two inputs chosen to separate a predicate (`names_a_type`) written to separate them. It shows 3c does what it was defined to do, not that "names a type" is the right line. "Consistent with 89 A2" is the brief's reading (A2's own words: "naming the type is what makes the mis-shape speak").
2. **corpus_proto "28 modules, 0 differences"** is a no-regression check, not evidence that union equals hand-duplicated. Stock refuses `C c`, so no example can contain a union-name pattern; the result would hold for any additive patch. The harness is sensitive, though: a control build (one renamed generated-variable prefix at `bs_emit.erl:585`) makes the same script report `differences=2` (Parcel, Shop). The brief states it only as "changes nothing already shipped", which is fair; section 9 leaning on it as a reason for B is weak. Dup-vs-union equivalence rests on `run_proto_values`, my N=20 check (88 for R1, R20 and `:none` in both forms) and the asm probe. The corpus also excludes `compiler/examples/exemplars/` (46 files; none compile on stock either).
3. **Scale table**: the two programs are semantically equal (same body, same results) and the single clause does not discard work, it is the body written once. But every dup body is byte-identical, the best case for the union. The realistic alternative (N heads calling one shared helper) is not measured.
4. **Gates "0 of 37" is overstated.** With the compiler shim replaced by `exit 7`, 34 of 37 gates go red; `check-feature-scenarios`, `check-no-silent-skip`, `check-record-idiom` stay green, so they cannot see any compiler change. `check-helper-agrees` is red at baseline (rc=1 both sides), so it cannot turn newly red. Effective: 0 of 33 informative gates. "No gate reads severity" is not shown: 10 gates mention "warning"; what is shown is that no exit code changed.
5. **Gleam p2** "c is typed Shape": the probe passes `c` to `take_ab(c: Shape)`, which would compile if `c` were narrower too. True of Gleam, but the probe does not discriminate.
6. **Elixir idiom 3** (`three(%E{})` after the disjunction "not diagnosed"): `E` is not covered by the first clause, so the clause is reachable and no diagnostic is correct. It does not test "no inhabitant check". Idioms 1 and 2 are fine.

## Probe groups
| group | verdict |
|---|---|
| `run_exemplars` (5 exemplars, stock rebuilt) | REPRODUCED byte-identical |
| `run_proto_cases`, `run_proto_values`, `run_proto2_cases`, `run_proto2_g3` | REPRODUCED. Only diffs: `src/bs_emit.erl` vs `bs_emit.erl` in the P5 stack trace, and the stored `.out` files hold junk sections for `P1.abstr`, `G1.beam` etc. (a glob ran over build output); harmless |
| `severity_matrix` | REPRODUCED rc for rc (wrapper names differ in my copy) |
| `corpus_proto`, `corpus_promo`, `corpus_promoall` | REPRODUCED (28 modules, 0 differences, 0 warnings) |
| `measure_scale` | REPRODUCED: handle words identical in all 12 cells; beam bytes +20..24 in every cell (longer scratch path), ratios unchanged (N=20: dup 5844, union 2416 vs brief 5824, 2392); timings noisy as the brief says |
| asm (`erlc -S`, E3 proto vs E4 stock) | REPRODUCED: both end in one `select_val` on `Kind`; union uses `bif map_get`, dup uses `is_map` + `get_map_elements` |
| `type_test_probe` (stock `bs_emit` + export_all) | REPRODUCED identical |
| `run_collapse`, `run_residual` | REPRODUCED |
| `run_gates_both`, `run_gates_promoall` | REPRODUCED (36 equal at rc=0, `check-helper-agrees` rc=1 both) |
| eunit | Full 1508-test runs were too slow here. I re-ran the 9 affected modules (176 tests). 3b adds exactly 4 (`heads_tests` x3, `down_view_tests`): REPRODUCED. 3c adds 0 (only the 2 env failures, `diagnostic_term_tests` x2): REPRODUCED; as a strict subset of 3b it cannot add elsewhere. promoall: 19 newly failing; the brief's "adds 18" is the net 27 minus 9, because one base failure (`a_path_is_utf8_on_the_wire_test`, environmental) did not recur |
| erlang, elixir, gleam | REPRODUCED (orpat syntax error; guard idiom; union_idiom and docs; gleam p1 warning/error set, p2, first-attempt error) |
| elm | Brief makes no claim. I confirmed the 403 with curl, but `elm_make.out` shows a missing-dependency error, not the 403 |

## Independent re-derivations
- **Option C unsound on `list<int>`**: my own program (`type Ints = list<int>`, `Q(Ints n) -> :ints`) is refused on stock and proto, accepted on proto2; `[1,2]`, `[1,:x]`, `[]` give `:ints`, `[:x,1]` gives `:other`. Confirmed. It is an artefact of the prototype lacking `part_test` gating, as the brief says. Stock does reject `Sum([1, :x])` for a `list<int>` parameter, so the type system is sound where the guard is not.
- **Record prefix vs `type_test` depth**: stock `H(A a)` matches `{Kind=:'K1.A'}` with no `Id`, and with `Id = :x`; proto2 gives `:other` for the missing-`Id` map. Confirmed. No stored probe has the stock half; I produced it.
- **Counts**: 28 example modules and 0 warnings; 37 gates (see flag 4); 4 eunit tests for 3b. All re-counted.
- **3c full-suite run**: section 5 labels it "the subset, not the 1508". Section 9's "0 for 3c" drops that qualifier.

## Citations checked (all hold unless noted)
`bs_diag.erl:562`, `:1896`, `:1167`, `:2230`; `bs_check.erl:1860-1876` (raises 1874/1876); `bs_emit.erl:543`, `:465`, `:590`, `type_test/3` at `:1269`; `bs_check.erl:4924`, `:5095` (the raise is 5096), `:4690`, seven warning sites `3941/3943/3945/4025/4785-4787`; `bs_parser.yrl:508`; `LANGUAGE.md:1159` and `:2085`; F37 line 222; ticket 89 A2 and A8 (A8 removes `type_prefix_nested`); ticket 84 lines 146 and 220; ticket 85 line 80; ticket 66 line 92 (`bs_diag.erl:952` stale, as the brief says); ticket 09 line 144; ticket 12 lines 96 and 132; CONTEXT.md lines 56, 294, 297; ssl `tls_dtls_client_connection.erl:146-150`; `beam_types.erl:63-66`; residual fixture `RecordUnion`.

Imprecise:
- `bs_check.erl:3939` is cited for `map_arm_deferred`; the call is at 3933 and its comment at 3934-3935 (3939 is `false ->`).
- The sentence "85 says if either is answered as a rule about names, the other is inside it" is ticket 66's line 145. Ticket 85 line 74 says the equivalent ("66 is inside that rule and should be resolved with it").

## Stated as measured, no stored probe
- "Under `A a` it matches" (I reproduced it; not stored).
- "No gate reads severity" (not measured; see flag 4).
- "0 added" for 3c over the whole suite (inferred from the subset).
- The Elm 403 (I reproduced it; not stored).
