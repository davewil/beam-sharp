# Probes for ticket 62 (ENG-252) -- the outbound ABI

Environment: `source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh`
(done for you by `lib.sh`). OTP 29 (erts-17.1), Elixir 1.20.4, Gleam 1.19.1, repo rev 019533d.

Every probe is ONE command, run from this directory, and its captured output is the `.out` beside it.
`lib.sh` defines `bsc()` because the scratchpad `bsc` wrapper cannot take `-o` / `--src-root`
(`erl -run` swallows dashed flags); `bsc()` calls `bsc:main/1` with the same compiler ebin.
Nothing here touches `compiler/src`: the alias experiment is `alias_emit.patch`, applied to a COPY by `patch_emit.sh`.

| command | what it settles | output |
|---|---|---|
| `./01_elixir_spellings.sh` | every Elixir spelling of a call to a PascalCase export (+ controls) | 01_elixir_spellings.out |
| `./02_gleam_emission.sh` | what Gleam really downcases (variants vs functions) | 02_gleam_emission.out |
| `./03_gleam_calls_bsharp.sh` | `@external(erlang, "Abi", "MakePoint")` RUN, not just compiled | 03_gleam_calls_bsharp.out |
| `./04_erasure_table.sh` | LANGUAGE.md sec.12 erasure table vs emitted `-spec` and runtime values | 04_erasure_table.out |
| `./05_alias_cost.sh` | .beam / export table / compile time for N=1,10,50,200 x {none, forward, forward_nospec, dup} (~35 s) | 05_alias_cost.out |
| `./06_runtime_hop.sh` | BEAM asm of the alias, inlining, 1e7 and 5e7 call timing with a positive control | 06_runtime_hop.out |
| `./07_naming_rules.sh` | three PascalCase->snake rules vs real Macro.underscore / real Gleam; collision behaviour | 07_naming_rules.out |
| `./08_record_and_kind.sh` | record is a map; Kind required (re-measure of friction 2 and 3) | 08_record_and_kind.out |
| `./09_option2_from_elixir.sh` | what Elixir gets from the aliases (and the stock-compiler control) | 09_option2_from_elixir.out |
| `escript 10_otp_pascalcase_exports.escript <OTP lib dir>` | does OTP already export PascalCase functions? | 10_otp_pascalcase_exports.out |
| `ELIXIR_ERL_OPTIONS=+fnu elixir macro_underscore_src.exs` | Macro.underscore source from the installed beam's debug info | macro_underscore_src.out |

Negative controls: 01 (E1-E3: lowercase and missing function must fail), 02 (a PascalCase Gleam function
must be refused), 03 (wrong function name / missing beams must be `undef`), 04 (`{ok,_}` must NOT match,
`{error,_}` must), 06 (an extra BIF per iteration must show up as +8 ns), 07 (`new` lowercase must be a
syntax error), 08 (right tag with a missing field), 09 (stock compiler must fail every snake_case line).
