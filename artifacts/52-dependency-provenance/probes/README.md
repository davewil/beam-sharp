# Probes for ticket 52 (dependency provenance)

Everything here is runnable standalone. Environment: OTP 29, Elixir 1.20.4, Gleam 1.19.1, Elm 0.19.0
(conda env in the session scratchpad; each script sources `env.sh` itself). No network is used except
where a probe says it expects a 403 (Elm registry, hex).

Run everything (~4 min): `./run-all.sh`  (rebuilds fixtures and the prototype, rewrites every `.out`).
Run one: `./<name>.sh` (each prints its observations; the checked-in `<name>.out` is its captured output).

| Probe | Question | Command |
|---|---|---|
| p1_undef_only_at_call_site | (a) does a different ERL_LIBS fail only at the call site? exact text | `./p1_undef_only_at_call_site.sh` |
| p2_presence | (b) lib_dir vs which vs application:load vs .app `modules`, 15 edge cases | `./p2_presence.sh` |
| p2b_modes_and_transitive | (b) interactive vs embedded; ensure_loaded side effect; transitive apps | `./p2b_modes_and_transitive.sh` |
| p3a_elixir_mix | (c) mix: warning text for an undefined remote module; where mix records deps | `./p3a_elixir_mix.sh` |
| p3b_erlang | (c) erlc, `-application`?, xref, dialyzer, ensure_all_started, systools | `./p3b_erlang.sh` |
| p3c_gleam | (c) `@external(erlang,"nonexistent_mod","f")` at build time; gleam.toml | `./p3c_gleam.sh` |
| p3d_elm | (c) Elm: registry unreachable; what that shows | `./p3d_elm.sh` |
| p4_derivable | is module->app derivable from the beam + code path? | `./p4_derivable.sh` |
| p5_prototype | the three options through a prototype `bsc` | `./p5_prototype.sh` |
| m1_check_cost | (d) cost of each presence primitive, cold and warm | `./m1_check_cost.sh` |
| m2_beam_size | (d) .beam bytes of carrying an attribute (5 variants, 2 modules) | `./m2_beam_size.sh` |
| m3_pipeline_cost | (d) the prototype check inside a bsc compile | `./m3_pipeline_cost.sh` |
| m4_cli_wall | (d) CLI wall clock, stock vs prototype | `./m4_cli_wall.sh` |

Support: `fixtures/build-fixtures.sh` (builds the tiny apps: a mix-built Elixir app `exdep`, an erlc-built
`erldep`, and deliberately broken app dirs; output in `fixtures/_fx`, git-ignored), `bsc.sh` (runs the
reference compiler and forwards `--src-root`; the scratchpad `bsc` wrapper uses `erl -run`, which lets erl
swallow a leading `--src-root`), `../prototype/build.sh` (builds a patched COPY of compiler/src; never
touches compiler/src).

Every probe carries a negative control (a machine without the dependency, a function that touches no
foreign module, a beam compiled without debug_info for xref, a deliberately wrong app name, ...).
