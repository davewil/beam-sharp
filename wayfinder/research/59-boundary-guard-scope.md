# 59 — boundary guard scope: probe

## 2026-11-06 — reproduction at `631b597`

**Toolchain.** OTP 28.5 built from `otp_src_28.5.tar.gz` (the version `.tool-versions` pins);
no `rebar3` in the sandbox, so `bsc` was built by hand: `leex:file/2` with
`{error_location, column}` and `yecc:file/2` on `compiler/src/bs_lexer.xrl` and `bs_parser.yrl`,
then `erlc -I compiler/src compiler/src/*.erl` into a scratch directory, and run as
`erl -pa <dir> -eval 'bsc:main(["Guard/guard.bs"])'`. The `check-*.sh` gates were not run; they
need the rebar3 escript.

**Program.** The one in the ticket's Round 1 (`Guard/guard.bs`). It compiles and writes
`Guard.abstr`.

**Measured.**

- `Public/1` head: `#{'Kind' := 'Guard.Order'} = O`; calls `'Inner'(O)`.
- `Inner/1` (private) head: `#{'Kind' := 'Guard.Order'} = O`, body `erlang:map_get('Total', O)`.
  The private function carries the tag test.
- `PublicByte/1` guard: `is_integer(N) andalso N >= 0 andalso N =< 255` (nested `andalso`).
- `InnerByte/1` (private) guard: `is_integer(N)` only, from the clause's own `int n` head; no range
  half and no kind test of the boundary's kind.
- Calling the compiled module with `#{foo => 1}`, `300` and `1.5` at the public functions each
  raises `function_clause` at `Guard.bs` lines 7, 10, 10.

**Source.** `compiler/src/bs_emit.erl:264-294` — `guard_one/7` takes the `{ok, Tag}` branch
without consulting `Public`; only `none when Public ->` reaches the int and float guards.
`is_public/1` is `bs_emit.erl:140`.

**Not measured.** Byte cost of widening (the ticket cites 26a: +14 bytes for the tag test and 18:
+3-5 bytes for `is_integer`); not re-run here. Elixir, Gleam and Erlang were not consulted: none
of them guards a parameter from its type at a boundary, so they have no scope to compare.
