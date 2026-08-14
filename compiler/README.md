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
rebar3 eunit                                    # 24 tests, all at the boundary
rebar3 escriptize
```

**There is no `;`.** A declaration ends where the next one begins; the grammar needs no terminator
and yecc reports no conflict without one. A stray `;` is the likeliest error in the language, since
both audiences type one from habit, so it gets a named diagnostic rather than a lexer tuple:

```
fib.bs:5: error: beam-sharp has no `;`
  a declaration ends where the next one begins. Remove it.
```

**Run a program.** Development is driven by runnable code, so the compiler runs one:

```
$ bsc examples/fib.bs 5
5
$ bsc examples/fib.bs 10
55
$ bsc examples/readings.bs Classify "(:ok, 7)"
:positive
```

`bsc FILE.bs [FUNCTION] [ARG...]`. The function name is optional because **under one function per
file the file names the function** — `fib.bs` holds `Fib` — with two fallbacks for files predating
that convention: an explicit name, or the only export. With no arguments at all it just compiles,
as before.

Arguments and results are in **beam-sharp** notation, and the parser accepts back exactly what the
printer emits: `:positive`, `(:ok, 7)`, `[1, 2]`. Erlang term syntax (`{ok,7}`) also works, for
shapes the surface cannot yet spell.

**Or stay in a shell.**

```
$ ibs -S examples/fib.bs
beam-sharp REPL — examples/fib.bs
  Fib/1
  :reload   recompile the file    :exports  list functions
  :quit     leave                 Ctrl-D    leave

bs> Fib(10)
55
bs> :reload
reloaded examples/fib.bs
```

`:reload` is the point of it: edit the file, reload, call again, without leaving the shell. The
REPL reads exactly one form — a call — because the parser in this slice reads declarations, not
expressions. A wider prompt waits on the surface growing an expression parser.

**Underneath, if you want the `.beam`:**

```
./_build/default/bin/bsc -o /tmp examples/readings.bs
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
- **`bs_emit:int_part/1`'s bounded branches are not reachable from the surface yet.** Intervals are
  in the algebra and the checker uses them, but they arise only from *guards*, and a guard refines a
  clause rather than a signature — so a parameter declared `int` emits `integer()` whatever its
  clauses test. The surface owes ticket 20 §5's `type Positive = int where value > 0;`. **That is
  the next slice increment.**

## Checking the emitted specs

```
./bin/spec-check.sh        # ~9 s once for the PLT, then ~0.05 s
```

Dialyzer is the tool ticket 13 §6's `-spec` emission exists for, so a wrong spec is a defect it will
name and the unit suite cannot see. The script compiles the examples, runs Dialyzer's default
warning set over the result, and then **corrupts a real emitted `.abstr` in exactly one respect** —
a wrong return type, a wrong argument type — and requires both to be caught. A clean run proves
nothing unless a wrong spec would fail it.

## Verified across the OTP range

The `.abstr` this compiler emits builds unchanged on **OTP 24, 25, 26, 27 and 28**, with the modules
callable and the emitted `-spec` byte-identical on all five — see
`wayfinder/research/13-otp-range-corpus.md`. Note the portable artefact is the **`.abstr`**, not the
`.beam`: a 28-built `.beam` is `{error,badfile}` on 26.
