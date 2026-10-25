# Verification of brief.md (ticket 64), independent re-run

Method: probes copied to a scratch tree (`scratchpad/verify64/`), paths rewritten only to point at the scratch dirs. Scratch compilers d1/d2/d3 were rebuilt by me from `bsc-build/src/bs_check.erl` plus the stored `delta*.diff` files, not reused. `bsc-build/src` is byte-identical to `compiler/src` at HEAD 1429fdc, and `git status` shows only `artifacts/` untracked. Timing probes were run 3 times.

## 1. Circularity / validity flags (first)

**F1. p16 is invalid. The brief's claim that a standard-environment `option<V>` row collapses silently at `term` is not demonstrated.**
- p16 uses only `--api`. `--api` neither type-checks bodies nor compiles (bsc.erl:152 "runs before the REPL and the compile path because it does neither"; the same is visible in p01, where `--api` prints a signature for a module whose body is refused).
- Under a real compile, the scratch row is rejected. Both my d2 build and the original `scratchpad/64/delta2/bsc` print `error: no type named option takes a type argument` for the stored `src_Pk.bs`. The `Use(m) -> Map.PeekOpt(...) switch {...} compiles` claim in brief section 3 is false.
- Under `--api` the checker is not consulted at all. `public int Bad(map<string,int>) -> Map.PeekOpt(m,"k")`, `public string BadG -> Map.Get(m,"k")` on `map<string,int>`, and `public atom ...` all print as accepted. The "control" (`OnInt` as `option<int>`) cannot fail, because the declared type is simply echoed.
- Consequence: brief section 1 item 1 ("all eight option-returning `?` rows ... collapse silently at T=term today (p05, p16)") is unsupported for rows. Those rows are unbuilt (p04 shows `Map.?Get` does not parse), so "today" is wrong even in principle. Only the user-generic case (p05) is supported.

**F2. p05 stands, but it lacks a control in the probe.** I added one. The same generic `Find<V>` returned as `public int` at V=int is refused: "AtInt returns a value its signature does not declare ... :nothing". At V=term returned as `term` it is accepted. So the gating gap is real for user generics (non-`--api` compile and run). The control belongs in the probe.

**F3. The p12 explanation is false.** The brief says "erlc inlines the private `Probe` and never builds the tuple".
- I compiled LoopTag.beam with the same options as `bsc.erl:843` (no inline) and dumped the asm. `Probe/1` is a real local function containing `put_tuple2 {some, ...}`, and `Loop` does `{call,1,{f,4}}` to it.
- So the tuple is built and the null result is not due to inlining. The cost is simply below the noise: 10M iterations take about 100 ms above the baseline of about 450 ms. The conclusion "the optimiser can erase the cost" is unsupported. The measurement itself (no visible difference) reproduces.

**F4. p18, an untested hole behind "whatever E is".** The brief says "the error tag keeps the member apart, whatever E is" and closes Open 3 on that. p18's own output accepts `result<(atom,int), term>`, where `(:error, 5)` is both a success `(atom,int)` and a failure `(:error,term)`. I ran it: `F(1) -> (:error, 5)` is accepted, and a switch on it takes the `:failure` arm. F36 refuses only full absorption, so partial overlap at `E=term` is accepted. p18 shows `E=term` does not trigger a new refusal. It does not show that `result<T, term>` is unambiguous for every T. Open 3 can be closed only as "no new refusal needed", not as "no ambiguity".

**F5. Inflated count in p17.** The loop iterates per `.bs` file, so a directory with several files is compiled and counted repeatedly (`25d-database-querying` x4, `25e`, `25f`, `Collapse` and others twice). "17 modules" is 17 iterations over about 12 distinct directories. The "3 modules gain errors (+6)" headline is correct as printed (Levels +2, Parcel +1, Optional +3). Section 6's "3 of 6 clean repo modules" is correct for distinct dirs. The sentence "each at both producers and consumers" is not backed by anything in p17.out (error counts only).

No hard-coded expected values, filtered-to-success output, or special-cased scratch-compiler inputs were found elsewhere. The three delta diffs are generic table and one-line changes. The attempt1 files are honest: attempt1 to final differs only by the `:maps.` qualifier (p06), PascalCase alias names (p07), and non-colliding controls replaced by colliding ones (p18, which strengthens it). The p02 sed changes only the `BSC=` line and the `-x` check; I diffed it against the original.

## 2. Per-probe re-run verdict

| Probe | Verdict |
|---|---|
| p01 | REPRODUCED (identical). Note `result<int,term>` / `result<int,atom>` also show body errors, so acceptance of the declaration rests on the `--api` line. |
| p02 | REPRODUCED (identical) |
| p03 | DIFFERS. My output has an extra block: the `Tup` case (`result<(atom,binary),binary>`) is refused with "(:error, binary) is absorbed by (atom, binary)". The stored `.out` is missing that block, so it is stale or truncated (the file's mtime is earlier than `src_Tup.bs`). The brief's claim is supported by my output. Fix the stored file. |
| p04 | REPRODUCED |
| p05 | REPRODUCED (valid, see F2) |
| p06 | REPRODUCED (all 9 kind lines, Bad refused, `C2Raw` badkey) |
| p07 | REPRODUCED |
| p08 | REPRODUCED |
| p09 | REPRODUCED (identical, including the Elixir doc line numbers) |
| p10 | REPRODUCED (rc=1 from grep -c 0, as stored) |
| p11 | PARTIAL. Words table and `{some,V}`=`{ok,V}` identical. Loop numbers vary: stored GCs 2 vs 593, mine 1 vs 363 (x3 identical to each other); list case 0 vs 970 identical. Direction holds. Timing is noisy (see section 4). |
| p12 | REPRODUCED x3 (no difference; spread larger than any effect). Explanation false (F3). |
| p13 | REPRODUCED (14 files / 27 lines / 17 erl / 66 md). The final header line's claim (no stdlib row returns `option<T>`) rests on an empty grep. |
| p14 | REPRODUCED x3 (see section 4) |
| p15 | REPRODUCED. Stock control checked in full: `Map.Fetch`, `Map.Get` each get "`Map` has no operation of that name". Runs and negatives match. |
| p16 | REPRODUCED textually, but INVALID (F1) |
| p17 | REPRODUCED (identical, 14 vs 8 errors, 3 worse) |
| p18 | REPRODUCED; valid but see F4 |
| p19 | REPRODUCED |

## 3. Citations checked (all verified unless noted)

- bs_check.erl:1109-1135 `collapse_decl`, opaque_env at 1110, parametric aliases skipped (`type_alias ... []`): OK.
- :3415 `absorbed`, :3410 `validate_collapses`, :3338 `declared_op`, :3295 `reserved_op`: OK.
- :1351 prelude alias, :1219 `failure_channel`, :3446 `ParseAtom` union, :1747 `Has` row, :1763 `sought_row`, :1738 `List.Insert generated`: OK.
- :1721 `declared_rows`: actually 1722 (off by one).
- bs_emit.erl:2153 `reserved_form List.Insert`, bs_parser.yrl:132 `record_decl` (no type params), bs_diag.erl:1973 hint, LANGUAGE.md:1651 hint: OK.
- `checked_call_typed/7` and `template/4` exist (4413, 833).
- OTP maps.erl 115 / 138 / 304 / 686: OK.
- STANDARD-ENVIRONMENT.md "108 area": line 108 is the `Map.Get` row (decided, unbuilt, ENG-324). The `ToExistingAtom` built row is at line 116. F54 is done 2026-09-21. No `PRELUDE.md` exists.
- Ticket 64 text, ticket 68 Q1 (a), ticket 108 (eight `?` rows at line 155), ticket 48 round-3 Q6 / lines 689 and 1030 (`(:ok,V) | :absent` "day one"), ticket 15 §1 "showcase": OK. Nothing in 96/108/118 mentions ticket 64: OK.
- p07.sh's comment cites `bs_check.erl:710-712` for "prelude owns lowercase aliases". Those lines are `list_offender` code, so the citation is wrong (it is in a probe comment, not in brief.md).

## 4. Timing spread (3 re-runs)

- p14 `maps:find` vs `is_key+get`, min of 7: 26.8/16.9, 22.9/14.9, 22.6/14.3 ms. About 50-60% slower; the claim survives. The brief omits that the `get/3` sentinel is fastest (8.7-9.8 ms).
- p11 bare vs tagged, int case, min: 15.7/16.7, 15.9/16.3, 17.2/20.2 ms, which is +6%, +2%, +17%. Medians +11%, +2%, +10%. The list case, min: +4%, +4%, +7%; medians 0%, +5%, -25%. Bare max exceeds tagged min in every run. The "+4% to +12%" claim does not survive as a number. What survives is "tagged is slightly slower or equal, and minor GCs go from about 0-2 to hundreds".
- p12: no separable effect in any of 3 runs (as the brief says).

## 5. Statements presented as measured with no supporting probe

- "Every one of the eight rows collapses silently at T=term today": no probe (p16 invalid, rows unbuilt).
- "`Use(...)` compiles" under scratch compiler #2: contradicted (F1).
- "erlc inlines Probe and never builds the tuple": contradicted (F3).
- "hex.pm is blocked", "package.elm-lang.org is not reachable": not in p10. Re-checked now: the hex.pm site and API return 200, while repo.hex.pm tarballs, hexdocs and package.elm-lang.org do not connect. So "source unavailable" holds in effect, but the stated reason is loose.
- "records erase to maps with a tag, so larger than the tuple": no probe.
- "BIF call plus tuple allocation vs inlined opcodes" explains p14: flagged as unverified in the brief itself, fine.
- Section 4 option C "each at both producers and consumers": not shown by p17 output.
- The p11 GC counts "2 vs 593" are not reproducible (1 vs 363 here).
