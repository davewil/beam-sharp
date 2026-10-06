# Verification of artifacts/52-dependency-provenance.md (ticket 52, ENG-234)

Verifier: independent re-run, 2026-10-06. Scratch: `scratchpad/verify52/`. No repo file, compiler, wayfinder or Linear object was touched.
Every probe was re-run fresh (own `mktemp` dir, `TMPDIR` in scratch) and diffed against its captured `.out` after masking tmp paths.

## 1. Re-run vs captured output

| Probe | Exit | Diff vs `.out` |
|---|---|---|
| p1 | 0 | identical except the tmp path in the raw `cmp` line |
| p2 | 0 | identical |
| p3 | 0 | identical (census 1279 / 25 / 2.0 %, 413 / 175 / 42.4 % reproduce exactly) |
| p4 | 0 | identical; **mix runs offline, no hex needed** (path dep, `deps: []`) |
| p5 | 0 | identical |
| p6 | 0 | identical except "Compiled in 0.47s" vs 0.45s |
| p7 | 0 | identical |
| p8 | 0 (1m55) | identical (34/34 beams, 232 conflicts, 37/34/36 lines) |
| p9 | 0 | **differs**: absolute byte sizes, timing, lib_dir microseconds (see 3) |
| p10 | 0 | identical |

## 2. Claim-by-claim

| Brief claim | Verdict | Evidence |
|---|---|---|
| `[external: elixir, app: req] using ...` is a syntax error; ticket 32's and `[module: ...]` too; no declaration-level `[` | BACKED | p2 S2-S6; ticket line 46 quoted verbatim. The error is at the `[`, not an artefact of the unknown `elixir` tag: S4 (`[app: req]` alone) fails identically. |
| `using :'Elixir.Req' {}` compiles | BACKED | p2 S1. |
| `LANGUAGE.md:2946` stale ("quoted atoms are not lexed yet") | BACKED but INCOMPLETE | Line 2946 is right and the lexer accepts `:'...'` (`bs_lexer.xrl:131`). But the doc's own example on line 2944 is spelled `:"Elixir.Enum"` with double quotes, and I confirmed that is **a syntax error** (`D.bs:2:7 syntax error before: ':'`). So the doc is wrong in two ways; the brief reports only one. |
| Missing app compiles clean, dies `error:undef` at the call; present returns 42 | BACKED | p1 C1-C3. |
| Beam identical whether the app is present or not | BACKED | p1 C4. I also compiled absent then present into the **same** `-o` dir and `cmp`'d raw bytes: byte-identical. This is stronger than the brief's `beam_lib:cmp` and removes the "ignores compile_info" objection. The control (a different program is not equal) is real. |
| Nonexistent function / module also compile | BACKED | p1 C5, C6. |
| 2.0 % of OTP modules, 42.4 % of Elixir.* modules cannot be mapped to an app | NUMBERS REPRODUCE, FRAMING MISLEADING | Own count from `ebin/*.beam` dirs: 1311 beams (the `.app` lists hold 1279; 32 undeclared), 25 with name == app. 413 `Elixir.*` beams, 6 apps. No module is listed in two apps, so "a module belongs to exactly one app" holds, though no probe tests it. Caveats: (a) 2.0 % is the strict `module == app` test, the weakest heuristic; the probe's own prefix test gives 31.6 % and the brief omits it. (b) The 42.4 % is module-weighted. By app, 5 of 6 Elixir apps are guessable and only `elixir` (237 modules) is not. The sentence "fails on the library everyone calls first" is the fair reading; "42.4 %" alone overstates the failure. Neither figure supports "not derivable" as strongly as a lookup table would: module to app *is* derivable from the machine, which is the brief's own point. |
| `:erlang` used in 8 of 18 example blocks | BACKED | Recount over `compiler/examples --include=*.bs`: erlang 8, maps 2, gen_server 2, lists/json/file/ets/epgsql/binary 1 each = 18. No non-`.bs` file matches. Note the 18 include four out-of-slice exemplars (25d-g); `:erlang` is in 8 either way. LANGUAGE.md has 11 `^using :` blocks, 3 of them the fictional `analytics_db`. |
| 34-37 changed lines | BACKED, metric caveat | Reproduces: inline 34, module 36, attr 37. The count is `diff` `<` plus `>` lines, so every edited line counts twice. The brief says "changed lines"; true edits are roughly half, and it is `bs_check` 21 of the total. |
| 232 yecc conflicts unchanged | BACKED | p8 P4, reproduced; the grep counts a real non-zero string. It is also the figure for all three variants and the stock rebuild. |
| 34/34 example modules identical beams | BACKED, CAVEAT | Reproduced (7 refused identically by stock). It proves the patch does not disturb programs that do not use `in :app`: **no example uses `in :app`**, so it is a no-regression control, not evidence the feature compiles real code. The brief words it correctly as regression control. |
| +36 bytes for one app, +12-14 per extra | BACKED, SHOULD BE "36-40" | Re-measured with beam_lib/`compile:forms`. Short scratch path: baseline 1736, +36 / +60 / +156 / +180. Long scratch path: baseline 1888, +40 / +64 / +156 / +188. The captured run had 152 at nine apps. The baseline moves with the source-path length (`Line` and `Dbgi` chunks), and the delta moves by 4 with the 4-byte chunk alignment. Per extra name: (180-36)/11 = 13. Conclusion stands; quote "36-40, about 13 per extra name" and say the baseline is path-dependent. |
| Attribute is cheaper than function; stock beam has no `bs_needs` | BACKED | p9 Z2, Z5 (control returns `undefined`). |
| `code:lib_dir` about 3.9 us a hit, 3.5 us a miss | NOT STABLE | Five fresh runs: hit 6.7-9.1 us, miss 2.2-2.7 us. The ordering in the brief (hit not much above miss) is inverted: a hit costs about 3x a miss. Say "single-digit microseconds". |
| Whole-compile time not distinguishable from noise | BACKED | Captured: stock min 6.4 ms vs patched 7.3 ms; fresh at lower load: 5.9 vs 5.7 ms (sign reversed). Noise, as claimed. Note p9 Z6 only has an `ok` control; the patched build there passes because the app is present, and the refusal direction is covered by p8 P3. |
| `lib_dir` keys on directory name, not `.app`; `-pa` dir runs but `lib_dir` says `bad_name` | BACKED | p3 D2, D3. Verified through the patched `bsc` too (see 3). |
| Mix warns at compile time about undeclared dependencies | BACKED WITH CAVEAT | Reproduced; needs no hex (p4 is path-only; my own `deps: []` project also ran). The warning is `X is undefined (module X is not available or is yet to be defined)`. A typo module (`Typo.Nowhere.hi/0`) with no dependency idea at all produces the same text, so M2 alone does not show Mix checks *dependencies*. M3 (module present via `ERL_LIBS`, still warned) is the evidence that the verdict follows the manifest, and it is real: the control shows plain `erl` loads the module. |
| "Real output of the patched compiler" in Q2 Opt 2 | BACKED | p10 R3 and my own rerun. |
| Per-app uniqueness / "Req, Req.Test, Req.Request are all app req" | PARTLY UNBACKED | Uniqueness of module to app holds (my census, 0 duplicates), but that Req's modules are one app comes from knowledge of Req, not a probe; the stand-in has one module. |
| Four blocks, four apps in the Req binding (p10) | BACKED for the tool, NOT for real Req | The binding is the brief's own; the claim is "no app repeats in this binding", true by construction. |

## 3. Circularity hunt

- **Is the patched diagnostic independent of a real lookup?** No. The patch (`apps_on_code_path`) calls `code:lib_dir/1` and raises only on `{error,_}`. I built the `inline` patched compiler and tested both directions on the same source: app on `ERL_LIBS` returns 42; `ERL_LIBS` unset gives `error: application fakelib ... not on the code path`. Not circular.
- **Is the `-pa` case real?** Yes, and it shows the check refuses a program that runs. Stock `bsc` with the same source (no `in`) and `-pa flat/` prints 42. The patched compiler with `in :fakelib` and the same `-pa flat/` refuses. Brief's claim holds end to end, not only in plain `erl`.
- **Name-only claims.** Confirmed: `using :fakelib_mod in :stdlib` (wrong but present app) is accepted (42); `in :nonesuch` is refused; an `ebin` dir with no `.app` satisfies `in :noapp`; a dir whose `.app` says another name is only found under the directory name. The brief's description of the check as name-only is accurate.
- **p10 stand-in `req`.** It proves only: the grammar plus a name-only `lib_dir` check works on a four-block binding, `erts` is the only spelling for `:erlang`, and `in :erlang` is refused. It cannot prove anything about real Req's `.app`, its modules list, whether `Elixir.Req` loads, or whether the nine transitive packages are present. The brief says so under "Not verified". One small point: p10 R1 is described as "visual" and has no assertion. p10 also hard-codes `/tmp/claude-0/mm/root/envs/b/...` (as do p3 and p5), so it will not reproduce on another machine without editing.
- **Text greps echoing themselves.** `expect "R3 ... application \`req\`"` matches the patch's own message, but the red is produced by the real `lib_dir` result (R3 vs R2 differ only in `ERL_LIBS`). R3b (stock, same input, `crashed: error:undef`) is a true opposite control. p8's "differing: 0" line is compared against a string built from the variables, which is only an echo, but the printed `identical` count of 34/34 is independently reproduced.
- **Byte deltas confounded by options?** p9 compiles all variants with one fixed option set (`debug_info, binary`) from the same abstract forms, so differences between variants are clean; the absolute baseline (1728 vs the 1788-byte file `bsc` writes) is not the on-disk size and is path-dependent as above.
- **Break attempts that went red as expected:** patched with app absent; `in :erlang`; `in :nonesuch`; `-pa` only; no-`.app` dir with the wrong name. **Break attempt that exposed a miss in the brief:** `:"Elixir.Enum"` is a syntax error.

## 4. Verdict per probe

| Probe | Verdict | Note |
|---|---|---|
| p1 | VALID | Strengthened by my same-`-o` raw `cmp`. |
| p2 | VALID | |
| p3 | VALID-WITH-CAVEAT | Census figures reproduce, but the 2.0 % and 42.4 % are weak/module-weighted metrics; hard-coded env path. |
| p4 | VALID-WITH-CAVEAT | M2's warning is generic "undefined module", not dependency-specific; M3 carries the claim. |
| p5 | VALID | |
| p6 | VALID | |
| p7 | VALID (narrow) | Only offline elm.json handling; says so. |
| p8 | VALID-WITH-CAVEAT | Changed-line count doubles edits; 34/34 is regression-only (no example uses the new syntax). |
| p9 | VALID-WITH-CAVEAT | Absolute bytes and microseconds are not stable across runs (+36 vs +40; hit 3.9 vs 6.7-9.1 us). Conclusions survive. |
| p10 | VALID-WITH-CAVEAT | Stand-in `req`; proves a name-only check on a toy, nothing about real Req. |

None is CIRCULAR; none is UNREPRODUCIBLE.

## 5. Overall

**The brief is sound.** Every probe re-runs green, the controls fail in the right direction, and I could not make any headline claim go red. The corrections are about precision, not about the recommendation.

## 6. Brief claims to correct

1. `LANGUAGE.md:2946` stale: also say the doc's example at line 2944 writes `:"Elixir.Enum"`, which is a syntax error (only `:'...'` lexes).
2. "+36 bytes ... 12 to 14 per extra": say 36-40, baseline path-dependent, 4-byte alignment.
3. "`code:lib_dir/1` costs 3.9 us a hit and 3.5 us a miss": re-measured 6.7-9.1 us hit, 2.2-2.7 us miss; say "single-digit microseconds", drop the equal-cost impression.
4. "34 to 37 changed lines": state that this counts `<` plus `>` lines of `diff`, so edits are counted twice.
5. "2.0 % / 42.4 %": add the prefix figure (31.6 %), say the 42.4 % is module-weighted (5 of 6 Elixir apps are guessable; only `elixir` is not), and note module to app is derivable from the machine.
6. Mix: state that the warning text is generic (identical for a typo module) and that M3, not M2, is the evidence about dependencies. Add that probe p4 needs no hex.
7. "Req, Req.Test, Req.Request are all app req": mark as outside the probes.
8. "34/34 identical": add that no example uses the new syntax (no-regression control only).
9. Note that p3, p5 and p10 hard-code `/tmp/claude-0/mm/...` paths.
