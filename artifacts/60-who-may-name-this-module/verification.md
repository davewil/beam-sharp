# Verification of brief.md (ticket 60 / ENG-242)

Independent re-run. Probes copied to scratchpad (xref temp dirs redirected), all six re-run on OTP 25 / Elixir 1.14.0, outputs diffed
against the checked-in `.out`. bsc not run; every bsc statement below is SOURCE or RECORDED.
Repo HEAD is now `33e859a` (brief says `f528593`; the two commits since are artifact-only, so no source drift).

## 1. Probe re-runs

| Probe | Runs | Fresh vs checked-in `.out` | Verdict |
|---|---|---|---|
| erl_caller_restriction | yes | Identical except xref timings (3.0 -> 2.8 ms load, 8.9 -> 4.4 ms first query; 51.4 -> 50.4 ms load at 301, 2.4 -> 2.6 ms query) and a temp path in a "Skipping m0.beam" line | CONFIRMED (qualitative); figures see 2 |
| ex_probe | yes | Identical except the unique module id `W100`/`W34` | CONFIRMED |
| prefix_rule | yes | Byte-identical | CONFIRMED as a property of string prefixes; CIRCULAR as evidence (below) |
| mix_xref_probe | yes | Byte-identical | CONFIRMED-WITH-CAVEAT |
| elm_probe | yes | Byte-identical (proxy 403) | CONFIRMED (no Elm claim made) |
| cost | yes | Shapes reproduce (flat map/prefix; linear member). Absolute numbers move 5-15%, and naive N-roots at 100k moved 27.5 -> 29.9 ms | CONFIRMED-WITH-CAVEAT |

## 2. Brief figures vs the final `.out` (the author warned they may differ; several do, beyond noise)

| Brief says | Final `.out` (author / my re-run) | Verdict |
|---|---|---|
| xref 2.5 ms load + 6.6 ms first query (3 mods) | 3.06 / 8.93 ms; mine 2.8 / 4.4 | brief matches neither .out; 4.4-8.9 ms query spread is 2x, so state "3-9 ms" |
| xref 40.9 ms load + 2.7 ms query (301 mods) | 51.4 / 2.4 ms; mine 50.4 / 2.6 | brief 20% low on load; fix to about 50 ms |
| `lists:member` miss 0.036 us at N=10 | 0.0188; mine 0.0187 | brief is 2x high; fix to 0.019 |
| `lists:member` miss 1.9 us at N=1k | 2.13; mine 1.79 | in noise |
| `lists:member` miss 203 us at N=100k | 204.3; mine 188 | in noise |
| naive "under any of N roots" 18 ms at N=100k | 27.5 ms; mine 29.9 ms | brief is wrong (1.5x low), matches no run. Fix to about 28 ms |
| `is_key` 0.014-0.030 us | 0.0145-0.035 (miss at 100k is 0.035) | fix to 0.014-0.035 |
| prefix test 0.12-0.27 us | 0.117-0.255; mine 0.116-0.26 | OK |
| sweep 0.2-0.5 us/edge | 0.200 / 0.216 / 0.595; mine 0.466 | upper bound should read 0.6 |
| compile:file 4.7 ms | 3.93 ms; mine 3.64 | brief high by 20%; say about 4 ms |
| "predicted about 1 ms, measured 0.2 ms" (member miss at 100k) | prediction header says about 1 ms; .out 0.204 ms | CONFIRMED |

None of these changes a conclusion (all are orders of magnitude below the compile). But the brief presents figures as MEASURED with `.out`
named, and several do not match the named file. Correct them or say "rounded from an earlier run".

## 3. Circularity hunt

1. **prefix_rule.escript: a tautology as to the headline.** `naive/2` is `lists:prefix(atom_to_list(R), atom_to_list(C))` with no dot
   boundary, and the caller list contains `Shop.ReportsV2`, chosen for this. That a dotless string prefix admits `ReportsV2` is true by
   inspection of the definition. It demonstrates the trap exists; it tests no rule that anyone proposed. The brief's own label ("probe
   of the proposed rule, not of bsc") is honest, but "MEASURED" overstates it, and item 7 of Option 1 (a `--self-test` that builds
   ReportsV2) is the actual test. It is a legitimate illustration, not evidence.
   - `dirp/2` is not a directory-path test. It splits the same atom on "." and never touches a path. The header prediction
     ("deriving R from a directory path via F15's dir<->dotted-name agrees ... a Windows-style or trailing-slash path would need
     normalising") is not exercised; no path, slash or F15 code is involved. "Segment-list forms refuse it" is true, but `seg` and `dirp`
     agree by construction (same tokenisation).
   - The `children/2` line reprints a copy of bs_check.erl:573-575 that the author re-typed, not the compiled function. It matches the
     source (I checked the lines), so it is fine but is a copy.
   - **"A namespace emits no atom, so no world key `'Shop'`": the MEASURED half is circular.** `World` is a hand-built map containing only
     `'Shop.Reports'` and `'Shop.Billing'`; `is_key('Shop', World)` is false because the fixture omits it. The same goes for the
     "typo root fails closed" line (the world has no `Shp.*` by construction). Only the RECORDED half (F15 lines 39, 102) counts, and it
     does say this. Downgrade the label to RECORDED plus SOURCE (bs_check.erl:487-490 shows namespaces handled by `children/2` when
     `is_key` fails).
2. **xref query "fix": not a patch to reach the expected result.** Prediction 3 already says "outsider -> shop_orders:recompute_total/1
   edge" (edges INTO the module); the final query `E || shop_orders : Mod` returns exactly that, from real beams, and the outsider edge
   is not present in any fixture text except as a real call. The `|` vs `||` slip is disclosed in the header, and the prediction text was
   not tuned. I cannot see the abandoned first draft (it was overwritten), so "before any conclusion" is unverifiable, but nothing shows
   tuning. CONFIRMED-WITH-CAVEAT. Small issue: the 301-module set is compiled with m0 lacking debug_info (xref prints "Skipping m0.beam"),
   yet the query still reports m1 -> m0; harmless, but the brief should not call these "whole beams" without noting m0 was skipped.
3. **Fixtures built to contain the answer, mildly.** `shop_orders` is written to export `recompute_total/1`, so "-export is
   all-or-nothing, an unrelated module can call it" is definitional Erlang; the value of the probe is only in the negative results for
   `-nifs`, `-on_load` and inline (2b-2d), which are genuinely triggered. 2d shows `attributes = []`, so `-nifs` and `-on_load` do not
   even persist, which the brief does not need.
4. **Failures simulated rather than triggered: none found.** Elixir `defp` cross-module (2a/2b) is genuinely triggered through
   `Code.compile_string`. Note that the `.out` labels two different lines "2b" (the `__info__` line and the run line); the brief cites
   "2a, 2b" and means the latter. Ambiguous, not wrong. For 3, the brief's "header lines" is vague; the evidence is the stderr warning at
   the top of the file plus 3 and 3b.
5. **Cost probes measure what is claimed, with caveats.** `lists:member` is timed on a miss (worst case) and separately on a hit at the
   last element (also worst case); the brief correctly says "miss". Neither timing is a "typical" case, and the brief's sentence that
   friend lists are 1-10 names is an assumption, not a measurement. The reps loop includes a fun call per iteration, so the 0.014 us
   `is_key` figures are dominated by loop and closure overhead; the flat-vs-linear shape is real, the absolute nanoseconds are not for
   `is_key`. Sweep comment says "3 imports each" but the code builds one edge each (stale comment; the per-edge figure is right for
   one). The sweep's `maps:is_key(C, Map) andalso under(...)` is always true, so both operations do run. "Prediction miss" claims are
   consistent with headers (the headers precede results in file order; I cannot prove write time, and the file mtimes for the escript
   sources are 23:09-23:12 versus `.out` at 23:14, consistent with predictions-first).
6. **mix xref caveat.** Both `Shop.Reports` and `Outsider` are in the same `reports.ex`, so the output `lib/reports.ex (runtime)` cannot
   distinguish modules at all. It supports "file granularity" only in the weak sense that the tool cannot tell them apart here; a
   separate-file fixture is not run, so it does not show whether callers in separate files are separately listed (they surely are). The
   brief's parenthesis "Outsider ... appeared only as that file" is accurate but makes the conclusion trivial.

## 4. Label discipline

SOURCE citations opened (`compiler/src`):

| Citation | Result |
|---|---|
| bs_check.erl:4037-4046, quoted as "those entries declare the file's dependencies" | **Off by 3 lines.** The quote is in the comment at 4034-4035; 4037-4046 is `qualified_module` and the start of `require_imported`, which does prove `using` is required (`module_not_imported`). Substance CONFIRMED, cite imprecise |
| bs_check.erl:472-486 (import_env/add_import, tables reachable only via using) | CONFIRMED. `import_env` builds funs/mods/types/qual/polys/privates from imports |
| bs_check.erl:573-575 `children/2` with `Prefix ++ "."` | CONFIRMED |
| bs_check.erl:495-508 add_module_import arity 3, reads exports and types | CONFIRMED (`maps:get(exports, Entry)`, `maps:get(types, Entry, #{})`); `Acc` also gets `imported` |
| bs_check.erl:484-502 (add_import has Self, L) | CONFIRMED |
| bs_check.erl:510-517 add_namespace_import | CONFIRMED |
| "bs_check.erl:307, 253-257 Self = module_name(Decls)" | 253-257 CONFIRMED; **307 is a comment; the assignment is line 308** (also 353). Off by one |
| bs_check.erl:214-224 module_matches_path | CONFIRMED |
| bsc.erl:227-239 world entry map | CONFIRMED (exports, polys, private, behaviours, types, and also `implements`, which the brief's "..." covers) |
| bsc.erl:478 / 814 Expect from directory | CONFIRMED (`expected_module`, `expect`) |
| bs_diag.erl:1233-1238 `private_function` message | CONFIRMED; the brief's "near :338" `built/2` clause is at :338 |
| bs_parser.yrl:180 `using_decl` | CONFIRMED |
| bs_check.erl:253-257 "defaults 'Main'" and REPL claim | CONFIRMED for `module_name`; "ibs ... would be refused" is correctly labelled UNVERIFIED |

RECORDED citations:

| Claim | Result |
|---|---|
| Ticket 24 lines 218-220 "every function ... exported today" | CONFIRMED (lines 218-221) |
| "24 resolved 08-13" | CONFIRMED (`Status: resolved 2026-08-13`); F12 done 2026-08-17 CONFIRMED |
| Ticket 24 does not name a test directory | CONFIRMED (grep finds no Tests/ rule) |
| 22 lines 431-435, "C# `internal` is assembly-scoped" | **Mis-cited.** 22 only says "a different feature from C#'s `internal`"; the word "assembly" appears only in ticket 60 (line 32). The brief cites both, so the claim is real, but the 22 line range does not carry it |
| 18 lines 439-440, 613 elision exported-vs-local | CONFIRMED |
| 18 §5 quote "whole-aggregate analysis would let an edit to one file silently move another file's emitted boundary" | Text exists (lines 435-437 and 837), **but it is about the emitter's guard analysis being function-local, not about naming rules.** Using it to argue a `friends` list in a callee's `index.bs` "is exactly that blast radius" is an analogy the source does not make. Present as the author's inference, not as a ticket support |
| "RECORDED 18 §5, 22" that BEAM cannot enforce per-function caller restriction | Supported by 18 (one entry label) and ticket 60's own text (line 38-40); "22" cites ticket 06 for "no way to publish a function to your own compiler". Fine, but the enforcement conclusion ("must be a compile-time caller check") is ticket 60's, not measured |
| F12 "Out of scope: `protected`, `internal`, or any third level" | CONFIRMED (F12 line 185) |
| F12 AMENDED (private default) and F12.4 refusal | CONFIRMED (lines 11, 149) |
| F15 namespace emits no atom; index.bs holds using/type/record/behaviour | CONFIRMED (F15 lines 31, 39, 102) |

Unlabelled or beyond evidence:

1. **"the 32 `.bs` files"**: REFUTED. There are 73 `.bs` under `compiler/examples` (46 under `exemplars/`), 160 in the repo. Fix or delete the
   number. The missing-evidence corpus search is therefore larger than the brief thinks.
2. "Only a callee-side (or third-party architecture file) declaration can refuse a caller" and "(b) and (c) are close to forced": argued,
   not evidenced, and the third-party architecture file is never developed. Fine as design reasoning; note it is unlabelled.
3. "`friend` ... means an explicit list in C++": unlabelled outside knowledge (brief admits "not probed").
4. "in the emitter/typing tables are only reachable through it": SOURCE 472-486 supports the typing tables; the emitter part is not read.
5. Gleam, Elm: correctly not claimed. C# `internal`: only RECORDED via ticket 60. No unsupported Gleam `@internal` claim found.
   The recommendation to not spell it `internal` is a naming preference, not evidence.
6. "Elixir 1.14: unknown attribute ... is not persisted" is supported by 3b (`[]`), fine. "Elixir has no such mechanism" is correctly
   softened to a name grep. Note the grep list includes no "protected"/"private"/"only" (weakly chosen search terms).
7. The Option 3 claim "refused today with the quoted wording" rests on F12.4 plus bs_diag, both read; bsc was not run, as disclosed.
8. "Measured cost ... 0.5 us/edge for a 100k-module world sweep" is a synthetic Erlang loop, not bsc. The brief does say "one prefix test per
   `using` line"; the leap to "checker cost is not a deciding axis" is reasonable but is not a bsc measurement and should say so.

## 5. Drift claims

| Claim | Verdict |
|---|---|
| Ticket 24 §2 "every function exported" superseded by F12 | CONFIRMED. 24 line 218-221 versus F12 line 74/107 (amended default private). Ticket 24 also says it "goes to ticket 22 unresolved", so the consumer is stale for the reason the brief gives |
| Ticket 60 cites `add_module_import/5` at `bs_check.erl:407-425`; at HEAD it is arity 3 at 495-508 | CONFIRMED |
| "arity 3 becomes 5, coincidentally the ticket's /5" | Fair: arity 3 plus `Self` plus `L` is 5 |
| F12 lists a third visibility level out of scope | CONFIRMED (F12 line 185) |

## 6. Verdicts by brief item

| Item | Verdict |
|---|---|
| Erlang `-export` all-or-nothing; -nifs/-on_load/inline restrict nobody | CONFIRMED (partly definitional) |
| OTP xref reports callers, enforces nothing | CONFIRMED |
| xref cost numbers | CONFIRMED-WITH-CAVEAT (figures do not match .out; see 2) |
| Elixir `@doc false`, `@moduledoc false`, nested module, `@visible_to`, `no_warn_undefined`, `defp` warning | CONFIRMED |
| Elixir exports no friend/internal-style names | CONFIRMED-WITH-CAVEAT (name grep only, stated) |
| `mix xref callers` file granularity | CONFIRMED-WITH-CAVEAT (same-file fixture) |
| `mix help xref` option list, Elixir beams only, Elm 403 | CONFIRMED |
| Prefix rule: naive admits ReportsV2 | CONFIRMED-WITH-CAVEAT (tautology; not a test of a proposal) |
| "namespace has no world key" MEASURED half | REFUTED as evidence (hand-built world); RECORDED half holds |
| Per-check and sweep cost figures | CONFIRMED-WITH-CAVEAT (shapes yes; several quoted numbers wrong) |
| "18 ms naive at N=100k" | REFUTED (27.5 ms in .out) |
| "4.7 ms compile" | REFUTED against .out (3.9 ms); within noise-ish of a warm-up-inclusive run |
| SOURCE citations | CONFIRMED with two line errors (4037-4046 quote; 307 vs 308) |
| C# assembly claim RECORDED to 22:431-435 | CONFIRMED-WITH-CAVEAT (in ticket 60, not those lines of 22) |
| 18 §5 blast-radius quote as support for the Option 2 counterargument | CONFIRMED-WITH-CAVEAT (quote real, application is the author's) |
| "32 .bs files" | REFUTED (73 in compiler/examples, 160 in repo) |
| Drift claims (24 vs F12; arity 3/495-508; F12 third level) | CONFIRMED |
| Prediction-miss disclosures | CONFIRMED (Elixir defp warning vs predicted refusal; member miss 1 ms vs 0.2 ms; `|` slip) |

## 7. Overall verdict

**Not as-is. Send after a short correction pass; no conclusion changes.** Required corrections:

1. Replace the mismatched figures in the evidence table with the final `.out` values (xref 3.1/8.9 and 51/2.4 ms; member miss at N=10
   0.019 us; naive N-roots 28 ms, not 18; compile about 4 ms; sweep up to 0.6 us/edge; is_key up to 0.035), or add "timings vary 5-100% run
   to run; rounded". Say the xref first-query time varies 4-9 ms.
2. Delete or fix "the 32 `.bs` files" (73 under compiler/examples, 46 of them exemplars).
3. Relabel "no world key 'Shop'" and "typo root fails closed": hand-built world, so RECORDED/SOURCE only. Relabel the ReportsV2 row as
   "illustration of a definitional property", and drop the implication that the directory-path form was tested (`dirp` never touches a path).
4. Fix cites: bs_check.erl:4034-4035 for the quoted comment (4037-4046 for the behaviour); `Self` assignment is line 308; the C#
   assembly statement is ticket 60 line 32, not ticket 22:431-435.
5. Mark the 18 §5 "blast radius" argument as the author's analogy (that passage is about guard-analysis locality).
6. Note in the xref row that m0 was skipped ("no debug information") and that the mix xref fixture puts both callers in one file.

Uncorrected but acceptable: all bsc behaviour is honestly labelled SOURCE/RECORDED; Gleam and Elm are honestly not claimed; the
recommendation logic ((e) gates the rest) does not depend on any refuted item.
