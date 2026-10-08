# Verification of the ticket 52 brief (adversarial, independent rebuild)

Verified 2026-10-08 on OTP 25.3 / Elixir 1.14.0. Own builds in `/tmp/verify52/{stock,proto}`; probe copies with paths edited in
`/tmp/verify52/probes/`; fresh outputs in `/tmp/verify52/new/`. Nothing under `compiler/`, `wayfinder/`, the brief or the probes
was edited; no commit; Linear untouched. Gleam/Elm statements: the brief labels Gleam `UNVERIFIED-NOT-EXECUTED` and makes no Elm claim; nothing to correct there.

## Verdict: PASS WITH CORRECTIONS

Every executed probe reproduced (19 of 20 identical; p5 differs, below). The recommendation's core facts hold: verdict purity (p13),
stock accepts / prototype refuses by environment (p8), no new yecc conflicts (p20), 4 AST sites (p14). But one headline
blast-radius claim is not supported, one precedent claim is overstated, the stated build path for the prototype does not work,
and several figures are over-precise.

## Reproduced

| Item | Result |
|---|---|
| Patch is a diff against `compiler/src` | Yes, 4 files. Applies cleanly **only after header paths are rewritten to basenames** (see M1) |
| "+59/-7, no new yecc conflicts, 4 AST sites" | **True.** `grep -c '^+[^+]'` = 59, `'^-[^-]'` = 7. yecc: stock `6 shift/reduce, 0 reduce/reduce`; patched identical; control copy `6 s/r, 16 r/r`. `grep '{foreign,' compiler/src` outside bs_check/parser: none; bs_check has exactly 4 (lines 622, 640, 1064, 1102) |
| Stock files byte-identical to compiler/src (`cmp`) | True for the 4 patched files |
| p1, p2, p3, p4, p6, p7, p8, p11, p12, p14, p15, p16, p17, p18, p19, p20 | Identical to `.out` (modulo tmp dirs/timestamps) |
| p13 | Hashes identical to the author's except whole-`.beam` md5 (path-dependent, as the brief says) |
| p10 | Sizes identical (836/928/928/1036). Timings differ by noise (see Timing) |
| p9 | Identical: 23 distinct modules, 90 occurrences, 13 absent, 2 flips (`51a-code-path/Elx`, `Req`) |
| p5 | **Differs**: see M4 |
| eunit, stock vs prototype (`/tmp/runtests.sh`) | 467 failed / 859 passed on **both**; `diff` of failing-name sets: empty (but see M2: vacuous for CLI tests) |

### Attacks

(a) p13 checksum. Independent run, same out dir name, three `ERL_LIBS` (`""`, `/usr/lib/elixir/lib`, `/nonexist`):
`A.abstr 524e1498...f3884` and `A.beam 65444eb7...f61221` identical in all three. Control (different source, different module):
`B.abstr 54fbe71c...`, `B.beam 5001b3f6...` differ. **Confirmed**, including the brief's explanation that the whole-file `.beam` differs only through the
output path in `CInf`. Caveat: "today the verdict cannot depend on the code path" is shown for `-o` compile; `bsc.erl:691-692` and `bs_repl.erl:68`
(`ensure_loaded`) are run/REPL paths the brief never discusses.

(b) p2. Run: `AttrApp`/`AttrOnly` -> `error: syntax error before: '['`; `AppKeyword` -> `syntax error before: app`; `AliasT106` -> `syntax error before: 'GetOrCrash'`;
`PlainQuoted` accepted. Independent grammar check: in `bs_parser.yrl` the `'['` token appears only at lines 546-571 and 779-785
(patterns, list expressions), never at declaration level. **Confirmed.** Ticket 32's `[external: erlang, "ets"] module Ets` is at `32-ffi-surface.md:334`.

(c) p17. See M3. The check exists and fires, but is **not** keyed on `--src-root`.

(d) p8 / blast radius. Recount: `grep` of compiler/test gives users_db 3, trees 3, session_store 3, store 1, m 1, analytics_db 1, accounts_db 1 = **13 occurrences of 7
names**, and the 51a `Elx`/`Req` flips reproduce. The word **"break"** does not (M2).

(e) p11 / p15. "3 of 30 blocks": 30 blocks, 18 files, 27 (file, app) pairs, 13 `:erlang` blocks: all recomputed correctly; the three `?` are `epgsql`, `json`, `Req`. `ssl` closure
6 (includes itself), `logger` 5 (includes itself): reproduced; "needs 6" counts the app itself. See O2 for the OTP 28 caveat on `json`.

(f) p5. M4.

(g) 25d-g. The brief does not rely on the invalid verdict rows: §6 uses the static module census (`code:which` on `epgsql`, `json`) and file:line quotes; §8 admits the rows are void.
Nit: p9's "18 files" denominator includes those 6 void rows (25d, 25e, 25f, 25g x3).

## Mismatches

**M1. The documented way to build the prototype fails.** `build-bsc.sh` takes one target file from the *first* `---` line of each patch and applies every hunk to it. The patch
touches four files and has absolute headers, so:
```
$ build-bsc.sh /tmp/verify52/proto 52x-app-clause-and-check.diff
7 out of 7 hunks FAILED -- saving rejects to file bs_parser.yrl.rej
4 out of 4 hunks FAILED ...
1 out of 1 hunk FAILED ...
```
Also the header says "+++ /tmp/bsb_52_x/..." and the brief says to build "via build-bsc.sh with the patch". Workaround used: `sed` headers to basenames, `patch -p0` in a copy, then the same shim/leex/yecc/erlc steps. Result: 15 beams, identical behaviour. The prototype author evidently built it by hand.

**M2. "13 occurrences of 7 fake foreign modules in compiler/test would break" is unsupported (probably wrong as stated).**
- All 13 sit in tests that assert a **refusal for another reason** (`?assertEqual(1, Rc)` plus a "returns X, which one guard cannot decide" message). The prototype's presence check runs after `foreign_rets_decidable`, so the declaration error is still first. Direct runs, stock vs prototype, first diagnostic line: `Analytics` (analytics_db), `For` (:m), `U1` (users_db), `T1` (trees), `S1`/`S2` (session_store), `S3` (users_db): **identical in all 7**. `function_value_tests:549` (`check_only`) passes in both.
- The eunit set difference (empty) cannot confirm this on its own: the CLI-driven tests (`bs_test_support:run_cli_result`, needs `_build/default/bin/bsc`, absent) already fail in the baseline, so they are blind to the prototype. I therefore ran the fixtures by hand as above. Not run by hand: strings_tests 268/283/297, foreign_return 98/131 (same pattern, by inspection).
- What *would* break is any fixture that expects **acceptance** with a non-existent foreign module; I found none among the 13. The brief's claim ("fixtures that need to compile with a module that does not exist") should be "none found; order-dependent". The p9 census measures only that the modules are absent, not that anything breaks.

**M3. S3 / p17: "native `using` check is keyed on `--src-root` (an explicit argument), not an ambient environment variable" is overstated.** `--src-root` is optional: with it absent `source_index/2` defaults to `filename:dirname` of the given module directories (`bsc.erl:437-441`, called at `bsc.erl:315` via `load_all`). Ran without `--src-root`: absent -> `src/UsesMissing/a.bs:2:1: error: \`using Nope.Gone\` names no module and no namespace` (rc 1); present -> `Dep.beam`, `UsesPresent.beam` emitted. With a wrong root: `bsc: --src-root other does not contain src/UsesPresent`. So the native precedent depends on the **source tree on disk**, not on a flag. It is still different in kind from `ERL_LIBS` (files given to the compiler vs. an installed-library search path), but the "explicit argument" framing and the use of it in §7 caution 2 ("contradicts S3's own precedent") should say "the source tree handed to the compiler". The throw site is `bs_check.erl:504` (`unknown_module`), rendered at `bs_diag.erl:2029-2032`; the brief's `bsc.erl:617` is a comment about running (see Citation errors).

**M4. p5 "surprise" is not as reported, and it is explained.** The committed `p5-elixir-mix-xref.out` shows case (b) **clean** (`Compiling 1 file (.ex) / Generated demo app`), contradicting the script's own text ("declaring :ssl AFTER a first compile still warned"). My rerun of p5 shows the warning in (b), and a separate loop (4 fresh projects, three `mix compile --force` each, one after `sleep 1.1`) warned 12 of 12 times. Cause: Mix 1.14.0 caches the app set in `_build/dev/lib/demo/.mix/compile.app_tracer`, which is not invalidated by editing `extra_applications`, even with `--force`:
```
force:                                          1 warning
rm _build/dev/lib/demo/.mix/compile.app_tracer
mix compile --force:                            0 warnings
```
(`rm -rf _build` also clears it.) The brief's "reproduced once, not explained" is therefore out of date and the saved `.out` contradicts the text. This does not undermine the Elixir neighbour claim (warning, exit 0, fresh project clean, `.app` lists `ssl`): it adds evidence that Elixir's check is a *cache-dependent warning*. Mechanism is from executed behaviour only; Elixir sources are not installed.

## Circularity flags

1. **Vacuity guard is bypassed by the probes that matter.** `lib.sh probe()` has the guard (only `: error: ` counts as refused). p8's `try()`, p9's `verdict()`, p13's inline `r=$(...)`, and p14/p18 treat **any non-empty output** as "refused". Demonstration: `erl -pa /nonexistent/ebin ... D/a.bs` yields `refused: {"init terminating in do_boot",{undef,[{bsc,main,...`. The saved outputs show real diagnostics, so the *results* stand; the scripts could not tell a crash from a refusal.
2. **S4 ("the check needs no declaration") is true by construction.** The author's `foreign_dep_check` ignores `App` unless set; Noapp refusing is the author's own code doing what it was written to do. It shows feasibility, not a property of the existing compiler. The same for the ownership check (`lists:prefix(code:lib_dir(App), Beam)`) and for Option 3's `needs.escript` (`code:lib_dir/1`): each probe confirms the prototype, with the controls (stdlib found in both, correct app accepted, stock accepts) being the only independent content.
3. **p18 demonstrates "Option 3: compile unchanged" with `BSB_DEP_CHECK=off` in the same build**, not a build lacking the check. Adequate because p13 independently shows stock purity, but p18 alone is not evidence for it.
4. **p8 severity row**: `BSB_DEP_CHECK=warn` is the author's own switch plus an ad hoc `DepWarn` list; it shows bsc's warning channel can carry a message, nothing about the right severity.
5. Expected values: no probe expectation was found adjusted to fit output. p19 and the `.out` for p13 record the author's earlier mistakes openly. Controls that can fail exist for every probe in the brief's index (stock refuses new syntax, 0-app size, changed source differs, duplicated production raises conflicts, absent dep fails in p1/p8/p13/p17/p18).

## Citation errors

| Cited | Actual |
|---|---|
| `bsc.erl:617` (S3, native check) | Line 617 is the 2nd line of a comment in `run/3` ("dependencies compiled and on the code path before it can run"). The check: `bs_check.erl:504`, index built at `bsc.erl:437-448`, `bs_diag.erl:2029-2032` |
| Ticket 51:53-54 ("consumes hex directly") | The words are at `51-a-build-and-dependency-tool.md:55` (sentence runs 53-55) |
| `bs_diag.erl:694` ("producer" of warnings) | A generic clause `built(Path, {Sev,_,_,_} = D) when Sev =:= error; Sev =:= warning`; true, but it is the builder, not an `unreachable_arm` producer |
| p19's "LANGUAGE.md:1163-1169" | Block is at ~1163-1170; fine |

Verified correct: `LANGUAGE.md:2986`, `:3006`, `handoff/MANIFEST:49`, 25d `index.bs:12`, 25f `index.bs:44`, `req.bs:69`, `bs_emit.erl:77` and `:1481`, `compiler/README.md:272`,
`32a_gleam_external.gleam:3`, `ssl.app:85`, `asn1.app.src:12`, `xmerl.app.src:42`, `foreign_return_tests.erl:83`, ticket 41 lines 73-74, ticket 50 (resolved 2026-08-26), ticket 106 (resolved 2026-09-25), ticket 32:334.

## Overstatements

- **O1. Timing precision.** Brief: "`code:which` is about 0.75 ms". p10 measured 0.67 ms and 1.19 ms in the same run (author's run: 0.76 and 0.78); "about 0.75" hides a 0.7-1.2 spread. Also the "path after add_pathz" row adds 1 dir (39), so it is not a different configuration worth reporting.
- **O2. "3 of 30 blocks" is OTP-25-specific.** `json` is in OTP 27+; on the repo's pinned OTP 28 it derives, leaving 2 of 30 (`epgsql`, `Req`). §6 concedes `json` is "probably present" on 28, but §5 and §7 (the recommendation) use "3 of 30 ... exactly the ones the handoff cannot reconstruct" without the caveat.
- **O3. Option 2's quoted diagnostic recommends `--lib`**, a flag `bsc` does not have (`grep -- '--lib' bsc.erl` -> none; `ERL_LIBS` is not referenced anywhere in `compiler/src`). It is prototype text, not designed text.
- **O4. Compiler delta omits other consumers.** The new production would also need `editor/tree-sitter-beam-sharp` and anything else that parses `using`; the brief says "no other file matches `{foreign,`" which is true for `compiler/src` and `compiler/test` only. Not verified either way.
- **O5.** "Of the 18 `.bs` files with a foreign `using`, stock accepts and prototype refuses 2": true, but 6 of the 18 rows are the invalid 25d-g runs (§8 admits). The accurate denominator is 12 valid rows.

## Timing re-measurement

Interleaved (on / off / stock in rotation to cancel drift), N=40 each, full process wall time, Elixir lib on `ERL_LIBS`, T2 source:

| variant | median | mean | p10-p90 | min-max (ms) |
|---|---|---|---|---|
| proto, check on | 428 | 431 | 393-470 | 369-523 |
| proto, check off | 416 | 423 | 395-457 | 377-504 |
| stock | 423 | 430 | 398-462 | 377-535 |

On/off medians differ by 12 ms inside a 70 ms p10-p90 spread: the brief's "inside the spread in every pair" holds. Its "430-550 ms process" is the right order (369-535 here when quiet). The author's saved run shows T3 on/off at 546/537 against T2 at 425-470: an unrelated 100+ ms batch drift, as the brief warns; no on/off timing is quoted more precisely than that allows apart from O1.
