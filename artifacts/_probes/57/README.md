# Ticket 57 probes — how to re-run every measurement in the brief

All compiler work happened in `/tmp/ticket57-scratch/`, never in the tracked
`compiler/` tree. To rebuild that scratch environment from scratch:

```sh
export PATH=/opt/otp28-src/bin:$PATH   # OTP 28.5, built from /opt/otp28-src
mkdir -p /tmp/ticket57-scratch
cp -r /home/user/beam-sharp/compiler /tmp/ticket57-scratch/compiler          # baseline
cp -r /tmp/ticket57-scratch/compiler /tmp/ticket57-scratch/compiler-optA    # grammar fix
cp -r /tmp/ticket57-scratch/compiler /tmp/ticket57-scratch/compiler-optB    # checker fix
```

Apply `patches/optA-grammar-negate.patch` to `compiler-optA/src/bs_parser.yrl`
and `patches/optB-checker-fold.patch` to `compiler-optB/src/bs_check.erl`
(both are unified diffs against the ticket's baseline SHA; `patch -p3` from
each `compiler-optN` directory, or apply by hand — each is under 25 lines).

Build each copy:

```sh
cd /tmp/ticket57-scratch/compiler<SUFFIX>
rm -rf _build
HTTPS_PROXY= HTTP_PROXY= rebar3 escriptize
# escript lands at _build/default/bin/bsc
```

## repro/ — the ticket's own two-line repro, plus the guard case it doesn't mention

- `repro1` — `type T = int where value >= -5`. Refused on baseline
  (`opaque_refinement`), accepted under both optA and optB.
- `repro2` — `Sign(<= -1) -> :neg`, the pattern form. Accepted on baseline
  and on both patches (nothing here should ever change this).
- `repro3` — a guard `when n >= -5` beside a catch-all. Compiles on baseline
  (the catch-all absorbs the guard's unreadability) but the guard is not
  *credited*: run both `Sign -3` and `Sign 10` and `Sign -10` through bsc's
  run mode to see the guard evaluate correctly at runtime regardless of
  whether the checker could read it — the checker's blindness to the
  negative literal is invisible here because nothing depends on the guard's
  narrowing.
- `repro4` — the case that exposes it: two guards, `n >= -5` and `n < -5`,
  covering all of `int` between them, no catch-all. **Refused as inexhaustive
  on baseline**, despite being a genuinely exhaustive split — the same root
  cause as the refinement bug, surfacing through a different diagnostic.
  Accepted under both patches.

Invocation pattern for any of these against any built `bsc`:

```sh
BSC=/tmp/ticket57-scratch/compiler<SUFFIX>/_build/default/bin/bsc
$BSC --src-root artifacts/_probes/57/repro/reproN artifacts/_probes/57/repro/reproN/ReproN
```

(the module directory name matches the `module` line inside `mod.bs`.)

## battery/ — the "how far does it fold" probes

Ten cases, each its own directory, each run the same way as above. Expected
result, identical under both optA and optB, all measured:

| case | expect |
|---|---|
| `and_negrange` | compiles — `value >= -5 and value <= 5` |
| `or_negrange` | compiles — `value >= 1 or value <= -1` |
| `still_disjoint_ok` | compiles (baseline control, unaffected) |
| `still_neq0_ok` | compiles (baseline control, unaffected) |
| `twoplusthree_refused` | **still refused** — `value >= 2 + 3` is not a bare negated literal |
| `one_minus_two_plus_three` | **still refused** — `value >= 1 - 2 + 3` |
| `zero_minus_zero` | **still refused** — `value >= 0 - 0` |
| `value_ge_n_refused` | compiles (has a catch-all; not a real test of foldability) |
| `neg_on_float_refinement` | still refused — float refinements are out of scope of F51 entirely, unaffected by either patch |
| `guard_var_bound_still_refused` | **still refused as inexhaustive** — `n >= m`, both variables, over two guards with no catch-all; proves neither patch starts folding non-constant comparisons |

## patches/

- `optA-grammar-negate.patch` — the grammar-layer fix: one new clause in
  `negate/2` in `bs_parser.yrl`, mirroring the float-literal fold F51 already
  added. 5 lines changed (1 added clause + comment).
- `optB-checker-fold.patch` — the checker-layer fix: `comparison/1` in
  `bs_check.erl` routes through a new `int_const/1` helper that recognises a
  bare literal or a bare negation of one. 21 lines changed.

Both were built and run against the full repro/battery set above with
identical results. Both were run through `rebar3 eunit` (1053 tests) against
the full existing suite; see the brief for the three tests that fail
intermittently across baseline/optA/optB runs (pre-existing flakiness, see
F15's documented `erlang:unique_integer/1` note), not attributable to either
patch.

## Erlang precedent (cited in the brief)

- `/opt/otp28-src/lib/stdlib/src/erl_parse.yrl:301` — `pat_expr -> prefix_op
  pat_expr : ?mkop1('$1', '$2')`. Patterns and expressions share one
  production; Erlang's grammar does **not** special-case a negative literal
  pattern the way B#'s `int_lit -> '-' integer` does.
- `/opt/otp28-src/lib/compiler/src/v3_core.erl:2638-2641` — pattern
  desugaring folds any `{op, ...}` node via `erl_eval:partial_eval/1` before
  treating it as a pattern.
- `/opt/otp28-src/lib/stdlib/src/erl_eval.erl:2204-2223` — `partial_eval/1`
  and `ev_expr/1`: recursively evaluates arbitrary constant arithmetic
  (`2+3`, `1-2+3`, nested), and silently declines (via `catch`) the moment it
  hits a non-literal (a variable), returning the original unevaluated node.

## Gleam precedent

- `/tmp/lang-src/gleam/compiler-core/src/parse/lexer.rs:142-143` and
  `:1038-1050` — negative int/float literals are handled **lexically**: after
  lexing a name or number, if a `-` immediately precedes a digit, it is
  force-emitted as `Token::Minus` (so `x-1` and `1-1` read as subtraction);
  otherwise `lex_number` swallows a leading `-` into the literal. One rule,
  context-sensitive, feeding both `parse_pattern`'s `Token::Int` match
  (`compiler-core/src/parse.rs:1510-1515`) and ordinary expression parsing
  uniformly — no duplicated grammar production.

## Elm precedent (contrast, not a model)

- `/tmp/lang-src/elm-compiler/compiler/src/Parse/Pattern.hs:33-73` —
  `termHelp` has no `-` alternative at all; a pattern's `Number.number` call
  never consumes a leading `-`
  (`/tmp/lang-src/elm-compiler/compiler/src/Parse/Number.hs`, entry point
  starts on a digit, `-` only appears inside `chompExponentSigned` for
  exponents). Elm simply does not support a negative integer literal in
  pattern position — `case n of -5 -> ...` doesn't parse. B# already rejected
  that extreme by giving patterns `int_lit -> '-' integer`; Elm is cited only
  to show the asymmetry B# has (patterns yes, refinements no) is not forced
  by any neighbor's design.
