# 32a — What Gleam's `@external` actually lowers to

Measured 2026-08-14. `local`, Gleam 1.18.1, OTP 28.5.
Source: [`32a_gleam_external.gleam`](32a_gleam_external.gleam). Run with `gleam build` and read
`build/dev/erlang/<app>/_gleam_artefacts/<mod>.erl`.

Ticket 32 proposes borrowing Gleam's syntax and refusing its semantics. This measures the third
thing, which the ticket did not ask about and which turns out to matter more: **its lowering**.

## The emitted Erlang, verbatim

Three declarations went in — a public external that is called, a public external that is never
called, and a private external that is called:

```erlang
-module(ffi32).
-compile([no_auto_import, ..., inline]).
-export([key_find/3, key_find_as_int/3, main/0]).

-file("src/ffi32.gleam", 4).
-spec key_find(any(), integer(), list(RP)) -> RP.
key_find(Key, N, List) ->
    lists:keyfind(Key, N, List).

-file("src/ffi32.gleam", 8).
-spec key_find_as_int(any(), integer(), list(any())) -> integer().
key_find_as_int(Key, N, List) ->
    lists:keyfind(Key, N, List).

-file("src/ffi32.gleam", 14).
-spec main() -> integer().
main() ->
    L = [{1, ~"one"}, {2, ~"two"}],
    _ = lists:keyfind(2, 1, L),
    erlang:byte_size(<<"abc"/utf8>>).
```

## Findings

**1. Gleam emits a wrapper where the *module's API* needs one, never where the *boundary* does.**
The three cases separate cleanly and the conclusion is forced by the private/public split rather
than inferred:

| Declaration | Visibility | Called? | Emitted |
|---|---|---|---|
| `key_find` | public | yes | wrapper **and** `-spec`; the internal call **bypasses** it |
| `key_find_as_int` | public | **no** | wrapper **and** `-spec` |
| `size_of` | private | yes | **nothing** — erased; only the inlined call survives |

A public external that is *never called* still gets a function, and a private external that *is*
called gets none. So the emitted function tracks export, not use, and certainly not the boundary.
`main/0` calls `lists:keyfind/3` and `erlang:byte_size/1` **directly**, skipping the wrapper that
exists three lines above it.

**2. The false claim is published as a `-spec`, twice, from one foreign function.** `key_find` and
`key_find_as_int` name the *same* MFA with different declared return types, and both compile. This
reproduces ticket 18's measurement (`-> Int` returning `41.5`) and adds that the language will
publish two contradictory specs over one foreign entity without complaint.

**3. Therefore Gleam's lowering does not transplant, and the reason is the semantics beam-sharp
already refused.** Inlining a foreign call at every call site is free *only because nothing is
attached to it*. beam-sharp attaches two things by prior decision — ticket 15's compiler-emitted
`try` wrapper and ticket 18's guard on the result — so the same lowering would duplicate both at
every call site. [`32d`](32d_where_boundary_code_lives.md) prices that: **~60 bytes once as a
function, versus ~65 bytes per call site inlined.**

Net for ticket 32: **borrow the syntax, refuse the semantics (already decided), and refuse the
lowering (new).** Two of the three things Gleam offers here are things to decline.

## What this does not show

Whether Gleam's inlining is deliberate or an artefact of the `inline` compile option it sets on
every module. Not chased — the effect on beam-sharp's decision is the same either way, since what
matters is that a declaration need not become a function and, for beam-sharp, should.
