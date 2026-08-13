# bsc — the beam-sharp walking skeleton

```
.bs  →  lex  →  parse  →  exhaustiveness check  →  abstract format
     →  erlc +from_abstr  →  .beam
```

Written in Erlang, because `leex` and `yecc` ship with OTP, `merl`'s `?Q` quasi-quoting rides on
an Erlang parse transform that Elixir cannot use, and the target runtime is already installed.
Ticket 13 freed the host language; this is a choice, not a constraint.

## Running it

```
rebar3 eunit                                    # 17 tests, all at the boundary
rebar3 escriptize && ./_build/default/bin/bsc -o /tmp examples/readings.bs
erl -pa /tmp -eval "io:format(\"~p~n\", ['Readings':'Classify'({ok,5})])."
```

## The slice

Deliberately only decisions the map has **closed**:

| In | From |
|---|---|
| Multi-clause heads under a mandatory signature | 01, 04, 08 |
| `:atom`, structural open unions, `->` clauses, `&&`/`||` guards | 01, 08, 09, 10 |
| Type algebra with **exact** unions and real integer intervals | 09, 11, 20 |
| Guards credited as type operations (`n > 1` → interval refinement) | 08, 20 |
| Retained failure arm | 12 |
| Abstract Format emission with a `-spec` | 13 |

Deliberately **out**: records (26 open), angle-bracket syntax (28 open), modules and imports
(still fog), FFI, OTP behaviours, refinements, binaries.

## What it is for

Not a demo. The map's fog records **eleven measurements** the skeleton owes, several of them
numbers that would *falsify* a decision rather than confirm it. Two are now paid — see
`bench/bs_bench.erl` and the map's Decisions-so-far entry.

## Known provisional decisions

- **Names are emitted losslessly and quoted**: `Readings` → module `'Readings'`, `Classify` →
  `'Classify'`. The map's fog patch on modules and namespaces owes the real answer (bare
  snake_case, or prefixed as Elixir's `Elixir.` is); quoting pre-empts it least.
- **A variable the body never uses lowers to `_`-prefixed**, so a named-but-unused parameter does
  not draw an Erlang warning. Found by running the emitter, not by reading it.
