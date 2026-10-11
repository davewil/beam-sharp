**Brief for ticket 52 (dependency provenance). A recommendation; the ticket stays open.**

Options, each run through a prototype `bsc` built from a patched copy of `compiler/src`:

- **A. Per `using` block**: `[external: elixir, app: req] using ...`, or without an attribute grammar, `using :M in req { }`.
- **B. Once per module**: `module Client in exdep, erldep`. One deduped attribute, 60-64 bytes whatever the block count.
- **C. Nothing in source**: the project file owns it (decision 51); `bsc` warns when a `using` module is not on the code path.

**Recommendation: C now.** The ticket's scenario (different `ERL_LIBS`, no `req`) is caught at compile time by `code:which/1` on the module the `using` line already names: no new syntax, about 20 us cold. mix, Erlang and Gleam all keep dependencies in the project file. Choose A (keyword form) only if the handoff must work from `.bs` source alone. Keep any check a warning: a release runs in embedded mode, where `ERL_LIBS` is ignored.

**Most surprising finding:** the ticket's claim is wrong in two ways. Compiling against another `ERL_LIBS` succeeds silently with exit 0; the failure is at run time, and `bsc` prints `crashed: error:undef` without the missing module. And `code:lib_dir/1`, the obvious presence test, keys on directory name and never reads a `.app`; `code:where_is_file("req.app")` is the right test. Gleam also builds a nonexistent `@external` module with exit 0.

Not probed: Req itself (hex blocked), rebar3 (absent), Elm past its registry failure.

Brief: `artifacts/52-dependency-provenance/brief.md`
