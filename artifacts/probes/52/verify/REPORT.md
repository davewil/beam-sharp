# Verifier report, ticket 52 brief (independent re-run, 2026-09-29, HEAD 51bfb6f, OTP 25)

## Verdict
Reproduced 35 PASS / 3 FAIL (P2b, P3b, P6a) from a clean TMPDIR (`rerun-output.txt`). The three FAILs are honest:
each greps for output the author said, in the file header, it expected before the run; the run.sh lines are annotated
"expected to FAIL", and I confirmed the real behaviours by hand (lib_dir matches dir names; hex-less mix stops at
"Could not find an SCM"; Elm fails on a local outline check first). P2-E6 fix did not manufacture a pass: awk fields
($4 lib_dir, $5 which) match the printed `TIME name [unloaded] min N us` layout; in my run 1.957 us vs 383 us (~196x).
Minor: probe.escript header says "100x or more", run.sh asserts >=50x, and the brief says 50x. The loosened threshold
was not needed (250x author, 196x mine) so it did not change the outcome, but the stated expectation drifted.

## Per probe
- P1a-d REPRODUCED (real bsc.sh = HEAD ebin; also rebuilt an unpatched copy from HEAD compiler/src: Absent -> `crashed: error:undef`).
- P1e-h REPRODUCED. Mutations below show they can fail.
- P1i REPRODUCED and NOT vacuous (mutation M3). Scope gap: it excludes compiler/examples/exemplars and wayfinder prototypes.
- P2-E1..E5, P2b-2, P2c REPRODUCED. P2b FAIL honest. P2-E6 REPRODUCED (see above).
- P3a, P3a2, P3c, P3d1-3 REPRODUCED. Independently re-did P3a in my own mix project: exit 0, `applications,[kernel,stdlib,elixir,logger,nope_app]`, ensure_all_started -> {error,{:nope_app,{'no such file or directory','nope_app.app'}}}.
- P4a-d REPRODUCED. My own xref: without debug_info `{ok,[]}`, with `{ok,[{{caller,f,0},{nope_mod,count,1}}]}`. Weak spot: P4b "nothing checks it" is only evidence of absence (no tool complained), not a probe of every reader.
- P5a-c REPRODUCED; my own project: `import gleam/json` -> `error: Unknown module`, exit 1; `@external(erlang,"Elixir.Nope",...)` builds, exit 0. Caveat: offline, "module in no declared package" cannot be told from "module exists nowhere", so P5c shows "unknown module", not "undeclared package".
- P6a FAIL honest; P6b REPRODUCED but weak (`! grep http` of filtered output; falsifiable only by the presence of "http"; real content is PROBLEM LOADING PACKAGE LIST + exit 1).
- P7b REPRODUCED but see timing note. P7c REPRODUCED.
No probe greps for text only the author's own script prints, except P2c/P4/P5 asserting on captured output of author scripts that read real tool state (acceptable). No CIRCULAR-SUSPECT found.

## Mutation tests (scratch: scratchpad/v52; nothing under compiler/ or the author's probes touched)
- M1 module on the code path: `using :loosemod` (a bare beam, in a dir not shaped `<app>/ebin`, added with -pa). Patched compiler refuses without -pa (diagnostic text), compiles with -pa (diagnostic gone); unpatched gives `crashed: error:undef`. So B checks only code:which, not app layout.
- M2 revert patch (unpatched copy from HEAD sources): Absent compiles, then `crashed: error:undef`. Undef returns.
- M3 patched copy that treats `erlang` as non_existing: P1i loop gives bad=4 (Foreign Interop Label Names) vs bad=0 for the real patch, of 21 dirs. The check can fail.
- 25f: patched `bsc --src-root . 25f-llm-evaluation-client/index.bs` from compiler/examples/exemplars prints `index.bs:44:1: error: `using :json` names a module that is not on the code path`, exit 1. NOT backed by any author probe (brief asserts it; P7c only shows json non_existing). Note HEAD itself refuses that invocation earlier (`module Support.Triage does not match its directory`), so 25f is not compiled by this route at HEAD; how exemplars are normally built was not checked.

## Independent checks
- (a) REPRODUCED: `using :'Elixir.Nope'` compiles (exit 0), dies at the call with error:undef.
- (b) REPRODUCED: `[external: elixir, app: req] using :'Elixir.Req' {...}` -> `syntax error before: '['`. bs_parser.yrl:170 is the foreign_decl rule; '[' appears only at lines 32, 544-783 (patterns, list/comprehension exprs); no "attr" in the grammar. Line 178 foreign_sig has no `=`.
- (c) Timings, unloaded VM, load average ~10 on the host (noisy). lib_dir(stdlib) N=20000x15: min 2.09/2.09/2.59 us, median 2.17-2.81; lib_dir(nope) min 1.74-1.82 us. REPRODUCED (~2.2 us).
  code:which on an unloaded module is NOT a constant 0.5 ms: `zip` (stdlib) min 97-108 us, median 110-130 us (first call 224-319 us); `Elixir.Enum` (36-dir path, ERL_LIBS) repeat min 395-594 us, median 448-728 us, first call 621-1451 us; a miss (`Elixir.Nope`, 30 dirs) min 523-599 us. So 0.5 ms is a warm repeat figure for an Elixir module or a miss, and it is not a cold-first-call artefact (the cold first call is 1-2x higher; one 6.3 ms first call seen under load 9.6, an outlier). Brief §4 does say "scales with path length", but its headline "0.5 ms on an unloaded module" overstates the cost for OTP modules and understates a cold outlier. Loaded module: which(lists) 1.9-2.6 us. Conclusion "<= 1 ms, cost is not the objection" stands.
  Also: escript itself has `sofs` loaded already (plain erl does not), and `xmerl` is in /usr/lib/erlang/lib but `xmerl_scan` is non_existing on the path, so P7b's 8-module list includes at least one miss (xmerl_scan); harmless to the assertions checked (zip, ets).
- (d) REPRODUCED all three: Gleam undeclared/unknown import error; mix extra_applications not checked at compile; xref silent without +debug_info.
- (e) RECOUNTED: 30 `^using :` blocks in 18 .bs files outside artifacts/; by module: erlang 13, maps 4, gen_server 2, string/lists/file/ets/binary 1 each = 24 OTP; json, epgsql, 'Elixir.String', 'Elixir.Req', 'Elixir.Enum', 'Elixir.Application' = 6. `ls -d compiler/examples/*/` = 22 incl. exemplars, so 21 example dirs. Citation error: the four Elixir.* blocks are all in wayfinder/prototypes/51a-code-path (Req/req.bs:37,43; Elx/elx.bs:13,17); nothing in a "50a" prototype. epgsql is exemplar 25d (index.bs:12), json is 25f (index.bs:44).
- (f) Citations: ticket 106 alias `term GetOrCrash(binary url) = :'get!'` at 106-a-using-alias.md:45,87, resolved 2026-09-25 OK. LANGUAGE.md:157 OK. bs_check.erl:4346 is the comment "Qualified calls still require a `using` entry..." (loose paraphrase, fine). Ticket 32 "the declaration carries both spellings" is at 32-ffi-surface.md:138 (brief gives no line; fine) and `[external: erlang, "ets"] module Ets` at :334 OK. Exemplar 25f `using :json` at index.bs:44 OK; json missing on OTP 25 (code:which = non_existing) OK; OTP 27+ json: not measured. check-language.sh is compiler/bin/check-language.sh (claim of :32 is roughly the "diagnoses" header at ~30-32; the brief gives no directory). bs_check.erl lines 325, 353, 615/633/1054/1092, bs_parser 170/178, grammar.js:183 all match. Patch is exactly 16 added lines.

## Errors and unbacked claims in the brief
1. WRONG: §5 Option B evidence says "All 55 built/2 diagnostics ... severity => error; a warning class does not exist, so 'warn, don't refuse' is a new mechanism". A warning class exists: bs_check.erl:3737,3739,3741,3767,3821 emit `{warning, L, Fn, Detail}`; bs_diag.erl:694 (`built(Path,{Sev,...}) when Sev =:= error; Sev =:= warning`) and message clauses at 1017, 1024, 1033 print `warning:`. (Also "55" counts `severity => error` occurrences; there are 127 `built(Path` clauses.) Whether declared/4, which raises, could emit a non-fatal warning was not checked; the claim should read "no warning exists for foreign declarations yet".
2. Unbacked by a probe: patched compile of 25f prints the json refusal (I reproduced it by hand, above); "no computable module->package map" (brief marks not measured); P4b "nothing reads it".
3. Gap in P1i "no false positive": excludes exemplars. Under B (strict), exemplars 25f (json, OTP 25) and 25d (epgsql, third party, non_existing per P7c) and the 51a prototypes (Elixir.Req etc.) would be refused on any machine without those deps, so any gate that compiles them (verify.sh) would need ERL_LIBS. The brief cites 25f only; 25d and the prototypes are the same case and not mentioned.
4. Recommendation step 2 (lock derivation from beam path): P2c derives from `<app>/ebin/<mod>.beam` layout only. M1/P2b show a bare beam dir has no app; escripts/archives/rebar `_build` layouts not probed. "Shown, not built" is disclosed; add "layout-dependent".
5. Recommendation "strict mode only" placement was not built (disclosed in §7). It also leans on the assumption that strict is the mode `bsc` compile uses and lenient the --api/editor path (bs_check.erl:353 shows exports_of uses lenient; fine).
6. Expectation drift: P2-E6 100x (probe header) vs 50x (run.sh/brief); P4c header notes a post-hoc edit ("discovered on first run") and 3d/6b expectations were written after 3b/6a failed. Disclosed in the files.

## Is the recommendation supported?
Mostly. Evidence solidly supports: (d) needs no syntax (P1, M1); the check is 16 lines and cheap (<= ~1 ms/module); C's grammar does not exist; neighbours check manifests not code path (P3, P4, P5). Not supported as stated: "a warning class does not exist" (false), and the claim of no false positives (scope limited to 21 non-exemplar dirs; exemplars 25d/25f would be refused). The environment-dependent-verdict objection is real and the brief states it; nothing in the probes resolves it, so recommendation 1 rests on judgement (spec sentence), not evidence. Recommendation 2 (lockfile) is an unbuilt proposal supported only by P2c on a conventional layout.

## Files
Author's: artifacts/52-dependency-provenance.md, artifacts/probes/52/. Mine: artifacts/probes/52/verify/{REPORT.md, rerun-output.txt, which-cold.escript (zip; edit module name for others), which-enum.escript}. Scratch mutants: scratchpad/v52/{m2,m3,m1}.
