# Independent verification of artifacts/52-dependency-provenance.md

Reran p1-p4 in fresh shells (PATH otp27 first, then /tmp/tools). Patched bsc built by me from `git archive HEAD compiler`
+ the patch + `rebar3 escriptize` (own mktemp dir). Raw reruns: `rerun123.txt` (pre-existing tracked file, restored after I
accidentally overwrote it; my p1-p3 run was not saved separately, its output matched), `v2_rerun4.txt`.

## Claim table
| Brief claim | Verdict |
|---|---|
| p3: ERL_LIBS holds req -> `(:req, [])` exit 0; empty -> `crashed: error:undef` exit 1; compile alone exit 0 silent | REPRODUCED |
| Erlang erlc silent exit 0, run-time undef; xref reports `{{e,f,0},{'Elixir.Req',new,1}}` | REPRODUCED (note: p1 ran under OTP27 erl on my PATH; brief says OTP 25. Behaviour same) |
| Elixir warning text, exit 0; `@compile {:no_warn_undefined, Req}` silences | REPRODUCED |
| Gleam `import` of absent module = error `Unknown module`; `@external(erlang,"Elixir.Req",..)` silent exit 0 | REPRODUCED |
| Elm not measured | REPRODUCED (elm stops at "elm/core" MISSING DEPENDENCY; brief is honest) |
| p2: code:which present gives beam path, lib_dir gives app dir, .app vsn "0.7.3", absent = non_existing / {error,bad_name} | REPRODUCED |
| p2 costs: which present ~195us, absent ~1.5ms, lib_dir 1.7-3.7us, ensure_loaded 76ns | DIFFERS in magnitude for one number: under OTP 27 I got 43us / 0.5ms / 2.6-2.9us / 32ns. Present-which is 4x lower, still "sub-ms, once per using block". Order-of-magnitude conclusion holds. Brief says OTP 25, but p2 uses whatever `erl` is first on PATH, so the script does not pin the OTP it claims. |
| "no direct which-app-owns-module call; path parse" | NOT CHECKABLE as negative; plausible (code:which returns path; p2 only demonstrates that). |
| p4: 27 modules, 0 flip | REPRODUCED (all 27 compile at HEAD; verified) BUT see circularity C1 |
| p4: 9 distinct foreign modules, 8 present, epgsql absent | REPRODUCED (9 = erlang,maps,gen_server,lists,json,file,ets,epgsql,binary). |
| "On OTP 25 json would also be absent" | REPRODUCED (system erl 25: code:which(json) = non_existing) |
| 25d "does not compile in checked-in layout: no `module` line" | REPRODUCED (both HEAD and variant) |
| Patch is "15 lines in bs_check.erl and bs_diag.erl" | REPRODUCED-ish (9 added in bs_check, 5 in bs_diag = ~14-15) |
| `--api` today skips unknown imports (bs_check.erl:490 area) | PARTLY: the comment at bs_check.erl:480 says "refuses unknown imports; `--api` skips them". That is about `import`, not `using`. Nothing measures `--api` on a `using` of an absent module on HEAD; I did: HEAD `--api` prints the module signature fine with no ERL_LIBS (so "--api compiles with nothing built" holds). |
| Patched build refuses (error `using 'Elixir.Req' names a module that is not on the code path`) | REPRODUCED by my own control, not in the brief's probes: variant, ERL_LIBS empty -> error, exit 1; with ERL_LIBS -> exit 0. Variant `--api` also prints the error (exit 0 on the pipe I used, so it is not clear the exit code is nonzero; do not assume). |
| "No neighbour records an application name in the source file that calls into it" | DIFFERS: Erlang `-include_lib("kernel/include/file.hrl")` names the application in source, and erlc errors when absent (verified: `can't find include lib "nonexistent_app/include/x.hrl"`, exit 1). Elixir `Mix.install([...])` in a script also names deps in source (I could not verify; it hung on network). The statement is true only for remote calls/`@external`, not for the language ecosystem as a whole. |
| "Sources for Elixir/Gleam not installed" | not checkable, harmless |

## Circularity / probe-quality findings
- **C1 (material): the 0-false-positive result is near-vacuous.** Only 4 of the 28 non-exemplar .bs files contain any
  `using :Mod` block (Foreign, Label, Names, Interop), and the modules they name are `erlang`, `file`, `lists`, `ets`
  (all in kernel/stdlib, always present). So "0 of 27 flip" is guaranteed by what the corpus contains; it says the patch does not
  break stdlib FFI, not that it has no false positives. The only foreign module outside OTP in the whole corpus is epgsql
  (an exemplar that cannot compile) and json (OTP 27 only). The brief's phrase "no false positives on code that compiles today" is
  true but should not be read as evidence about real third-party use. Also the probe has no positive control; I added one
  (variant refuses the Elixir.Req fixture with empty ERL_LIBS), so the check does fire.
- **C2 (minor): p3's fixture is hand-made** (`Elixir.Req` is a 1-line erlang module standing in for a real Hex package). It
  proves the mechanism (undef at run time, silent compile) which is not in doubt, nothing about real Req. Also no corpus example uses
  an `Elixir.*` module at all.
- **C3 (minor): p2's timing "present vs absent" isn't a controlled comparison** of what a bsc check would pay; the absent case scans the
  path of the fake ERL_LIBS plus OTP libs and varies with install size. Order-of-magnitude only. p2's OTP depends on PATH (see above).
- **C4 (probe hygiene):** p4 writes the shared file `/tmp/foreign_mods.txt`, so concurrent runs would collide; its grep only counts
  line-initial `using :` so indented blocks would be missed (none exist today; I checked with `^\s*using`). The `for d in $(find ...)` loop
  is fine (no stdin consumption; the erl call has `</dev/null`). p4 does not test `exit` flips in which HEAD also fails, but all 27 compile at HEAD.
- No patch text is probe-specific; the patch is generic. Patch exempts modules in `World` (compiled in this invocation), which is the
  right design and is not what makes the result.
- Unbacked claims: the `--api` warning half (acknowledged in Caveats); "a handoff manifest is a better home" (opinion); the delta
  descriptions for Option B (parser has no `in` clause, consumers of the `{foreign,...}` tuple) were not probed. I did not check them.

## Corrections the brief needs
1. Replace "No neighbour records an application name in the source file that calls into it." (twice: survey paragraph, Option B
   counterargument "no neighbour makes a source file carry") with:
   "No neighbour's *call-site declaration* (Erlang remote call, Gleam `@external`, Elixir alias call) records an application name;
   Erlang's `-include_lib(\"app/include/x.hrl\")` does name the application in source, and erlc refuses when it is absent (measured)."
2. Replace "no false positives on code that compiles today" in the Recommendation with:
   "no false positives on the repo's examples, but the only foreign modules those examples use are OTP's own (`erlang`, `file`, `lists`,
   `ets`), so this tests nothing about third-party modules."
3. In "False positives": add after "0 flip to refused": "(only 4 of the 28 example files contain a `using :Mod` block, all on OTP modules)".
4. Cost bullet: add "On OTP 27 the same script gave ~43 us present / ~0.5 ms absent; the script uses whichever `erl` is first on PATH."
5. Caveat on `--api`: change "`--api` today skips unknown imports (bs_check.erl:490 area)" to "`--api` skips unknown *imports*
   (bs_check.erl:480); for `using` blocks on HEAD, `--api` also succeeds with nothing built (measured), and the patched build prints the
   error in `--api` mode too."
