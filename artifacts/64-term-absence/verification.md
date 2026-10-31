# Independent verification: artifacts/64-term-absence

Verifier run 2026-10-30. Probes were copied to a fresh `/tmp/v64/probes` and run there with their
documented commands. The brief and probes were not edited. Mutations were made only in
`/tmp/v64/mut`. `bsc`, gleam and elm are absent, so no B# claim was executed by anyone.

## 1. Re-run against saved outputs

Exit codes: all nine probe commands exited 0, and every assertion line printed `holds`.

| Probe | Fresh vs saved `.out` |
|---|---|
| p1, p2, p2b, p3, p4_check, p5, p6 | byte-identical |
| p4 dialyzer | identical except the `done in` timings. I rebuilt the PLT from scratch. It prints one warning, `p4_spec.erl:21:9 {'error',_} can never match {'ok',_}`, which is the `use_tagged` dead clause. `use_untagged` gets none. |
| p7 | instruction counts (205 vs 225) and beam bytes (1912 vs 2056) are identical. The timing line differs, as expected: ratio 1.02 fresh vs 1.12 saved. |
| p8 | timings differ; the sign of the asserted ratio is the same (1.73 fresh vs 1.47 saved). |

## 2. Per-probe verdict

- **p1 PASS.** The assertions compare two observed results, and the only literal is `=:= error`, which is a documented fact about `maps:find`.
  - Mutation: `StoredN` set to `other` -> `maps:get` absent==stored goes FAILS and exit 1.
  - Mutation: `find(k, StoredE)` replaced by `find(k, Absent)` -> FAILS and exit 1.
  - No try/catch, no fallback.
- **p2 PASS.** Same structure. Mutation: `nil_v = %{k: 1}` -> two FAILS lines and exit 1.
- **p2b PASS, but the assertion is weak.**
  - It passes if the Map.get/3 doc contains "nil" OR "default". Any `Map.get` doc contains "default".
  - With the "nil" clause removed it still holds.
  - It only goes red if both words are replaced by strings that are absent, which I confirmed.
  - The printed doc text, not the assertion, is what supports the claim ("If `default` is not provided, `nil` is used"; `Map.fetch` returns `{:ok, v}` or `:error`).
  - Not circular, but a near-vacuous control.
- **p3 PASS as a calculation. Partially CIRCULAR as an assertion.**
  - The exit code asserts only "at least one row has absorbed=true and cofinite=false".
  - It does NOT check `absorbed` against F31's expected S-verdicts.
  - Mutation: `Absorbed = true` for every row -> still exit 0 and "REFUTED by 10 row(s)". The mutation survives.
  - Mutations that break the other halves do go red: `Absorbed = false` (exit 1), `Cofinite = always true` (exit 1), and `t_is_subtype(T,F)` swapped (exit 1).
  - So the claim "reproduces F31 S3/S4/S5/S6/S7/S8/S10" rests on eyeballing the printed table.
  - I did eyeball it, and all of S1 to S8 and S10 agree with F31's table (F31 lines 175-190). S9 and S11 are not modelled.
  - Faithfulness to ticket 68's `M ⊆ union(others)`:
    - The probe tests only `F ⊆ T` for a hand-built two-member union.
    - The real rule (`each_member`, `bs_check.erl:1202-1216`) tests each written member against the union of all the others, and 68 Q5 extends it to nested positions.
    - For every row in the probe the two coincide: `option<option<int>>` has `nothing ⊆ int|nothing`, and the nested result has `(:error,_) ⊆ int|(:error,_)`.
    - Not modelled: `T ⊆ F`, three-or-more-member unions, and the nested-position walk.
  - "4 of 8 refused rows missed by a cofinite rule" is arithmetically correct for the probe's row set: 8 rows have absorbed=true and 4 have no cofinite atom top.
    - It is not an independent finding. F31 line 186-189 already says a cofinite check "passes S3 and S5 and fails S4 and S8", so 2 of the 4 were known.
    - The other 2 (`result<tuple,atom>` and the nested result) are rows the probe author chose.
    - The rule being "refuted" is a strawman, since a rule that looks only at atom tops cannot see a tuple failure member.
    - The conclusion "C must key on `absorbed(nothing, V)`" is trivially true and does not need the probe.
  - The brief itself says the probe is not B#'s algebra, and it is honest about that.
- **p4 PASS.** The check script reads the saved `.out`, not a live run. If `run.sh` is not re-run, the check can go stale.
  - Mutation: tagged spec weakened to `term() | absent` -> dialyzer is silent, check prints `0 ; 0`, ASSERT FAILS, exit 1.
  - Mutation: untagged spec narrowed to `{ok,term()} | nothing` -> check prints `1 ; 1`, ASSERT FAILS, exit 1.
  - The control is fair: both `use_*` functions contain the same `{error,_}` clause.
  - Dialyzer warnings read directly: one warning, on line 21, in `use_tagged`.
  - The claim that `term() | nothing` is `any()` was not inspected directly. The zero warnings are consistent with it.
- **p5 PASS, but descriptive.**
  - The "untagged" functions are hand-written to conflate; the brief says so. The probe shows that conflating code conflates, not that B# would emit it.
  - It is not hard-coded. Mutation 1: `retry => 1` -> `untagged option misreads` goes empty and ASSERT FAILS (exit 1). Mutation 2: `tagged/2` reimplemented with `maps:get(...,nothing)` -> `tagged misreads: [retry]` and FAILS (exit 1).
  - Output matches the brief: retry misread as absent, upstream misread as failure, Has+Get and tagged misread zero.
- **p6 PASS.** Mutation: `{ok,V,V}` -> ASSERT FAILS and exit 1.
  - Delta is 3 words in every row. `{some,V}` equals `{ok,V}`.
  - "A miss allocates nothing" is NOT measured by p6. It is inferred (the atom row shows bare=0). The brief lists it under "Measured evidence".
- **p7 PASS for counts, and the timing is inconclusive, as the brief says.**
  - The assertion is weak: `tagged >= bare`. With both modules generated identically it still passes (205=205, exit 0).
  - The counts are therefore real output, but the check cannot fail on a "no difference" outcome.
  - The 144-byte delta includes a few bytes from the module names (`p7_bare` vs `p7_tagged`); the identical-code mutation still shows 1912 vs 1916.
  - Spread of the median ratio over 7 runs (saved, fresh, then 5 reruns): 1.12, 1.02, 1.07, 1.18, 1.15, 1.17, 0.98. The range is 0.98 to 1.18, so the sign flips. The brief's "inconclusive" is correct.
- **p8 PASS.** The assertion is only `ratio > 1.0`.
  - Large-hit `is_key+get / find` over 7 runs (saved, fresh, 5 reruns): 1.47, 1.73, 1.48, 1.87, 1.47, 1.39, 1.50. Median 1.48, range 1.39 to 1.87.
  - The brief's "1.47x" is a single draw. The direction is stable; the magnitude is ±20%.
  - "Miss within noise" is consistent: saved 15275 vs 18164, fresh 19230 vs 17929, so the direction flips.
  - I did not mutate p8's assertion (it is a plain `>`).

No probe contains a swallowed failure, a printed-regardless result, or a patched-in expected value.
The weak controls are p2b, p3 (the exit code does not test the verdicts), p7 (`>=`) and p8 (`> 1.0`).

## 3. Claims table and citations

Checked and correct:
- `bs_check.erl:1202-1216` (`collapse_members` / `each_member`, raising `absorbed_member`).
- `bs_check.erl:3265` (`validated`, the `ValidateAs` obligation) and `3410-3415` (`validate_collapses` / `absorbed`).
- `bs_check.erl:1763` (`sought_row`, `Map.Has` present).
- Ticket 108 decisions entry at lines 160-175 (`Map.Get` crashes, `Map.?Get` returns `:nothing`, "Return types unchanged: `option<T>` for a lookup").
- 108:155, 96:99 (Q3), 96:224 (`Map.Find -> option<V>`), 98:71 (`Agent.Get(a, m => Map.Find(m, k))`).
- F75 lines 119 and 181; F31 S1 to S11 table and the 2026-10-08 amendment at F31 lines 160-165.
- `maps.erl:285-293` and `60-63`, `proplists.erl:194-230`, `dict.erl:139-142`.

**Finding (a): Q3 wording.** Ticket 64 Q3 says `result<T, E>` "at `E = term`", and its own table lists `FindR result<term, atom>` as COLLAPSED, so the collapse is at `T = term`. The brief's p3 and p5 results back its answer on both readings (`result<int,term>` and `result<atom,term>` survive; `result<term,E>` collapses). It is a fair reading, but "wrong premise" is slightly strong. Q3 only asks whether the reasoning reaches `E = term`, and that question gets a real answer ("no, not by itself").

**Finding (b): `Map.?Get` / `option<V>` against the F31 refusal.** I confirmed it from the tickets and code.
- Ticket 108 fixes `option<T>` as the lookup return type.
- F31 S5 and S7 refuse a written `option<term>` and `result<term,E>`.
- `collapse_decl` / `collapse_ty` (`bs_check.erl:1105-1163`) run only on written declarations: signatures, aliases, records, foreign and `implements`. `as_pasted` at 2390 reuses them for pasted signatures. I found no call-site or instantiation check.
- Nothing in `wayfinder/issues/` (excluding 64) addresses `GetOr` or ENG-254 for the row.
- Caveat on the brief's wording: its item 1 says the decided `Map.?Get` "has no legal return type" at `V = term`. Its own item 5 says the absence of a call-site check means the row would silently re-collapse rather than be refused. These two are in tension.
  - What is established is that a user-written `option<term>` is refused (F31 S5).
  - What is not established is what `Map.?Get(m, k)` yields at `V = term`. Both are source-read and unexecuted.

## 4. Misstated or unsupported claims

1. **"F36 S5" and "F36 S7" (brief lines 23, 85, 262).** These scenario ids are F31's (`F31-collapse-at-the-declaration.md:175-190`). F36 (`F36-an-absorbed-member.md`) has no S5 or S7 table. The claims table cites F31 correctly. Section 0 and the options text use the wrong feature number.
2. **"Measured evidence" under B includes "A miss allocates nothing".** p6 does not measure a miss. It is an inference.
3. **p8 "1.47x" is presented as a figure.** The 7-run range is 1.39 to 1.87. The brief says "noisy", but the headline is one sample.
4. **p3 "reproduces F31's verdicts (all agree)".** True on inspection, but no probe assertion enforces it (see the p3 mutation above).
5. **Option A's REFUSED example text.** The error text and the `Map.Has` hint are invented, and they would arise only from the new call-site check that "Compiler must gain" lists. In the example as written, the refusal would come from the author's own `option<term>` return, not from `Map.?Get`. Not false, but not a demonstration.
6. **"The Elm `Dict.get` returns `Maybe`" and "Gleam `dict.get` returns `Result`".** The brief marks both UNPROBED. The Gleam line is backed by `research/48:151,211` and ticket 48:86, which I read. The Elm line has no local source.

No number in brief.md disagrees with the saved probe outputs: 3 heap words, 28 to 31, 205/225, 1912/2056/144, 1.47, and the 4-of-8 list all match. The fresh runs reproduce all of them except the p7 and p8 timings.

## 5. Overall verdict

The probes are honest and reproducible. The deterministic ones (p1, p2, p2b, p4, p5, p6 and the p7 counts) reproduce exactly and respond to mutation. The brief flags the timing probes as noisy, and my 7-run spreads support that (p7 straddles 1.0; p8 stays above 1.0 at 1.39 to 1.87).

The real weaknesses are structural:
- p3 is a re-derivation on a different algebra, and its exit code does not test the verdicts it is cited for. The "4 of 8" result is a count over author-chosen rows against a strawman rule that F31 already refutes on two of those rows.
- All B#-level claims, including the central "`Map.?Get` collides with the refusal", rest on source reading and tickets. They are labelled UNPROBED or INHERITED, which is accurate.
- The F36/F31 scenario mislabel is the only citation error I found.
