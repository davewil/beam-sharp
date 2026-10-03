# Independent verification of brief 52 (dependency provenance)

Method: probes copied to scratch; prototype rebuilt from `proto52.patch` against a fresh copy of `compiler/src`;
every run.sh re-run (p03 three times); outputs diffed (tmp-dir names, pids, dates masked). Repo and original probes untouched.

## Re-run results
- p01, p02, p04, p05, p06, p07, p08 (erlang/elixir/gleam/elm), p09, p10: output identical to the captured run.out. REPRODUCED.
- p03 (timing), 3 runs. Primitives: which hit 5.4-6.9 us; lib_dir 1.6-3.0 us at all path lengths (flat). REPRODUCED.
  which miss: 42 entries 11-26 us (brief: 10), 142 entries 0.46-1.19 ms (brief 1.1 ms; captured 0.57), 542 entries 2.5-3.2 ms
  (brief 4.1 ms; captured 2.68; never seen above 3.2). The brief's 4.1 ms is not in run.out or in my runs: UNSUPPORTED number, direction right.
  In-prototype 1/20/60 blocks: module check is often +0.3 to +1.5 ms at 60 blocks, app mode similar; ordering is noisy, none exceeds the +-1-2 ms noise
  clearly; consistent with "no measurable delta, analytic ~0.4 ms".
- Own app-derivation script (python, counts .beam files rather than .app `modules`): 32.84% (445/1355) and 35.84% (148/413), 237/237 elixir-app modules missed.
  REPRODUCED (my module total is 1768 in 40 app dirs vs brief 1736 in 41; the .app-vs-beam difference does not move the percentages).

## Circularity hunt
- Patch read: Option A check is `code:which`, B is `lib_dir`+`which`+prefix test; the strip keeps `decl` a 4-tuple. Nothing tuned to produce a number. Fixtures (wrongapp, wrongname) are built to fail by design, and say so.
- "Module-only check refuses 2 corpus programs": REPRODUCED (Req, Elx rc 0 baseline, rc 1 with BS52=module and no ERL_LIBS). I also tried the 7 `exemplars/*`: all already fail to compile today (incl. 25d, which names epgsql), so excluding them from p09 is legitimate, not cherry-picking.
- p09 "21 of 21": true for the module check. The brief reuses it for B ("every program that compiles today still does"); that is true by construction (no example carries `in`, and B checks only annotated blocks). CIRCULAR as evidence for B; fine for A.
- Prototype error text "nothing here says which application provides it" is wording written into the prototype; "what the check can name" (A vs B) is a design property, not a measurement.
- 0 of 237 statistic: correct but headline-shaped. Outside app `elixir`, the Elixir rule holds for 148 of 176 (84%), so for Hex-style packages the app often IS derivable. The brief says this only implicitly. Overstated conclusion ("cannot tell a stranger what to install").
- .beam deltas: p05 B compares bsc output of annotated.bs with and without BS52=attr (924 -> 1016, +92), and plain unchanged (920 = 920): same source, with/without. C builds all variants from the same .abstr. NOT circular. The 856 vs 920 note is disclosed.
- p08 gleam step 5 uses `crypto`, which EXISTS, so it does not show "@external to an absent module compiles clean". I tested a truly absent module (`nosuch_mod_zz`): compiles clean, rc 0. Claim true, probe weak. Its "rc=$?" there is that of `head`.
- Ticket correction: (a) compiles with lib missing, fails at run time `crashed: error:undef`, trace names `Elixir.String`: REPRODUCED against the real compiler. (b) Grammar has no `[external:` attribute: REPRODUCED (`bs_parser.yrl:170` is `using atom_lit {`; no `external` in the grammar or lexer; LANGUAGE.md only mentions `@external` of Gleam). But ticket 52's text already says "something like" and ticket 32 (`32-ffi-surface.md:152`) did specify `[external: ...]`, so "what landed differs" is fair; calling the ticket's "fails at the call site with error:undef" wrong is mild, since the brief's own finding agrees it fails at run time with undef.
- Not mentioned in brief: LANGUAGE.md:157 already says "a file's `using` lines are its dependency list" for B# modules; relevant to Option C's "new construct" objection.

## Citations opened (installed sources and repo)
ssl.app:101 and :10, ssl_cipher.erl:38, debugger.app:53, bsc.app.src:5, bs_parser.yrl:170, bs_lexer.xrl:54: all match.
gleam.toml:15-16 and mix.exs:17,22 match the generated files in run.out (mix/gleam files are generated at run time, not installed sources).

## Verdicts per claim
| claim | verdict |
|---|---|
| compiles without lib; run-time undef without module/app name | REPRODUCED |
| no `[external:]` in shipped grammar | REPRODUCED |
| A diagnostic text, 0 emitted bytes, 21/21 examples | REPRODUCED |
| A refuses 2 corpus programs | REPRODUCED |
| A cost numbers (hit 5.5-6.8; miss 10us/1.1ms/4.1ms) | REPRODUCED except 4.1 ms (UNSUPPORTED; I got 2.5-3.2) and 1.1 ms (range 0.46-1.19) |
| B diagnostics, wrong app, absent app, bare -pa false positive | REPRODUCED |
| B lib_dir flat; no in-prototype delta | REPRODUCED |
| B "21 of 21 still compile" | CIRCULAR (true by construction) |
| corpus: 30 blocks, 16 dirs, 25/5, 12 of 30, 5 vs 4 annotations | REPRODUCED |
| app not derivable (32.8 / 35.8 / 0 of 237) | REPRODUCED; conclusion overstated (84% outside app elixir) |
| .beam sizes (+44, +92, +1.2 KB, +508, on_load text) | REPRODUCED |
| attribute survives from_abstr/beam_lib/module_info; OTP ignores it; .app enforced | REPRODUCED |
| neighbour table (Erlang, Elixir, Elm) | REPRODUCED (Elm registry fetch: egress 403 recorded, not bypassed) |
| neighbour table, Gleam "@external to absent module compiles clean" | REPRODUCED by me; probe itself UNSUPPORTED (used a present module) |
| UNMEASURED items (LSP, required-outside-OTP rule, Option C cost, --api, rebar manifest) | correctly flagged; no fact-claims made while unmeasured found |

## Overall
Largely REPRODUCED. Fix before relying: 4.1 ms figure, p09-for-B circularity, Gleam step-5 probe, and soften the "cannot tell a stranger" claim.
