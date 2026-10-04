# Verification of brief.md (ticket 52), independent re-run, 2026-10-04

Method: probes copied to `verify/probes/`, every `/tmp/p52` rewritten to `/tmp/v52`, fixtures rebuilt
from source (mix, rebar3, gleam), all 20 probes run, outputs in `verify/out/`, diffed against the captured
`.out` after mapping `/tmp/v52` back to `/tmp/p52`. Discrimination run: `verify/out/discrimination.txt`.

## 1. Re-run results

All 20 REPRODUCED in verdicts; none FAILED TO RUN. Differences are timings/timestamps only:
00 (timestamp), 01 (build ms), 04 (dir mtime), 10 (yecc ms; `.bs files lexed` 176 vs 166 because my copy of
the fixtures adds .bs files under artifacts/, the `from`=17 / `app`=1 counts are identical), 13 (all us/ms
figures; see claims), 14 (compile 0.51 vs 0.52 s), 21 (85.3 vs 84.8 us). 02, 03, 05, 08, 09, 11, 12, 15, 16,
17, 19, 20, 22: byte-identical after path mapping. Verdicts (undef vs "hello, bob", conflicts 6/6/6/6, +44/+60/
+64/+112 bytes, 12 diagnostics, 30 blocks/18 files/5 non-core) all match.

## 2. Prose claims

Matched by probe or source: 18 us (median 17.9-18.1 in author's runs; mine 17.9-20.6); ~0.26 ms/3 blocks cold
(author 256/225 us, mine 223/226); 0.7 s compile (703 vs mine 782 ms); 0.04% (0.26/700); first miss 2.9-13.7 ms
(author's two runs; mine 1.4 and 8.0 ms, outside the stated range, brief does say noisy); load+unload 95-163 us;
closure 1.0-1.4 ms and its false positive (`{[greeter,kernel,stdlib],[elixir,logger]}` with Elixir absent);
44/60/64/112 bytes on 852; 534-entry path; 85 us; 422 modules/890 modules/168 right/311 right/18 of 29; yecc 6->6
in all four variants; `from` x17, `app` x1, `requires` x0; 161 files/30 blocks/18 files/5 non-core/max 3;
bsc.erl:640-641; bs_parser.yrl:170-171 (rule is at 170); four match sites bs_check.erl 622, 640, 1061, 1099
(no other consumer of `{foreign,_,_,_}` in compiler/src); req.bs:37,43,69; elx.bs:13,17 (51a and 50a copies);
25d index.bs:12; crypto.app:28, sasl.app:44, inets.app:100, kernel.app:161 (OTP 28 lines confirmed);
xref.erl:1160 and :1542 (1542 is the doc entry for undefined_function_calls); bs_diag.erl:2054;
grammar.js:183-188 (brief says 183-190, harmless); gleam.toml:15-19, manifest.toml:5, mix.exs:5, probeapp.app:2;
ticket 106's `= :'get!'` alias. Nothing under wayfinder/ or compiler/ is modified (git status clean there).

Discrepancies:
- **3.9 us** (fact 11) vs captured/re-run **3.8 us** (probe 09). Trivial.
- **39.8% (fact 7) is computed with Erlang-named modules inside Elixir apps (elixir_*, 34 of 422) counted as
  "guess wrong"** (`ex_guess` returns `none` for them). Restricted to the 388 `Elixir.`-prefixed modules the
  guess is right for 43.3% (my recount). Conclusion unchanged (still not derivable) but the headline number is
  a bit unfair. The 34.9% OTP rule (`mod == app` or `app_` prefix) is a naive strawman, also fine for the
  conclusion, since Erlang has no convention to test.
- **`LANGUAGE.md:2944`** : the "not lexed yet" text is at **2946** (bullet begins 2944). The "line is stale"
  claim is overstated: it says *quoted atoms* are not lexed and its example is `:"Elixir.Enum"`, which is
  still true (probe 08 C, syntax error); only the single-quoted form lexes. The line is incomplete, not false.
- "Per using-block check ~18 us ... 0.04%" mixes warm (18 us) and cold (0.26 ms) figures; the cold figure is
  the one that is used for the percentage. Fine, stated.
- Section 1 prints every prototype diagnostic as `error:` while Recommendation 2 says the environment checks
  should be warnings; the prototype never prints `warning:`. Inconsistency in presentation, not in evidence.
- Probe 19's "stack head" and "proposed text" come from a standalone escript try/catch, not from bsc;
  bs_run.erl:94 does carry the stack to `report_run/1`, so the shape claim holds, but Option 3's printed
  `crashed: ...` line is a prototype string, not bsc output.
- Probe 15's `{:error,{:req,...}}` is `ensure_all_started(:req)` on an app that simply is absent, not a
  dependency of another app (probe 16 covers listed-but-absent, in Erlang).

## 3. Circularity audit

- 10_grammar_delta: the patch is in `10_patch.py`; conflicts counted by grepping yecc's own verbose output on
  base and patched copies; samples are parsed by the real lexer. Discriminates (base yields no `from` rule: real
  bsc on any `from` file says `syntax error before: from`, see discrimination.txt). The 0-new-conflicts claim
  counts "Conflict resolved in favor of" lines only (6 = 6 is a count, not a proof of identical conflict sets),
  and the patched grammar was not run over the corpus (brief admits).
- 12_prototype_check: `prov_check.erl` message text is hand-written (so the wording is not evidence), but
  *which branch fires* depends on real code-server state and scenario files made with `sed` from `a_ok.bs`.
  The expected outputs are captured, not typed into the .out (my re-run reproduces them). Discrimination:
  unpatched bsc, ERL_LIBS=other, with `from`/`requires` stripped, compiles all nine scenario files silently
  (typo, wrong app, absent app, no-from). c_ok and b_norequires parse unpatched and also compile silently
  (exit 0, no output). a_* and b_ok/b_unused fail unpatched with a syntax error, which is trivial
  discrimination; the stripped forms show the missing diagnostics are not already there. Not circular.
  Caveat: the Option B/C passes are written by the same author as the Option A pass, with the pass mode chosen
  per option; B's "unused requires" case depends on `owner/1` path-shape, as the brief says.
- 13_cost: `prov.erl`/`prov_check.erl` are the measured code; timing is real. No expected output hand-written.
- 19: the "proposed" function lives in the probe; it is a demonstration, not a test of bsc. Honest in the brief.
- 20: classification uses `code:which` with Elixir absent, so every Elixir module reads `not_found`; the 5
  non-core blocks are identifiable by name regardless. Files that fail to parse are silently counted as zero
  blocks (`_ -> []`); the 161 are "files globbed", not "files parsed OK". I did not find a parse failure
  that changes 30/5; I did not enumerate them.
- Probes greping their own output: none found. Hand-written .out files: none (all `.out` match fresh capture).

## 4. Citations

All cited files exist and the cited line says what is claimed, except LANGUAGE.md:2944 (really 2946, see
above). req.bs: the edited citation `req.bs:69` is correct on disk now (`Start() -> :'Elixir.Application'
.ensure_all_started(:req)` at line 69; file mtime 2026-09-30, git blame last touched Sep 29). `bs_parser.yrl:170`
is the `foreign_decl` rule line, AST at 171. `[external: elixir, app: req]` is at ticket 52 line 46; no
`[external` in compiler/src or compiler/features (confirmed).

## 5. Neighbour surveys

Gleam 14, Elixir 15, Erlang 16, Elm 17 re-run: output identical (14 differs by 0.01 s). Quoted outputs match
(`Unknown module`, `Nonesuch.Thing.run/1 is undefined`, exit 0, rebar3 xref warning, `nonesuch.app` start
refusal, Elm `MISSING DEPENDENCY`). Caveat: Elm's check is that elm.json lacks `elm/json`, which the Elm
compiler itself requires, not a general import-provenance check; reading it as "the nearest thing to the
ticket's candidate" is a stretch (the brief marks Elm inconclusive). Versions differ from the tickets' (stated).

## Verdict

PASS: all 20 probes reproduce; discrimination vs unpatched bsc; every numeric claim within noise except those
below; four match sites; corpus counts; neighbour quotes; req.bs:69 citation; repo untouched.
FLAG: (1) 39.8% inflated by counting Erlang-named modules in Elixir apps (43.3% fair; conclusion holds);
(2) LANGUAGE.md line number 2944 -> 2946 and "stale" overstated; (3) prototype diagnostics all say `error:`
vs recommendation "warning"; (4) probe 19 text is an escript prototype, not bsc output; (5) first-miss range
2.9-13.7 ms not reproduced by me (1.4-8.0 ms), noisy by the brief's own admission; (6) Elm "nearest thing"
reading is weak; (7) probe 20 swallows parse failures; (8) 3.9 vs 3.8 us.

Safe to rely on? **Yes, with caveats** (1)-(4); none changes the recommendation or an option's evidence.
