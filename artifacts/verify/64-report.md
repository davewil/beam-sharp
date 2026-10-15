# Verification of brief 64 (option<term> / result<term,E> collapse)

Verifier reruns used a mktemp dir and `-o`. No saved .out, probe, brief, ticket or compiler/ file was touched. Own probes and output are in `artifacts/verify/64/`.

## 1. Probe reruns (exact listed commands, clean shell)
| probe | verdict |
|---|---|
| 64_collapse_table.sh | REPRODUCED (byte-identical) |
| 64_silent_routes.sh | REPRODUCED (byte-identical, incl. R2 runtime 0) |
| 64_tagged_shapes.sh | REPRODUCED |
| 64_cases.sh + 64_programs/* | REPRODUCED (incl. NAIVE both `:no_assign_or_logged_out`, BareWins/TaggedOption 2/2, counts 0 vs 1) |
| 64_untagged_vs_tagged.exs | REPRODUCED |
| 64_gleam.sh | REPRODUCED (github reachable) |
| 64_neighbour_sources.sh | REPRODUCED (Elm clone also worked, source lines print) |
| 64_repr_cost.escript | REPRODUCED for all sizes (exact). Timing differs in noise: get/3 min 28.1 vs 27.1; find-based mins 36-49 vs 36. Direction reproduces (get/3 has the lowest min). Medians (41.6/54.1/71.4/77.3 vs 33/37/44/47) are load noise and order differently, as the brief warns. |

## 2. Circularity review
No probe is built on a patched compiler copy. B's `Found<T>` is a user alias on stock HEAD. There is nothing to diff against stock. No CIRCULAR probe found: expected strings are not self-echoed, and every table has differing controls (ACCEPT/REFUSE mix, `option<int>`, T=int, R3b, R5, G1).

Weaknesses, none fatal:
- F6 (AssignsBRaw crash) is weaker than it reads. The probe declares a foreign signature that lies about `maps:find`, so the crash proves "do not mis-declare OTP's `error`", not a property of the design. The conclusion (spell the absent as `:error`, or adapt) still follows.
- F5's AssignsNaive picks `:nothing` as the sentinel by construction. It shows the harm only for a sentinel inside the value domain, which the brief says itself, with JsonDefault as the counter-case.
- F3 R2 "Use(:nothing) prints 0" is just the semantics of an untagged option. The real finding is the missing diagnostic, which does reproduce.
- F10's wrapper counts are `grep -c` on a single-clause toy, so 0 vs 1 is nearly trivial. The word-cost table is the real evidence.
- HeadersOpt hand-writes `Header`. It does not exercise `Map.?Get`, which is unbuilt. The brief admits this.
- The perf paragraph's ranges ("27-31 ms in 6 of 7 runs") rest on unsaved runs. This rerun is consistent with it.

## 3. Citations
All confirmed except these:
- `STANDARD-ENVIRONMENT.md:115` ToExistingAtom returns `result<atom, string>`: OK (repo root).
- bs_check.erl: `absorbed/2` at 3282 OK; `each_member` is defined at 1196, the comment is at 1195 (off by one); `stratum_one` 1338 OK; `reserved_arities` 1752 OK; the 1717-1744 reserved_sig range OK, and `List.Map` is at 1728. bs_emit.erl:2112 `otp_args({'List',...})` OK.
- `exemplars/25g-jev-server/triage_index.bs:42` and `triage_crash.bs:21` say what is quoted, but the real path is `compiler/examples/exemplars/25g-jev-server/` (abbreviated in the brief).
- Ticket 48 lines 1028-1031 OK. Ticket 108 "Return types unchanged" is at line 177. `grep 'ENG-254|ticket 64'` over 96/97/108 finds nothing: confirmed. No PRELUDE.md in the tree: confirmed.
- Erlang `maps.erl:138` and `:686-692`, and Elixir `map.ex:298-299,317,526`, are in nix-store paths that still exist. Gleam and Elm files are covered by the neighbour_sources rerun.
- "18 option<...> uses, 0 at term": `grep -c option<` over compiler/examples gives 18 LINES. About 7 of those are comments, so code uses are about 11 across 10 files. The "0 at term" claim holds either way. Brief option C says "19 corpus sites", which is inconsistent with the 18.
- Measurements table: `erts_debug:size` and `term_to_binary` numbers match exactly on rerun (all 6 rows x 3 columns, flat_size too).

## 4. Own extra probes (artifacts/verify/64/v64_generic_leaks.sh, v64_extra.sh; .out beside)
The recommendation leans hardest on "F3 is a separate hole whose check makes the refusal loud".
- **F3 is wider than measured.** The brief measured only `option<T> Wrap<T>`.
  - `result<T, atom> Wrap<T>(T)` called at T=term is also accepted with no diagnostic. `Use((:error,:x))` reads as error (0), while `Use(5)` gives 1.
  - `option<T> Wrap<T>` at T=atom is also silent (`Use(:nothing)` gives 0).
  - So the F3 check must cover `result` and every absorbing T, not just term. The brief's wording ("option<T>/result<T,E>") anticipates this, but F3 never measured it.
- **Generic records are not in the language yet.** `record Box<T>` is a syntax error. Only the generic function route leaks, and there is no generic-record route to test.
- **Elixir cross-check of F2.** `int | {:error, term} == int` is false and `term | {:error, term} == term` is true, so E=term survives and T=term collapses. `Map.get(%{a: nil}, :a) == Map.get(%{}, :a)` is true, `Map.fetch` distinguishes them, and this independently supports the sibling-operation argument.

## 5. Gaps I did not close
Req header shape is unknown (the repo has no Req source; `51a-code-path/Req` only reads `__struct__`/`method`). Whether the F3 check can avoid false positives on generic code is untested. `Map.?Get` is unbuilt and the reserved_table has no `?` rows, so the "same hole" prediction is still a prediction.

## Bottom line
**YES WITH CORRECTIONS.** Every probe reproduces, none is circular, and there are no patched-compiler prototypes.
Corrections:
1. Fix the 25g path to `compiler/examples/exemplars/25g-jev-server/`.
2. The corpus count is 18 lines (about 11 code uses), and "19" in option C is inconsistent.
3. `each_member` is at line 1196.
4. F3 should state that the silent generic route also holds for `result<T,E>` and for T=atom (verified here).
5. F6 is an FFI mis-declaration, so present it as an adapter caution, not evidence against `:absent`.
