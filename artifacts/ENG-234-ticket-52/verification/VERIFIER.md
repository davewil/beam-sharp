# Verifier report — ticket 52 / ENG-234 brief

Reruns: `verification/<name>.rerun.out` (OTP 25.3, Elixir 1.14.0, rebar3 3.19.0, Elm 0.19.3). Author files untouched.

## Per-probe table

| probe | reproduced | diff vs recorded | notes |
|---|---|---|---|
| a_undef | yes | identical | Real erlc/escript/elixir run. H3 (Elixir message) is printed, not asserted. |
| b_check_cost | yes (all ok lines) | timings differ | Rerun: which-present 656 us (then 238/218/280 in 3 more runs), which-absent 2812 us (then 1755/2195/2547), lib_dir 10.3, consult 950, get_key 1.5, unload+load 981. Absent-cost order of magnitude (about 2-3 ms, range 1.8-2.8) and ranking agree; the 290 us and 612 us figures are single-run and move about 2x. The brief's "2,801 us" is the top of the observed range, not a typical value. |
| c_app_files | yes | identical | rebar3 xref warning, mix warning, `mx.app` contents, direct xref call all reproduce. |
| d_elixir_tracer | yes | identical | Warning text and the silencing by `extra_applications: [:eex]` reproduce. |
| e_elm | yes | identical | 403 and MISSING DEPENDENCY reproduce. Tests nothing about the stated hypotheses (see below). |
| f_attr_cost | yes | deltas identical (+32/+52/+48, Attr chunk 40/70/90/81); absolute file sizes differ (808 vs 652 B: tmp path length is embedded); compile medians 2345 vs 2187 us (m0/m3) here, 3115/3287 recorded | Order flips between runs, consistent with "inside noise". |
| g_owning_app | yes | identical | |

## Extra checks I ran

- Mix source lines (from shipped beams' debug_info): `compile.app.ex` `handle_extra_applications/2` line 342, `apps_from_runtime_prod_deps/2` 354, `project_apps/1` 395. All correct. The brief says tracer lines were "unrecovered": they are recoverable, e.g. `application_tracer.ex` `format_warning/1` line 173, `warnings/1` 103.
- debug_info: bsc compiles with `debug_info` (`compiler/src/bsc.erl:843`), the probe used `+no_debug_info`. I rebuilt with default debug_info: still +32 B (one app) and +52 B (three). The brief's number survives, but the probe does not match bsc's real option and the brief does not say so.
- Preloaded set: `zlib`, `init`, `erl_prim_loader`, `prim_file`, `erts_internal` also return `preloaded`. The "special case" is a class, not only `erlang`.

## Citations

- `bs_parser.yrl:170` correct. No attribute production (grep of attr/attribute empty): correct.
- `bs_check.erl` :620, :636, :638, :1076: all correct.
- LANGUAGE.md section 11 `using :lists` (line 3100): correct.
- `.tool-versions` erlang 28.5: correct. 51a bindings: `Elx/elx.bs` 2 `Elixir` blocks (both elixir), `Req/req.bs` 2 (Req, Application): correct (req.bs also has a third `using :maps`, so "2 blocks for 2 apps" counts only the Elixir ones, as stated).
- Tickets 50 (resolved 2026-08-26), 106 (resolved 2026-09-25, `= :'get!'` syntax present): correct.
- **WRONG / UNVERIFIABLE: "ENG-440, RECORDED"** (brief line ~202). `git grep ENG-440` finds only the brief itself. No repo file carries it, so the sibling-file-`using` claim has no source I can check. It may live in Linear; as written it is a citation to nothing in the repo.
- "bsc cannot be built here (OTP 27 leex error_location)": not probed. The F35 doc mentions `error_location` but no OTP-27 requirement; plausible, unverified.

## Weak or circular probes

1. **e_elm.sh: cannot decide either hypothesis.** H1 (undeclared-package import) and H2 (versions recorded) are never exercised: the fixture has an empty `elm.json`, so Elm stops on `elm/core` first. The brief admits "partial", but the probe index says "partial" while the probe has zero bearing on any option. Treat Elm as no evidence.
2. **b H6 and the "wrong app is refused" claim is a fixture tautology.** `AppOf` derives the app from the directory name the author created (`otherapp-1.0.0`), then asserts `=/= "fakereq"`. It cannot fail. The brief caveats name-vsn convention, but the "(measured derivable)" label on the error row of the Option 2 table overstates it. The `.app` `modules` lookup, the authoritative route, is never exercised as module-to-app.
3. **b H1 "not loaded" and f "round-trips without loading" are near-vacuous**: the module was never loaded by anything in the script, so `is_loaded =:= false` cannot fail unless beam_lib/which loaded it. True and cheap, but weak.
4. **g_owning_app: expectation vs "Surprise".** Run1 shows `erlang` expected `preloaded` before the fix, so the author already knew; calling it a "Surprise" and "falsified/fixed" is narrative. The header's "expectation written beforehand and not changed" is unverifiable (no timestamps/VCS; the .sh was edited after run1). The `Elixir.Req -> absent` row holds by construction (ERL_LIBS points only at the elixir dir). H1 ("exempt exactly kernel/stdlib") only tests 2 modules; `started at boot` is read inside an escript, not inside bsc, which may have other apps started.
5. **c_app_files: "name only" is overgeneralised.** The probe shows only that `.app` files list names. `rebar.lock`, `mix.lock` and `mix.exs` deps requirements do carry versions and were not examined (rebar fixture has `{deps, []}`). The Mix-with-version case measured only `dep1` as a path dep. "Mix and rebar3 (MEASURED) record names only" is true of the generated `.app`, not of the toolchains.
6. **"Every neighbour that checks this at compile time checks the name only"** (brief, sub-decision 2): measured for exactly one neighbour (Mix). Elm unmeasured, Gleam unavailable. Not a probe-backed generalisation.
7. **Timing claim in H5 text**: "`~0.3 ms` per present module" is within the observed 0.22-0.66 ms but cost is one machine and one warm loop; the doc says so.
8. Option-2 error/warn table rows (module found under another app, absent -> warning, no-`from` -> error) are design, not measurement; only "derivable" is probed, and only via fixture directory names.
9. f compile-time: author correctly declines to claim a delta. Fine.

## Claims with no probe

- "Mix makes the same choice (warning, not error)": supported by d, yes. "Option 1 cannot offer diagnostic": reasoning, not probe, but sound.
- Hypotheses H1-H6 in b were declared in the script header, written before output as far as can be judged; I found no after-the-fact hypothesis other than possibly g (item 4).
- No label is wrongly MEASURED except: "(measured derivable)" for wrong-app detection (item 2), and "Mix and rebar3 (MEASURED) record names only" (item 5). All `bs_check`/parser statements are correctly labelled RECORDED.

## Verdict

Stand: erlc emits no diagnostic and failure is run-time `undef` (a); `code:which` finds without loading, absent costs about 2-3 ms and present about 0.2-0.7 ms on 40 entries (b, softened to a range); rebar3 xref reports the absent module and nothing reports an undeclared application (c); Mix warns by app name, silenced by `extra_applications`, absent module gets a different warning (c, d); beam attribute costs +32/+52/+48 B and is readable without loading, also with debug_info (f, my check); owning-app of `lists/ets/crypto/ssl/inets/String` and the `preloaded` atom (g); all parser/checker/Mix line citations except ENG-440.

Soften: (1) "name-only is what every neighbour does" to "what Mix's `.app`/tracer does; Elm and Gleam unmeasured; lock files carry versions"; (2) wrong-app detection: drop "measured", say "derivable from the directory convention in a fixture I built; `.app` modules lookup not exercised"; (3) cite ENG-440 properly or mark as unverified; (4) the 2.8 ms figure as "about 2-3 ms"; (5) `preloaded` is a class of erts modules, not just `erlang`; (6) Elm: state that the probe tests neither hypothesis. The recommendation (Option 2, no version) rests on design judgement plus Mix evidence; nothing measured contradicts it, but the measured evidence does not discriminate between Options 2 and 3.
