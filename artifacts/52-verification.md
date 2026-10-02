# Verification of artifacts/52-dependency-provenance.md (ticket 52 / ENG-234)

Verifier: independent session. Toolchain here: OTP 25, Elixir 1.14.0, Gleam 1.12.0, no dialyzer, no bsc.
Brief and probes were not edited. My scratch work is under the session scratchpad only.

## Overall verdict

The measurements hold. Every one of the ten probes reran green (`ALL PROBES HELD`, ~10 s), and every number I could
compare agrees with the brief, apart from two small count drifts and a timing spread (below). The weaknesses are
in the **inferences** and in **two assertions that cannot fail**:

1. p3's gate for the `-pa` / `bad_name` claim is vacuous (it passes via a different line of output).
2. Row 9 (p4, "1.2%, no rule exists") does not support the use the brief makes of it against option 3. The probe's
   own sample says the opposite for every Elixir app except `elixir` itself and `ex_unit`.
3. The recommended membership check (item 4) has a false-positive hole the brief does not mention (path
   directories with beams and no `.app`).
4. Two "the ticket is contradicted" claims in section 1 are overstated.

The recommendation (option 1, optional `in :app`, name only, warning) is **coherent but not forced by the evidence**.
The evidence establishes that a module-presence warning is cheap and sufficient to turn `undef` into a diagnostic. It
does not establish that a source-level app name is needed. That rests on the handoff argument ("stranger learns what
to install"), which is reasoning, not a probe result. The brief half-admits this in its "what would change my mind".

## 1. Rerun, row by row

| Row | Brief | My rerun | Verdict |
|---|---|---|---|
| 2 erlc silent, run `error:undef` | exit 0, empty; undef | same | CONFIRMED (and see falsification F1: also silent under 7 flag combos) |
| 3 imports chunk | `[{'Elixir.Req',new,1},...]` | same | CONFIRMED |
| 4 stock beam names no app | no key | same | CONFIRMED |
| 5 xref needs debug_info | `[]` + "Skipping ... (no debug information)" without; hit with | reproduced both by hand (erlc w/o +debug_info -> `Skipping`, `{ok,[]}`) | CONFIRMED |
| 6 lib_dir unreliable | bad_name for `-pa libC/anything/ebin`; which right in all 3 | same | observation CONFIRMED; the probe's gate for it is CIRCULAR-SUSPECT (F2); relevance PARTIAL (see section 3) |
| 7 ensure_loaded runs on_load | `ON_LOAD RAN`; which/beam_lib don't | same; exports `[{module_info,0},{module_info,1},{new,1}]` | CONFIRMED |
| 8/Measurements p2 bytes | 708 / 744 (+36) / 776 (+68) / 868 (+160) / 972 (+264) / behaviour 772 (+64) | **identical**: 708/744/776/868/972/772; words 7/13/35/65 identical | CONFIRMED exactly |
| 9 p4 | 925 modules, 11 match (1.2%), 140 of 388 | **938 modules, 12 match (1.3%)**, 152 of 938, 140 of 388 | DISAGREE on two small counts (same box; the brief's 925/11 are stale or from a different path set; the 140/388 matches). Conclusion unaffected. But see claim analysis below |
| 10 p8 | 25 files, 52 entries, 0 versions; runtime_dependencies on 19/25, none Elixir | identical | CONFIRMED |
| 11 p5 | `{req,{"no such file or directory","req.app"}}`, `mint.app` | identical | CONFIRMED |
| 12 p9 | 27 blocks, 14 modules, 3 absent (Req, epgsql, json) | identical | CONFIRMED (the probe has no assertion; it exits 0 whatever it finds) |
| 13 no env query in bs_check | no `code:`/`file:`/`filelib:` hits | I grepped: none in `bs_check.erl` | CONFIRMED. But "`code:` appears only in bs_batch.erl, bs_repl.erl" is wrong: `bs_run.erl:19-20` also calls `code:add_patha` and `code:ensure_loaded` |
| 14 undef on 50a | cited from ticket 51 | ticket 51 line 22-23 says that | CONFIRMED (cited) |
| p6 Elixir | warns `Req.new/1 is undefined`, exit 0; Logger warning only with `[]` | reproduced; also `--warnings-as-errors` turns it into exit 1 (not in brief, harmless) | CONFIRMED |
| p7 Gleam | builds clean, `'Elixir.Req':new([])`, undef; `gleam/io` Unknown module | same; 0.35 s vs the brief's 0.42 s (noise) | CONFIRMED |
| p10 timings | lib_dir 1-3 us; which 115 / 965 us; scan 11-13 ms | lib_dir 2-4 us; which 850-1371 us (4 runs); scan **12.8 / 14.7 / 15.5 / 21.9 / 25.3 ms** | AGREE within noise, but the brief's 11-13 ms is the favourable end; scan on a 4-core box ranged to 2x. Still "nobody waits" |
| p3 timings | which 115 us short path | 131 us; beam_lib exports 56 us vs brief 67-92 | AGREE within noise |

## 2. Circularity hunt, per probe

**p1 (erlc silent).** Falsifier: any warning text from erlc. I tried `-Wall`; `+warn_unused_import +warn_missing_spec
+warn_untyped_record +warn_deprecated_function +warn_removed`; `-Werror +warnings_as_errors -Wall`; `+bin_opt_info
+recv_opt_info`; `+strong_validation`; `+warn_obsolete_guard +warn_exported_vars`; `+report`. All exit 0; the only text was
an unrelated "missing specification" from `+warn_missing_spec`. There is no erlc warning for an absent remote module.
Control: the probe has none showing erlc is able to speak at all; I checked by hand that an undefined local call
(`nothere/1`) is rejected, so the silence is meaningful. xref `undefined_function_calls` and `undefined_functions` both
report it with debug_info. **Dialyzer is not installed**, so the claim covers erlc and xref only; dialyzer's "Unknown
function" warning is UNVERIFIABLE here (the brief makes no dialyzer claim, fine). CONFIRMED.

**p2 (attribute cost).** The control `m0` differs from `m1` only in the one attribute line (same function, same
export). Falsifier: size not increasing, or attribute not in `module_info`. Mutation F3 below turned it red. The probe
hand-writes `.abstr`; it does not run bsc's `to_abstr`, but `bs_emit.erl:2500-2504` serialises forms generically with
`~p`, so any attribute form survives. The brief's proposed `-bs_uses({req,'Elixir.Req'})` (two atoms) was not itself
measured; p2 measured `[req]`; the difference is one atom already present in the imports table, immaterial.
Unsupported aside: "which is why bytes exceed twice the words" compares bytes to words (different units) and was never
checked against the chunk list. Harmless prose, not a finding. CONFIRMED.

**p3 (presence checks).** Gates: `chk 'lib_dir(req)={error,bad_name}'` is a `grep` over the whole output. The control
block ("no ERL_LIBS, no -pa") prints exactly `lib_dir(req)={error,bad_name}`, so the gate is satisfied by the control
and does not test the `-pa libC/anything/ebin` case at all. Mutation F2: I renamed the libC dir to `req` (so lib_dir
should succeed there); the probe still ended `p3 fail=0`, while the visible output did show
`lib_dir(req)="libC/req"`. So the claim is true and visible in the printed output, but the gate would never have gone
red. CIRCULAR-SUSPECT for the gate; the claim itself CONFIRMED (and it is naming-based: `anything` fails, `req` works).
Is it a layout the recommendation meets? The recommendation (item 4) explicitly does not use `lib_dir`, so for the
recommendation the finding only justifies the choice of scanning `.app` files. Real layouts (mix `_build/dev/lib/req/ebin`,
rebar3 `_build/default/lib/req/ebin`, `ERL_LIBS` app-vsn) all work with `lib_dir`; `bad_name` needs a directory named
neither `req` nor `req-vsn` (a git clone named `elixir-req`, say). So "`code:lib_dir` is not a reliable test" is true but
the section 1 phrasing ("answers bad_name for a dependency that is on the path") sounds broader than the layouts that
cause it.

**p4 (module to app).** It can fail (exit 1 if >=10%). Sampling bias is real and the brief states it, but then **uses
the number anyway**: option 3's counterargument says "the module name cannot rebuild it (row 9: 1.2% match)". Two
problems:
 - 11-12 matches are almost all Erlang OTP app-callback modules (kernel, inets, mnesia, ssl...) plus `elixir`. That is
   the wrong statistic for the question. What matters for hex is the *Elixir* rule, and I computed it per app from the
   same data: lowercase-first-segment rule right for **eex 5/5, iex 29/29, logger 11/11, mix 95/96**; wrong only for
   `elixir` (1/253, because `Elixir.String` etc. belong to app `elixir`, which the rule can never get right) and `ex_unit`
   (0/28, `ExUnit` vs `ex_unit`). The 140/388 aggregate is dominated by the single app `elixir`. So the probe shows
   "no rule exists" only if one counts the core library; for hex-like apps the rule mostly holds, while real failures
   (phoenix_live_view, ecto_sql) are from my background knowledge, not from the probe.
 - Option 3 does not derive the app from the name. It reads `.app` files, so the 1.2% figure is a non-sequitur against
   it. Option 3's actual weakness (dependency absent, no `.app` to read) stands independently of p4.
 Verdict: measurement CONFIRMED (938/12 here); the use of it CIRCULAR-SUSPECT / not supporting.

**p5, p8.** p8 has a real falsifier (a non-atom entry). p5 outputs are VM behaviour. Both CONFIRMED. p8's inference to
"the BEAM's dependency vocabulary is names" covers `.app` runtime files only: `mix.exs` deps and `rebar.config` carry
version requirements everywhere. The brief's "name only because 0 of 52 entries carry a version" is therefore
supporting colour for a decision that really rests on ticket 51's "no resolution".

**p6 (Elixir; the author's unexplained "with logger still warned").** I investigated. Findings:
 - Fresh directories are deterministic: 12 of 12 fresh projects with `extra_applications: []` gave 3 warnings; 12 of 12
   with `[:logger]` gave 0. So the probe's two-directory design is sound and the contrast is real.
 - Reusing one directory is **not deterministic**: identical inputs (build with `[:logger]`, then swap to `[]`,
   `--force`) gave 3, 0, 3 across three repetitions with no changes between them, and a `rm -rf _build/dev/lib/p/ebin`
   variant gave 0, 0, 3. In-place edit sequences also failed to reproduce the author's exact symptom (my first
   `[]` -> `[:logger]` in-place swap gave 0, not "still warns"). So the cause is stale/racy incremental build state
   (the `_build` app-tracer/manifest), consistent with the author's guess, but I could not pin it to one file; I can
   only say it is not a property of the Elixir check. Practical consequence: never trust an in-place mix.exs edit for
   this check; fresh dir only, which is what p6 does.
 - "Elixir 1.14 warns but compiles" CONFIRMED: `elixirc` of a call to absent `Req` prints
   `warning: Req.new/1 is undefined (module Req is not available or is yet to be defined)`, exit 0 (exit 1 only with
   `--warnings-as-errors`). The quoted Logger text matches the real warning.

**p7.** Confirms the build/undef behaviour. The "dependency governs imports" half has no positive control (building
with `gleam_stdlib` declared needs the network), so it shows an undeclared import fails, not that declaring fixes it.
CONFIRMED, weak on the second half.

**p9 (corpus).** Count verified (`grep '^using :'` -> 27; an indented `using` grep finds none; 133 `.bs` files under
compiler/wayfinder). The script asserts nothing, cannot go red. The corpus is the repo's own examples and prototypes,
so it is self-selected; third-party usage is n=2 (`Elixir.Req` in `wayfinder/prototypes/51a-code-path/Req/req.bs:37`,
`epgsql` in `compiler/examples/exemplars/25d-database-querying/index.bs:12`). Brief's "24 of 27 blocks would not need it" is off
by one in the conservative direction: only Req and epgsql (2 blocks) need `in :app`; `json` is stdlib on the pinned OTP
28, so 25 of 27. Claim CONFIRMED with that correction.

**p10.** See timing row. Path was 36 entries; `code:which` is linear in path length, so a deps-heavy project will be
slower; the brief says so for the 36 vs short path, fine.

## 3. Citations and bsc claims

Opened each file:
 - `bs_parser.yrl:170` foreign_decl rule: correct. `:29` token `'in'`: correct. `:165` for `behaviour_decl`: actually line
   **164** (off by one).
 - `bs_check.erl:615, 633, 1054, 1092` `{foreign,_,Mod,Sigs}` matches: correct (four). No other file pattern-matches the
   `{foreign, ...}` tuple (greps of the other modules show only `foreign_*` diagnostics). The brief's own caveat that the
   other consumers were not checked stands.
 - `bs_emit.erl:75-77` (`type_atoms` export) and `:78` (behaviour attribute comprehension): correct.
 - `bsc.erl build/3`, `Options = [from_abstr, debug_info, ...]`: correct (`bsc.erl:842-843`). No line number given in the
   brief; I found no other compile call in the compiler source, so "xref works on bsc output" is supported by source.
 - Ticket 51 `scope`/"no manifest of its own": `51-a-build-and-dependency-tool.md:47`. Ticket 106 title matches the "alias
   form". `F16` exists. Ticket 65 "reserves no identifier": `65` line 19 confirms.
 - Row 1 says `ERL_LIBS` appears in "51 and 52 only". It also appears in 50 (line 20) and 67 (line 137); neither decides
   provenance, so the conclusion stands but the phrase is inaccurate.
 - Row 13's "`code:` appears only in bs_batch, bs_repl": also `bs_run.erl`. Minor.
 - Every claim about bsc is labelled "read from source" or "plan"; I found none asserted as measured. Section 7 is
   honest about this. The "compiler delta" items are plans.

Section 1 overreach: it presents "two things the ticket states that the probes contradict". (a) The ticket says "Compile
it on a machine with a different ERL_LIBS and it fails at the call site with error:undef". Read naturally ("it"
= the program) that is consistent with p1: the *run* fails. The brief's own phrasing "the compile succeeds, silently"
is a useful clarification but not a contradiction. (b) The ticket says checking "the application is on the code path is
one line"; it never says `code:lib_dir`. The brief attacks a specific implementation the ticket did not name. The
substantive point (a module-presence check is enough and cheaper) stands.

## 4. Does the recommendation follow?

Supported by evidence:
 - A module-presence warning is feasible, cheap, and does not execute foreign code (p3, p10).
 - Attribute route exists and costs ~32-36 B per entry (p2).
 - No name-to-app rule is needed for option 3 only if the dependency is installed; absence is the hard case.
 - Names, not versions, match the BEAM `.app` vocabulary and 51's no-resolution line.

Not supported / gaps:
 1. **Item 4 membership check can only fire when the app is installed**, i.e. exactly when the module-presence warning
    has already passed. It catches only "present module, wrong app name". The evidence contains no instance of that
    failure, and p9 shows only 2 of 27 blocks would even carry an app. The brief sells this as the thing no other option
    can do; it is real but speculative value.
 2. **False-positive hole in item 4.** "warn if the app is absent" scanning `*.app` over `code:get_path()` will misfire for
    path directories that hold beams but no `.app` (the `-pa` style directories bsc's own `bs_run:add_patha` produces for
    `.bs` output, loose `erlc -o` output). p9's `no_app_file` branch exists for this but the brief never reports it or
    says what the check does then. Also `code:lib_dir`-free scanning of the p10 form filters `basename == "ebin"`,
    which would skip a `-pa` dir not named `ebin`.
 3. **"A module has exactly one owning application"** is asserted as a reason for per-`using`. Not measured (p4 has the
    data to check duplicates; the probe does not).
 4. Option 3's rejection leans on p4 (see above) and on the single-file exemplar argument. The latter is a fair
    argument but is reasoning about the handoff, not measured; the audition has not been run on it.
 5. "Write cost near-free, read cost full weight" is used to price option 1; the brief concedes (counterargument)
    that it duplicates `mix.exs`/`rebar.config` with no drift check. That is the strongest rival, and "what would change my
    mind" lists it. Reasonable.
 6. The recommended spelling `in :app` was not run through the grammar (no yecc here). No LALR conflict check was done;
    `'in'` already being a token makes a conflict unlikely but it is unverified.

## 5. Falsification attempts of my own

 - **F1** Tried to make erlc speak about the absent module with 7 flag sets. Stayed silent. Claim survives.
 - **F2** Mutated p3 (libC dir renamed to `req`) -> lib_dir succeeds there, yet the probe still reports `p3 fail=0`.
   Gate cannot detect the claim it is meant to guard (the control block satisfies the grep). Gate CIRCULAR-SUSPECT.
 - **F3** Mutated p2 (`m1` given no attribute) -> sizes equal (`m0 708`, `m1 708`), `attrs=[]`, both
   `UNEXPECTED` lines print. Probe goes red as it should. Real.
 - **F4** Dropped the debug_info in p1 xref -> `[]` and `Skipping`, matching row 5.
 - **F5** p4 recomputed per app (see above): the "no rule" conclusion does not hold outside app `elixir`/`ex_unit`.
 - **F6** p6 repeated 12x per variant in fresh dirs: deterministic; in-place reuse: flaky. Explains the author's
   unexplained warning.
 - `code:which(erlang)` returns `preloaded`, not `non_existing`, so a check keyed on `non_existing` handles the 10
   `using :erlang` blocks; fine.

## Verdict list

 1. Row 2 (erlc silent; undef at run): CONFIRMED
 2. Row 3/4 (imports chunk; stock beam has no app): CONFIRMED
 3. Row 5 (xref needs debug_info; bsc passes it): CONFIRMED (source read at bsc.erl:843)
 4. Row 6 (`lib_dir` unreliable): CONFIRMED observation; probe gate CIRCULAR-SUSPECT; real-world scope narrower than worded
 5. Row 7 (ensure_loaded runs foreign code; which/beam_lib do not): CONFIRMED
 6. Row 8 + byte table (p2): CONFIRMED exactly
 7. Row 9 (p4, 1.2%, no rule): numbers DISAGREE slightly (938/12=1.3%); conclusion used against option 3 CIRCULAR-SUSPECT (rule holds for 4 of 6 apps)
 8. Row 10 (names only): CONFIRMED for `.app`; inference to the decision is weak
 9. Row 11 (VM speaks app names): CONFIRMED
10. Row 12 (corpus 27/14/3 absent): CONFIRMED; "24 of 27" is really 25 of 27; probe asserts nothing
11. Row 13 (no env query in checker): CONFIRMED for bs_check; "only bs_batch/bs_repl" DISAGREE (bs_run too)
12. Row 1 (nothing decides it): CONFIRMED in substance; "51 and 52 only" DISAGREE (50, 67 mention ERL_LIBS)
13. p6 Elixir warns-but-compiles, and Logger check: CONFIRMED (12/12 fresh dirs); in-place variance isolated as stale `_build` state, nondeterministic
14. p7 Gleam: CONFIRMED (second half lacks positive control)
15. Timings/p10: AGREE within noise (scan 12.8-25 ms, brief's 11-13 is the low end)
16. Citations: all correct except `bs_parser.yrl:165` (is 164)
17. Item 4 membership check value and false-positive on `.app`-less path dirs: UNVERIFIABLE here / gap
18. "One owning application per module": UNVERIFIABLE from the probes
19. Section 1 "ticket contradicted" claims: overstated
20. Recommendation (option 1, optional `in :app`, name-only, warning): follows as judgement, not forced by evidence; its decisive step is the handoff argument, which no probe tests

**Overall: measurements sound and reproducible; fix the p3 gate, drop or reframe row 9 against option 3, and add the `.app`-less path-directory case to item 4 before this goes to David.**
