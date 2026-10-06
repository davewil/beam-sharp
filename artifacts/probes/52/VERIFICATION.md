# Independent verification of ticket 52 evidence

Verifier re-ran `run.sh` from a copy (probes in `.../scratchpad/verify52/probes`, `WORK=.../verify52/work`; the only change was
the `WORK` env var so the author's `p52work` was not overwritten). All 18 scripts exit 0. Author's files, compiler/, wayfinder/ untouched.

## 1. Re-run diff (author's out/ vs mine, paths normalised)

Identical in substance for 00, 01, 02, 03, 05, 08 (xref/systools/dialyzer), 09, 10, 11, 12, 13, 14, 15, 17. Differences:

- Absolute paths, timings, `Compiled in Ns`: ignored.
- **06 (numbers differ, conclusion holds).**
  - Beam sizes shift by source-path length: mine none 1200 / using 1596 / module 1328 (author 1180 / 1580 / 1312);
    ShopC 1264 / ShopA 1364 / ShopB 1324 (author 1144 / 1244 / 1204). Deltas: +396 / +128 (author +400 / +132), and ShopA +100, ShopB +60 (same).
    Absolute sizes depend on where the source lives; the deltas reproduce.
  - lib_dir hit: mine 2.93 us, author's final out/ 5.50 us. which hit 41 vs 45 us. load+unload 220 vs 225 us.
  - End to end: mine no-marker median 731.7 ms vs 10-marker 838.9 ms (+107). Author's final out/ has 800.9 vs 766.2 (-35). Spread
    is 500-700 ms, so both support "no measurable end-to-end difference", and neither supports any smaller claim.
- 16 (eunit): my re-run of the 2 x ~3 min suite hit my 590 s limit and was killed. **UNCHECKED**; only the author's recorded file
  (227 passed / 1 failed on both copies, `body_check_tests:every_aoc_program_still_compiles_test`) exists.

## 2. Per-probe verdict and circularity

None of the probes asserts anything. Each prints raw output and a `REFUTED IF` comment that a human must check, so "green/red" below means "output changes".

| Probe | Verdict | Reason |
|---|---|---|
| 00 fixtures | REPRODUCED | builds clean |
| 01 bsc-today | REPRODUCED | compile exit 0 silently; `Make` -> `crashed: error:undef`; `Two` -> 2; missing function, missing module, wrong ERL_LIBS give identical text. Mutation: correct ERL_LIBS gives `:get` (author's section B). Not circular: uses the repo's unpatched bsc |
| 02 codepath | REPRODUCED | the ghost / loose / absent rows reproduce. Caveat: `loose` is "present" in lib_dir only because the fixture dir is itself named `loose` and was added with `add_patha`; it demonstrates basename keying, not a general hazard |
| 03 versions | REPRODUCED | 40/40 numeric vsn; I recomputed independently in Python (40 files, 40 numeric) |
| 04 patched build | REPRODUCED | 6 s/r before and after; +14/+33/+4/+8 |
| 05 patched behaviour | REPRODUCED, with one CIRCULAR claim (below) | |
| 06 size/cost | REPRODUCED (deltas), DIFFERS (timings vs the brief; see section 4) | baseline "none" differs from "using" only by markers; repo bsc and patched bsc give the same size for the unmarked file |
| 07 corpus census | REPRODUCED | same 21/21, same non-loadable list. Hook (c) block output reproduces |
| 08 ecosystem readers | REPRODUCED | xref/dialyzer/systools unchanged by the attribute. Positive control exists (dialyzer/xref do report the missing remote) |
| 09 erlang/rebar3 | REPRODUCED | |
| 10 mix | REPRODUCED | mutation below goes red as expected |
| 11 gleam | REPRODUCED | G3 is network-blocked, as stated |
| 12 elm | REPRODUCED as "could not run" | |
| 13 attribute-to-app | REPRODUCED but weak evidence | the tool reads an attribute the same patch wrote; it shows the attribute is consumable, not that anyone needs it. `inferred` uses the directory basename, which is the F2 hazard |
| 14 module-to-app rule | REPRODUCED | I recomputed: Elixir 174/412 = 42.2%; Erlang 26/1397 = 1.9% (author 26/1314 = 2.0%, my regex counts more modules; same conclusion). The rule is a straw-man naming rule, but the claim is stated that narrowly |
| 15 surface today | REPRODUCED | |
| 16 suite | UNCHECKED | see above |
| 17 otp app names | REPRODUCED | |

CHANGELOG.md: I find every logged edit legitimate (formatting, tool absence, fixture ordering, scripts' own bugs). Item 5 ("part (c) added after (a),(b)
showed the hook refuses nothing") and item 10 (ShopBLie added after seeing the ShopLie result) are disclosed post-hoc additions. They add a case; they do
not change the existing ones. Two things the changelog does not say: the brief's timing numbers come from an earlier run than the final out/ (section 4);
and the patch was regenerated twice before first use, which is logged.

### Mutations (5+ premises broken; all by me, in `verify52/mut/`)

1. **M1: neutralise the lib_dir check in a patched-bsc copy** (`{error,_} -> ok`). ShopA with ERL_LIBS unset compiles, exit 0, then
   `crashed: error:undef`. Before the mutation it was `error: application mylib is declared here...`, exit 1. RED as it should be: the diagnostic comes from the check, not from the probe.
2. **M2: unpatched repo bsc on ShopA.** `syntax error before: '['`, exit 1. The prototype's grammar is the only reason `[app:]` parses.
3. **M3: Mix consumer with the dependency removed** (but `extra_applications: [:ssl]` kept). The `MyLib.new/1 is undefined` warning returns (V1 reproduces from a declared state). RED as it should be.
4. **M4: independent recompute of probe 14 and 03(c) in Python** (above). Same numbers.
5. **M5: LANGUAGE.md block and exemplar 25d.** Exemplar 25d without the hook fails for another reason (`this directory holds .bs files and no module line`); with the hook it gets `application epgsql is declared here and is not on the code path`. Supports the brief's "refused too". It was not tested by the author's probes, only inferred from the non-loadable list.
6. **M6 (the key one): the "B cannot verify" result is by construction.** The patch has `_ when RM =:= module -> ok;`, so a module-level marker is not checked
   against any module. I replaced that line with 7 lines that, for a module-level marker, require every foreign `using` module (except maps/crypto/ets) to
   have `code:which` inside some listed app's `lib_dir`. Result with the dependency present and `BS_PROTO_STRONG=1`:
   `[app: stdlib] module ShopBLie` -> **refused** (exit 1), correct `[app: mylib] module ShopB` -> `:get`, exit 0. So **Option B can catch
   the wrong-app lie**; the probe's "compiles clean, then undef" is a property of the prototype's missing code, not of the option.
7. M7: `= :'get!'` alias in a `using` entry gives `syntax error` in the repo bsc, consistent with "106 unbuilt".

## 3. Citations

All opened and checked: `bs_parser.yrl:170` (foreign_decl), `bs_check.erl:93` (check_dir1), `bs_emit.erl:73-78` (attribute list), `code_server.erl:1035-1038`,
`:642-651`, `:126-150` (all match), `xref_reader.erl:86/90/92` (match), `systools_make.erl:592` (`error_reading`), Mix docs lines 14-18 and 46-50 (match out/10),
tickets 32, 41 (line 74), 50, 51, 106 (decisions entries match). `scope.md` is referenced by ticket 52 line 32 and not in the repo, as stated.
Mis-cited / loose: none outright wrong. Imprecise: "script mentions it (6 times)" is `grep -c` of lines, not occurrences.
`xref ... identical` differs in the module name (ShopC vs ShopA) by construction.

## 4. Brief claims not supported by the raw outputs

1. **Timing numbers in F9 do not match the final `out/06`.** Brief: no markers median 685 ms (min 526, max 1104), 10 markers median 741 ms (min 549, max 1055);
   lib_dir hit 2.9 us / miss 1.7 us; load+unload 213 us; "~70x dearer". Final out/06: medians 800.9 / 766.2 (min 576.4 / 620.0, max 1383.0 / 1266.3);
   lib_dir 5.495 / 8.204 us; load+unload 224.6 us (about 41x). The brief was written (23:44) before the final run (23:46) and was not refreshed. The qualitative claim survives; the figures are
   not in the shipped raw output. (2.9 us and 213 us are close to my own re-run, 2.93 / 219.9, so they are plausible but not what the author's out/ says.) Note the sign of the 56 ms gap
   is also not the same in out/ (-35 ms).
2. **"the 14 corpus blocks"** (Option A and recommendation reason 4). out/17 shows `:erlang` x10; OTP blocks total about 22 (erlang 10, maps 4, gen_server 2, 6 singles).
   "14 `using :erlang` blocks" appears only in a script comment and is not what it prints.
3. **Recommendation reason 2 ("Only A can verify module belongs to app")** rests on the prototype's `RM =:= module -> ok` line. My M6 shows B can verify it with a 7-line check. The brief's B
   counterargument half-concedes this ("the check would have to be the call-site one") but F6 and the Recommendation state it as measured fact.
4. **Core-delta accounting for the recommended option.** "About 36 core lines" excludes the "strong" check, which is the probe-only hook (part of the 23 hook lines), yet the recommendation requires it.
   The cost of recommended A is nearer 36 + ~14.
5. Diagnostics: the strong refusal prints "no `stdlib` directory with an ebin was found" when stdlib exists, and the C hook prints "application `Elixir.MyLib` is declared here". Neither is wrong evidence,
   but the brief quotes the "is declared here and is not on the code path" form as the A diagnostic without noting that the strong-check message is wrong for its case.
6. F7 "Epgsql ... would be refused too" is inferred, not probed in the author's scripts (I checked it; it holds).
7. Absolute beam sizes depend on source path length (my 1200 vs 1180 for identical content); the "2-25% of shipped examples" comparison mixes two different path contexts. Deltas are stable.

## Overall verdict

**Evidence mostly reproduces; two brief numbers are stale; one comparison is rigged by the prototype.** Every executed fact F1-F10 reproduces from a clean copy with the same outputs, and the key mutations turn red.
The check being claimed, F1/F2/F6/F10 and the neighbour survey, is sound. Fix before the brief is relied on: (a) replace the F9 timing numbers with those in `out/06` (or re-run and re-paste); (b) correct "14" to the real count; (c) soften F6/Option B/reason 2
from "B cannot verify module belongs to app" to "the prototype's B does not", since a 7-line change makes B refuse the wrong-app case, which removes the main reason given for A over B. The recommendation of A may still stand on the
other grounds (explicit per-module provenance), but not on reason 2 as written.
