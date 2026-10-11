# Verification of the ticket 62 brief (independent re-run)

Verifier: independent agent, 2026-10-11. Work dir: `$S/verify62/` (probes copied there, paths re-pointed so nothing of the author's scratch was reused; my own scripts in `$S/verify62/mine/`).
Toolchain as in COMMON.md: OTP 29, Elixir 1.20.4 (compiled with OTP 27, confirmed by `elixir --version`), Gleam 1.19.1. `compiler/src` is unchanged between the cited rev `019533d` and HEAD `d8a3bd8`.

## Overall verdict: VERIFIED WITH CORRECTIONS

The headline is true and I reproduced it from scratch: Elixir calls `:Shop."New"(1)` and every spelling listed. Every probe reproduces. The corrections are about (a) the cost percentages being an artefact of one-line function bodies, which weakens the recommendation's Option B reasoning, (b) one false generalisation (the OTP census), (c) quoted timing numbers that are not in the committed `.out`, and (d) two vacuous "negative controls" plus one over-reaching claim about `import`.

## 1. Per-probe verdict

Fresh output diffed against the committed `.out`. Only path strings and timings differ unless stated.

| Probe | Result | Notes |
|---|---|---|
| 01 Elixir spellings | **reproduces** (byte-identical) | Also reproduced with my own script, see section 3. |
| 02 Gleam emission | reproduces | diff = scratch path and "Compiled in" time. |
| 03 Gleam calls B# | reproduces | diff = path, time. Negative controls red (`error undef` twice). Own Gleam project (section 3) agrees. |
| 04 erasure table | reproduces (identical) | |
| 05 alias cost | reproduces on bytes, exports and chunk sizes (beam sizes differ by +24 B from the committed file in every row, from debug-info paths, ratios unchanged). **Compile times differ run to run**, see 2c. | 36 s. |
| 06 runtime hop | reproduces qualitatively. Assembly output identical; timings differ (see 2d). | The brief's quoted medians are not in the committed `.out`. |
| 07 naming rules | reproduces (identical) | Escript re-implementation matches real `Macro.underscore` on all 17 of the author's names and on 15 of mine. |
| 08 record and Kind | reproduces (identical) | The "NEGATIVE CONTROL" in it is not a control (2e). |
| 09 option 2 from Elixir | reproduces (identical) | The "NEGATIVE: no alias built" line is vacuous (2e). The stock-compiler column is the real control and is red where it should be. |
| 10 OTP PascalCase census | reproduces the numbers (1321 beams, 46,001 exports, 19 hits) | **The brief's reading of it is wrong**, see 2a. |
| `macro_underscore_src` | reproduces (identical) | lines 2316 / 2331 confirmed as printed. |

## 2. Findings against the brief

### a. Mis-claim: "all 19 are in `diameter_types`" (brief section 3)
The probe prints only `lists:sublist(Hits, 12)`; the brief generalised from 12 of 19. With the full list (I removed the sublist): 14 in `diameter_types`, plus 5 in **wx**: `wxImage:'Destroy'/1`, `wxMenu:'Destroy'/2`, `wxRegion:'Xor'/2`, `wxRegion:'Xor'/5`, `wxWindow:'Destroy'/1`. The total (19 of 46,001) is right. Correction: say "diameter_types and wx", and fix probe 10 to print all hits.

### b. The cost percentages depend on the function body (affects recommendation reason 2)
The brief's generator uses `ComputeTotalK(n) -> n + K`. I regenerated N=1,10,50,200 with a realistic body (three guarded clauses returning atoms, arity 2), 15 timed compiles per cell after a warm-up, same patched compiler, `none` verified byte-identical to the stock compiler except the `CInf` chunk:

| N | mode | .beam | stripped | compile ms median (min-max) |
|---|---|---|---|---|
| 200 | none | 44752 | 7162 | 330 (301-370) |
| 200 | forward | 56176 (**+25.5%**) | 11109 (+55%) | 379 (356-468) (**+15%**) |
| 200 | dup | 65752 (+47%) | 13470 (+88%) | 663 (593-1158) (**+101%**) |
| 50 | forward | 14820 (+24%) | | 90 vs 77 (+18%) |
| 10 | forward | 3828 (+18%) | | 21.5 vs 20.8 (+3%, noise) |

- The marginal cost per aliased function is the same as the brief's (57 B forward: (56176-44752)/200 = 57.1), so the byte-per-alias claim stands. The **relative** growth ("about +50% beam, about +48% compile", used in section 6 reason 2 and Option B) is specific to one-line bodies. With realistic bodies, `forward` is about +25% beam and +15% compile; `dup` is about +47% and +100%. The brief's own caveat covers `dup` only; it should say the forward percentages also shrink.
- Stripped size was "not measured" in the brief. Measured: forward adds +55% to a stripped beam (the alias machinery is a larger share once debug_info is gone). Stripped beams are what production releases ship, so the brief's "about +50%" is closer to the truth for releases than for dev builds, the reverse of what a reader would assume.
- Compile-time percentages are unstable across reruns of the same probe: probe 05 forward at N=200 was 127 ms committed, **149 ms** in my rerun (+48% vs +76% over `none`); `dup` +75% vs +91%. The in-VM spread is wide enough that the brief's "about 48%" should be given as a range.

### c. Byte-size and export numbers: confirmed
All quoted .beam sizes, export counts (203/403), ExpT, Code +58%, AtU8 +108%, ExpT +98%, 57 B/67 B per function, forward_nospec saving 1.9% recompute correctly from the output.

### d. Timing (probe 06): conclusion holds; quoted numbers and spread are misreported
- The brief's quoted medians (1e7: 105162 / 108023 us, 0.29 ns; 5e7: 532836 / 541822 us, 0.18 ns) **do not appear in the committed `probes/06_runtime_hop.out`**, which has 111790 / 112651 (0.09 ns) and 563003 / 582620 (0.39 ns). The brief quotes an earlier run, so the "(captured `.out` beside each)" claim is not true for these figures. My fresh run: 105864 / 106610 (0.07 ns) and 633266 / 607115 (**-0.52 ns**).
- Spread claim: "min-to-max of a single configuration is 3-15%" and "difference about -0.2 to +0.4 ns". Committed and fresh `.out` show min-max up to 40% at 5e7 (550680-771918 us), and a difference of -0.52 ns in my fresh run. In my own 6 repetitions (9 interleaved reps each, 2e7 calls) the alias-minus-Pascal difference was: -0.39, -0.01, 0.04, 0.37, 0.39, 0.40 ns/call, so min -0.39, median 0.20, max 0.40; single-configuration min-max reached 38%.
- Sensitivity of the positive control: the `phash2` BIF control (+8 to +10 ns) is far larger than anything under test, so it does not show the probe can see a hop-sized cost. I added genuine extra hops (`hop2.erl`, three runs of 9 reps, 2e7 calls): an extra tail-call forwarder costs about **+0.5 ns/call (-0.2 to +0.8)** and a non-tail forwarder with a frame **+1.1 to +1.8 ns/call**. So the claim "not distinguishable from zero" is true, but a real hop of this kind costs roughly the probe's resolution; the honest statement is "below about 1 ns/call, indistinguishable". Conclusion for the recommendation is unaffected.
- Not circular: the asm dump (`call_only`) is read from `compile:file` output; timing loops call the two different exports; the negative control moves the number.

### e. Weak or vacuous controls
- Probe 09 "NEGATIVE: no alias built": `:Abi.NoSuchAlias(1)` is a parse error (capital after the dot), so it is a `SyntaxError` under either compiler and tests nothing about aliases. The real control (stock compiler) is fine and was seen red.
- Probe 08 "NEGATIVE CONTROL: right tag, missing Total" is not a control; it is a finding (accepted, returns `:order`). It is correctly reported as a finding in the brief, but labelled a control in the probe.
- Probe 01 T6 (`import(:Shop, only: ["New": 1]); "New"(1)`) fails because `"New"(1)` is not valid call syntax at all, not because import cannot reach the function. Own test: `import :Shop, only: [{:New, 1}]` succeeds, and a call to the imported function built as raw AST (`{:New, [], [11]}`) **runs** and returns the record. So "import cannot reach PascalCase names" (brief Option A doc delta, section 0) over-reaches. What is true: no source spelling of a bare call exists; a macro or generated AST can use `import`.
- 01 B5 (`Module.safe_concat([:Shop])`) fails because `safe_concat` yields `Elixir.Shop`; harmless, but it is a manufactured failure in a table headed "ways to call".

### f. Claim 8 ("boundary tests `Kind` only") is function-specific
`Shop.Which` has clauses that name only the type, so a map with the right `Kind` and no `Total` matches. A function that reads a field does not accept it: `:Shop."Amount"(%{Kind: :"Shop.Order", Id: 9})` raises `KeyError` (key `:Total` not found). `Pay` accepts an extra key and a wrongly-typed `Total` (returns `Total: 500`). The brief and its suggested LANGUAGE.md sentence should say "checks only what the clause patterns name", not "Kind only".

### g. Citations
- `LANGUAGE.md` 3299-3302: correct (code fence 3299, the two lines 3300-3301, fence 3302), in section 12 (header at 3274, subsection at 3291).
- `bs_otp.erl` header quote (lines 7-8): verbatim, within lines 1-14 as cited. 
- `bs_lexer.xrl:14-16` (UPPER/LOWER/ALNUM definitions) and `150,153` (uident/lident): correct.
- Macro.underscore at 2316 and do_underscore at 2331: confirmed as printed from the beam's debug info (no `.ex` source on the machine; the brief says so honestly). `camelize` is at 2380.
- Ticket 10 section 7 / 62 quote "Gleam downcases when it emits to the BEAM": that sentence is ticket **62's** paraphrase, quoting ticket 10 section 7 as "PascalCase becomes snake_case"; ticket 10 line 335 reads "PascalCase to snake_case". The brief's ledger row 6 puts it in quotation marks as ticket 10's wording; minor.
- Ticket 26 line 488: quote correct. Ticket 32 line 204/344 "no snake_case-PascalCase rule anywhere in the language": correct.
- Section 3 says the patch is "41 added lines": the patch hunks add 41 lines (counted `+` lines excluding headers: 44 including exports lines); acceptable.

### h. Additional naming-rule inputs (not in the brief)
Real `Macro.underscore` (the rule the brief recommends for Option B) vs the "simple" rule the patch actually uses:

| B# name | simple (patch) | Macro.underscore (real) |
|---|---|---|
| Parse_Url | parse_url | parse__url |
| ParseUrl | parse_url | parse_url |
| Get_HTTPServer | get_httpserver | get_http_server |
| IDs | ids | i_ds |
| UUIDv4 | uuidv4 | uui_dv4 |
| Foo__Bar | foo__bar | foo___bar |
| Sha256Hash, Base64URL, ToJSON2, HTTP2Server | sha256_hash, base64_url, to_json2, http2_server | same |

- B# identifiers may contain `_` (`bs_lexer.xrl:16`), so `Parse_Url` and `ParseUrl` **collide under the simple rule** (patched compiler: `function parse_url/1 already defined`, position `:0`, checked) but not under `Macro.underscore`. The brief's collision list names only `NewUrl`/`NewURL`; the set of colliding names is rule-dependent and the brief should say so.
- `Macro.underscore` yields ugly and surprising names (`i_ds`, `uui_dv4`, `foo___bar`) that a spec would have to freeze. This strengthens the brief's argument against shipping a derived rule.
- The patched compiler measures the simple rule while the brief says the real implementation "must be the Macro.underscore rule"; sizes are insensitive to which, but the collision diagnostics and the Elixir-visible names are not what was measured.
- The author's Erlang re-implementation of `Macro.underscore` agreed with the real one on all my 15 extra names.

## 3. Headline re-test, from scratch
My own Elixir script (`mine/my.exs`, not derived from theirs), against Shop built with `bsc` from `compiler/examples`:
- `:Shop."New"(1)` -> `%{Total: 0, Kind: :"Shop.Order", Id: 1}`.
- Inside a compiled `defmodule`: module attribute receiver `@m."New"(2)`, parameter receiver `mod."New"(3)`, `&:Shop."New"/1` in `Enum.map`, pipe into `:Shop."Amount"`, `alias :Shop, as: ShopAlias; ShopAlias."New"(7)`, `apply(:Shop, :New, [8])`, tuple-element receiver `elem(x,0)."New"(...)`: all run.
- Controls red: `:Shop.new(1)` -> `UndefinedFunctionError`; `Shop.New(1)` (Elixir alias syntax) -> parse error `unexpected ( after alias New`; `Module.concat([:Shop])."New"(9)` -> undefined (`Elixir.Shop`), which shows the receiver matters and the quote alone is not magic.
- Extra: `Code.format_string!` preserves the quoted form.
- Extra: Elixir field access on the result `o.Kind` is a compile error whose message **does** say "wrap the function or field name in double quotes". So Elixir already tells callers about quoting for field access but not for the function-call case; the brief's remark that the error "never mentions quoting" is true only for the call error. Callers reading fields must write `o."Kind"` or `o[:Kind]`/patterns.
- Gleam: my own project (`mine/g`) with `@external(erlang, "Shop", "New")` and `"Amount"`, run with `-pa`: prints `#{'Kind'=>'Shop.Order','Total'=>0,'Id'=>5}` then `0`. Confirmed; the ticket's claim holds.

## 4. Alias-patch audit
Read `alias_emit.patch`. `forward` adds the alias to the export list, a duplicate `-spec` and a one-clause forwarder `alias(A..) -> 'Name'(A..)`; `forward_nospec` omits the spec; `dup` replaces the forwarder with a renamed copy of the whole function (bodies recursing into the original name). No other emission changes. `none` is byte-identical to the stock compiler in all chunks except `CInf` (path). Exports in forward and dup differ by the same alias set (verified for N=10). Only public functions are aliased. The `snake/1` used by the patch is the simple rule (see 2h).

## 5. Corrections for the orchestrator (brief.md not modified)
1. Section 3 (OTP): replace "all in `diameter_types`" with 14 in `diameter_types` and 5 in `wx` (`wxImage`, `wxMenu`, `wxRegion` x2, `wxWindow`); print all hits in probe 10.
2. Sections 4.1, 5 (Option B), 6 reason 2: the "+50% beam / +48% compile" figures are for one-line bodies. State the realistic-body figures (forward +25% beam, +15% compile; dup +47% / +100%; N=200, my regeneration) and the stripped-beam figure (+55%); give compile percentages as a range (my rerun of probe 05 gave +76% for forward at N=200).
3. Section 4.2: the quoted medians are not in the committed `.out`; either regenerate the `.out` or quote the committed figures. Correct the spread ("up to about 40% min-to-max at 5e7; difference -0.5 to +0.4 ns"). Note that a genuine extra hop costs about 0.5 to 1.8 ns/call (my `hop2.erl`), so "indistinguishable from zero" means "under about 1 ns".
4. Section 0 and Option A: "import cannot reach PascalCase names" should read "no source spelling of a bare call exists after `import`"; `import :Shop, only: [{:New, 1}]` plus a macro-built local call works.
5. Claim 8 and section 6 last paragraph: replace "Kind only" with "only what the clause patterns name" (`Amount` with no `Total` raises `KeyError`).
6. Probe 09 and 08: relabel or remove the two non-controls; probe 01 T6 and B5 are not tests of what their labels say.
7. Section 4.5: add that colliding names depend on the rule (`Parse_Url`/`ParseUrl` under the simple rule), that `Macro.underscore` gives `i_ds`, `uui_dv4`, `parse__url`, and that the measured patch uses the simple rule, not the one recommended.
8. Optional: the "Elixir's error never mentions quoting" sentence should add that the field-access error (`o.Kind`) does.
