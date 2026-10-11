# Probes for ticket 60 (ENG-242), "Which modules may name this one?"

Every probe is one command, prints its observations, and its `.out` file was produced by running it
(not typed). Environment: `source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh`
is done inside each script (override with `BS_ENV=...`). Repo rev `019533d`.

`bsc2` is a 3-line wrapper around the scratch-built `bsc`. The supplied wrapper loses leading `--`
flags (`erl` swallows `--src-root`), so `bsc2` passes arguments with `-extra`. `BSC_EBIN=dir`
selects which compiler build to run (default: the unmodified HEAD build).

| Probe (one command) | Output | What it settles |
|---|---|---|
| `./a_checker_today.sh` | `a_checker_today.out` | (a) the ticket's checker claim, re-measured: no who-token exists, `internal` as a modifier is a bare syntax error, a unrelated module names any public function, three other doors besides `add_module_import` |
| `./f_unclassified_helper.sh` | `f_unclassified_helper.out` | (f) ticket 24 sec.2's `unclassified` helper under F12; public callbacks stay nameable; a test file inside the module dir reaches private functions |
| `./gleam_internal.sh` | `gleam_internal.out` | (b) Gleam 1.19.1 `@internal` and `internal_modules`: nothing enforced at compile time |
| `./elixir_probe.sh` | `elixir_probe.out` | (c) Elixir 1.20.4: `@moduledoc false`, `@doc false`, `@deprecated`, `defp`, xref, `no_warn_undefined`, and a compiler-tracer rule |
| `./erlang_xref.sh` | `erlang_xref.out` | (c) OTP 29: `-export`, `export_all`, xref as a post-build "only X may call Y" query |
| `./elm_probe.sh` | `elm_probe.out` | (c) Elm: could NOT run (package server blocked); recorded |
| `./go_internal.sh` | `go_internal.out` | extra: Go's `internal/` directory rule (the direct precedent for variant B) |
| `./rust_pub_in.sh` | `rust_pub_in.out` | extra: Rust `pub(in path)` (a per-item subtree marker) |
| `./e_prototype.sh` | `e_prototype.out` | (e) three scratch-compiler variants with negative controls |
| `./e_cost.sh` | `e_cost.out` | (e) compile-time cost (60 warm runs, 30 cold runs per build) and a corpus regression sweep |

Scratch compilers for (e) are built from COPIES of `compiler/src`; `/home/user/beam-sharp/compiler/src`
is never edited. Sources of the variants: `../patches/variant_{A,B,C}.patch` (diff against HEAD).
To rebuild: copy `compiler/src/*` to `$PROTO/base`, apply a patch into `$PROTO/<V>`, and build with
`build.sh` (leex with `{error_location,column}`, yecc, `erlc +debug_info`); the scripts expect
`$PROTO/ebin_{base,A,B,C}`. `build.sh` is saved here as `e_build.sh`.

Fixtures: `proj_a` (today's checker), `proj_f` (Cart: GenServer + private helper + test modules),
`proj_e` (variant A programs), `proj_b` (variant B programs), `gleam/`, `elixir/`, `erlang/`, `elm/`,
`go/`, `rust/`.
