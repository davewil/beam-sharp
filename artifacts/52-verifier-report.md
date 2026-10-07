# Verifier report: ticket 52 brief (dependency provenance)

Scratch: /tmp/claude-0/verify52 (p = probe copy with BSC/ROOT paths rewritten; controls and timing scripts beside it). Brief, probes, compiler/ and Linear untouched.

## Overall: PASS WITH CAVEATS

Every probe reproduces, and no circular probe was found. Caveats are the fixture's provenance, a census misattribution in E11, and cost numbers that are the slow end of what I measured. None changes the recommendation's evidence.

## 1. Probe re-runs (full `run.sh` copy, diffed against the saved .out files)

| Probe | Verdict |
|---|---|
| bsc_missing.out (P1-P5) | REPRODUCED, identical |
| xref_bsc_beam.out | REPRODUCED, identical |
| census.out | REPRODUCED, identical |
| census_tests.out | REPRODUCED, identical (89 blocks, 17 absent). My first diff showed 0 only because my own path-rewrite sed dropped a `cd`. |
| elixir.out, erlang.out, elm.out | REPRODUCED, identical (Elm: the same proxy 403, so no evidence either way) |
| gleam.out | REPRODUCED. Only build times and absolute paths differ. |
| measure.out | DIFFERS in timing only (sizes identical, see section 3) |

Not reproducible from `run.sh`: the `fixture/*/ebin/Elixir.Req.beam` was built by hand and no source or build step is saved. It is a 952 B beam exporting only `new/1`, and it returns a `Req.Request` struct map.

## 2. Claim by claim

- **E1/E2/E3 (missing module compiles, crashes with bare `undef`).** Holds. Compile prints 0 bytes on stderr, rc=0. `grep` finds no `code:which` or module-existence check in `bs_check.erl` or `bsc.erl`. The only `code:ensure_loaded` is `bsc.erl:692`, which loads the B# module itself.
- **E4 (synthetic `req`, ERL_LIBS).** I added negative controls:
  - `ERL_LIBS` pointing at an empty dir gives `undef`.
  - A layout with the beam in `req-0.7.3/` and no `ebin/` gives `undef`.
  - The mix `_build/dev/lib/req/ebin` layout resolves.
  - Pointing `ERL_LIBS` at the app dir itself also resolves, so the kernel is lenient about level. That does not hurt the claim.
  - With `ERL_LIBS` unset the call fails, so the cwd is not leaking the beam.

  The fixture exercises only the code-server path layout, not Req's own dependencies (finch, mint and so on) or app start. The brief admits it is synthetic. "Req 0.7.3" is the fixture's own vsn and I could not check it against hex. It is faithful for the layout claim and says nothing more. The "Elixir.Req" in the brief is accurate as hedged.
- **E5.** Holds. ImpT lists `Elixir.String:upcase/1`. Dbgi is 322 B and `bsc.erl:843` is `Options = [from_abstr, debug_info, ...]`. The beam's abstract_code chunk is `raw_abstract_v1`.
- **E6 (xref).** Not circular. Controls:
  - `Nope` plus Elixir's lib still flags `Elixir.NoSuchLibrary`. The module is flagged because it exists nowhere.
  - `Up` with Elixir's lib gives `[]`, and without it flags `Elixir.String`. The warning tracks path presence, not fixture design.
  - `Fetch` (compiled by me) flags `Elixir.Req` without the fixture and gives `[]` with `fixture/otp_style` as library. This is a negative control with the module present and no warning.

  The `+debug_info` caveat is real and `bsc` does pass it.
- **E7.** Probe is on target. `application:get_application` returns `undefined` before the app is loaded, and the lib_dir/.app lookup needs the dependency present.
- **E8.** Sizes are deterministic and re-ran identical (844 / +44 / +56 / +64 / +108). Caveat: `bs_requires` is injected after the module attribute in the forms, not by an actual `bs_emit` change. That is fair for a size measurement.
- **E9 (cost).** Recomputed, timing is noisy and the author's figures are at the high end:
  - `code:which` present: 21-35 us (author 35-90, one 83 us outlier in my six runs).
  - `code:lib_dir`: 1.5-3.3 us (author 1.1-3.6).
  - Combined module-in-app check: 21-31 us in six runs of `measure.escript`, and 20.5 / 22.5 / 28.6 us (min / median / max over 15 batches of 5000) in my own script. The saved run shows 61 us and my copy's run showed 30.7 us, so the spread is about 3x. "~60 us" is an upper estimate; "~25 us" is typical here.
  - Compile of the same module: author 1.5-2.1 ms single cold call; mine 1.5-2.2 ms cold (`measure.escript`), ~1.0 ms warm average (my script). "~2 ms" is the cold figure.
  - The conclusion (negligible next to compile, a 2-3% share) is unchanged.
- **E10.** Re-ran, 89 / 17. It is a textual grep, so it over-counts and would miss `using` blocks split across lines. The brief says "upper bound", which is fair. The epgsql exemplar header at line 5 reads "does not parse today".
- **E11 (minor error).** The brief says the non-OTP libraries are named "in `.bs` files: Req, epgsql, bs_front". `census.out` shows `bs_front` and `cowboy_req` only in `*.md` files (`grep -l bs_front --include=*.bs` finds nothing). `cowboy_req` is a real third-party library and is omitted from the E11 list. It does not change "demand is tiny", but the wording is inaccurate.
- **Neighbours.**
  - Gleam: holds. Negative controls: an unquoted module name is a syntax error, `erlangg` is "I don't recognise this target", and a missing function arg is a syntax error. So Gleam validates the form of `@external`. The well-formed `"Elixir.NoSuchLibrary"` compiles clean, `applications` stays `[]`, and `gleam run` dies at runtime in `Elixir.NoSuchLibrary.frob`. The claim is "no existence or dependency check", not "no validation".
  - Elixir: holds. The brief says `NoSuchLib.Thing.frob/1 is undefined...` and the probe shows exactly that. No `:crypto` warning appears, consistent with the probe.
  - Erlang: holds. `systools_make.erl` cites at 824-828 and 2386 are correct. The brief says it could not run `systools`, which is honest.
  - Elm: no claim made, none checkable.

## 3. Citations opened

| Cite | Result |
|---|---|
| `bs_parser.yrl:170` | Correct. `foreign_decl -> 'using' atom_lit '{' foreign_sigs '}'` is the single rule (lines 170-171). |
| `bs_parser.yrl:544-783` (only `'['` rules) | Correct. Lines 544/545 and 777/781/783 are the only `'['` productions. |
| `bs_parser.yrl:158-164` | Correct (behaviour_decl). |
| `bs_check.erl:622`, `{foreign,` at 6 sites | Correct. 4 in `bs_check.erl` (622, 640, 1061, 1099) and 2 in the parser (`.yrl:171`, generated `.erl:7461`). No other files match. |
| `bs_emit.erl:74-78` | Correct. Module and export attribute list. |
| `bsc.erl:843` | Correct. |
| LANGUAGE.md 2899-2945 | Correct. The section 11 heading is at 2899 and the `using` bullet list runs through 2945. |
| Ticket 32 `[external: erlang, "ets"]`, 106 `= :'atom'`, 51 "NOT closed here" | All found (32 lines 177/183, 106 line 45, 51 line 182). |
| `apply.ex:921-936` | Approximate. The format_diagnostic clause is 919-937. |
| `compile.app.ex:449`, `:20-26`, `compile.elixir.ex:174-181` | Correct. |
| `systools_make.erl:824-828`, `:2386` | Correct. |

## 4. Things the reader should know

- The Option YES delta claim "runs as today with `code:which` under `code:lib_dir`" is validated for the fixture layouts only. A real mix release layout was not probed (the brief says so).
- All "confirmed" verdicts for cost are single-machine.
