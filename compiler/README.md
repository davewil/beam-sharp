# bsc — the beam-sharp walking skeleton

```
.bs  →  lex  →  parse  →  exhaustiveness check  →  abstract format
     →  .abstr on disk  →  compile:file from_abstr  →  .beam
```

The last step is the Erlang compiler, in-process, reading the `.abstr` file `bsc` just wrote — the
same `compile` module and the same `from_abstr` reader `erlc` runs, without `erlc`'s own VM boot per
module (ENG-314, 2026-09-03; that boot was two thirds of a block's cost in the gates). Its report
reaches stderr under a `compile:` prefix. Ticket 13's obligation — the forms are the contract, and
`.abstr` plus an external `erlc +from_abstr` must always work — is unchanged, and `spec-check.sh`
still runs the real `erlc` over the real `.abstr`.

Written in Erlang, because `leex` and `yecc` ship with OTP, `merl`'s `?Q` quasi-quoting rides on
an Erlang parse transform that Elixir cannot use, and the target runtime is already installed.
Ticket 13 freed the host language; this is a choice, not a constraint.

## Running it

```
rebar3 escriptize                               # FIRST — several tests drive `bsc` itself
rebar3 eunit                                    # the suite, all at the boundary
```

**The order matters.** Tests that drive the CLI resolve `_build/default/bin/bsc`, so running
`eunit` on a fresh checkout fails on them. CI had the two steps the other way round and one of
those tests guarded itself into never running at all; both are fixed, and this is the order.

**There is no `;`.** A declaration ends where the next one begins; the grammar needs no terminator
and yecc reports no conflict without one. A stray `;` is the likeliest error in the language, since
both audiences type one from habit, so it gets a named diagnostic rather than a lexer tuple:

```
fib.bs:5: error: beam-sharp has no `;`
  a declaration ends where the next one begins. Remove it.
```

**Run a program.** Development is driven by runnable code, so the compiler runs one:

```
$ bsc examples/Fib 5
[0, 1, 1, 2, 3]
$ bsc examples/Fib 10
[0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
$ bsc examples/Readings Classify "(:ok, 7)"
:positive
```

`bsc [--src-root DIR] [--diagnostics term] PATH [FUNCTION] [ARG...]`, where **`PATH` is a module — which is a
directory** (ticket 13 §3). Naming one of its files works too and means the same thing, since a
file names the module it belongs to.

The function name is optional because **the module names the function** — the `Fib` module holds
`Fib` — with two fallbacks: an explicit name, or the only export. With no arguments at all it just
compiles, as before.

`--src-root` says where the tree is rooted, which is what ticket 41 §5's check compares a `module`
declaration against. It defaults to the module directory's own parent, so a single-segment module
never needs it; a dotted one does, because `module Shop.Reports` lives at `Shop/Reports`:

```
$ bsc --src-root examples examples/Shop/Reports Restate 3
9
```

`bsc --batch MANIFEST RESULTS` runs many invocations in **one VM**. Each entry of the manifest is
`entry ID`, an optional `cwd DIR`, one `arg TEXT` line per argument and `end`; for each, the batch
writes `RESULTS/ID.stdout`, `.stderr`, `.output` (both streams in the order they were written, as
`2>&1` would deliver them) and `.status`. It exists for the gates: `check-language.sh` compiles
fifty-odd blocks and `check-tour.sh` replays fifty-odd transcripts, and each used to be a VM boot.
An argument is one line, so nothing is quoted and nothing re-parses a command line — a transcript
saying `; touch pwned` reaches the compiler as arguments. A malformed manifest runs nothing and
names its line; `--repl` is refused in an entry, since a batch has no stdin to hand a prompt.

```
$ printf 'entry fib\narg --src-root\narg examples\narg examples/Fib\narg 10\nend\n' > m
$ bsc --batch m out && cat out/fib.stdout out/fib.status
55
0
```

`--diagnostics term` publishes the diagnostic as a **term** on stdout, alongside the prose that
still goes to stderr. Ticket 23 §1 decided that the diagnostic *is* a term and the prose is a pure
function of it — so this is not a second rendering that could disagree, it is the value the message
was computed from:

```
$ bsc --diagnostics term Rank 2>/dev/null
#{tag => inexhaustive,severity => error,line => 1,function => 'Rank',
  file => "Rank/Rank.bs",
  heads => #{kind => products,products => [[[":amber"]]],
             pasteable => ["Rank(:amber) -> ..."]},
  residual => "(:amber)"}
```

The module in that example is not in `examples/`, and cannot be: everything there must compile,
and this one deliberately does not. `pasteable` is the clause you must write. The compiler synthesises the **head** and never the body
(23 §2): a head is derived from the residual and cannot be wrong, where a body is a guess. Where a
residual cannot be expressed as a head the term says so and offers nothing, rather than handing
back an approximation that reads as actionable.

**One descriptor per line.** A file with two inexhaustive functions prints two of them, and the
newline is the frame — so a consumer reads a line and parses it, and never has to match brackets to
find where one ends. It is not available under `ibs`, and that is a refusal rather than a silent
fallback: the prompt prints values on stdout, so the flag's own contract could not hold there.

**The term is full fidelity and the prose is not.** The prose stops at three cases and prints
`... (2 more)`, which is ticket 43's cap; the term carries every one of them. That is deliberate
and is why the residual travels as its parts.

Arguments and results are in **beam-sharp** notation, and the parser accepts back exactly what the
printer emits: `:positive`, `(:ok, 7)`, `[1, 2]`, `{Kind = :'Shop.Order', Id = 1, Total = 0}`.
Erlang term syntax (`{ok,7}`) also works, for shapes the surface cannot yet spell.

**Arguments are values, not expressions.** There is nothing here to evaluate a call or a
construction with, so a record is passed as the map it is — `Pay({Kind = :'Shop.Order', ...})`,
not `Pay(Order{...})`. An argument the reader cannot read **says so**; it used to become a binary
and crash inside your function with your own source text in the error.

**Or stay in a shell.**

```
$ ibs -S examples/Fib
beam-sharp REPL — examples/Fib
  Fib/1
  :reload   recompile the file    :exports  list functions
  :quit     leave                 :env      list bindings

bs> Fib(10)
[0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
bs> Series(3, 0, 1, [])
Series/4 is private in Fib -- defined, not exported
bs> :reload
reloaded examples/Fib
```

The banner lists what the module **exports**, which is why `Series/4` and `Reverse/2` are not on
it: `fib.bs` marks them `private`. They are still in the beam and `Fib/1` still calls them — the
prompt says so rather than answering "no such function", which is a different and untrue sentence.

`:reload` is the point of it: edit the file, reload, call again, without leaving the shell. The
REPL reads exactly one form — a call — because the parser in this slice reads declarations, not
expressions. A wider prompt waits on the surface growing an expression parser.

**The prompt holds bindings**, which is a property of this shell rather than of the language —
ticket 34 put bindings in a *body*; keeping one across prompts is what stops you retyping a value:

```
bs> var t = 9
bs> var o = {Kind = :'Shop.Order', Id = 1, Total = 41}
bs> var n = Bump(o)
n = {Kind = :'Shop.Order', Id = 1, Total = 42}
bs> Squared({Kind = :'Shop.Order', Id = 1, Total = t})
81
bs> :env
```

A bound name resolves **at any depth**, not only as a whole argument. The environment does not
survive `:reload` — the values in it came from code that has just been replaced. An unbound name
says so rather than silently arriving as an atom.

**Checking the reference.** Every beam-sharp block in `LANGUAGE.md` is compiled and checked
against what it claims to be — untagged blocks must compile, ```` ```csharp not-yet ```` blocks
must **not**:

```
./bin/check-language.sh        # -v to see the source and the compiler's output
```

The second half is the one that pays. When a feature lands, this names the paragraphs that now
need promoting, rather than waiting for a reader to trip over them — which is how the reference
came to be showing two constructs the language had never had. A block that is an excerpt gets its
missing declarations from a `<!-- check: ... -->` comment before the fence, invisible in rendered
Markdown.

**Underneath, if you want the `.beam`:**

```
./_build/default/bin/bsc -o /tmp examples/Readings
erl -pa /tmp -eval "io:format(\"~p~n\", ['Readings':'Classify'({ok,5})])."
```

## The slice

**This section describes the slice F1 cut on 2026-08-13, and it is kept in the past tense it
earned.** The table below is what the walking skeleton was; it is not what the compiler is now.
Read the [feature index](features/README.md) for that.

Deliberately only decisions the map had **closed** at the time:

| In | From |
|---|---|
| Multi-clause heads under a mandatory signature | 01, 04, 08 |
| `:atom`, structural open unions, `->` clauses, `&&`/`||` guards | 01, 08, 09, 10 |
| Type algebra with **exact** unions and real integer intervals | 09, 11, 20 |
| Guards credited as type operations (`n > 1` → interval refinement) | 08, 20 |
| Retained failure arm | 12 |
| Abstract Format emission with a `-spec` | 13 |

~~Deliberately **out**: records (26 open), angle-bracket syntax (28 open), modules and imports~~
~~(still fog), FFI, OTP behaviours, refinements, binaries.~~

**ALL SEVEN SHIPPED, and this line went on denying it for up to twelve days** — corrected
2026-08-26 by ENG-245. Left standing rather than deleted, because what it cost is the useful
part: six of the seven have a worked example in `examples/` that the full verification COMPILES
ON EVERY RUN, so the repository was building the refutation of its own README and reporting
green. Nothing was asking a document whether it agreed with the compiler. Now
`bin/check-status-claims.sh` does, and this line is the defect it was written against.

| Was called "out" | Shipped | Compiles today as |
|---|---|---|
| records | F3, 2026-08-14 (ticket 26 resolved) | `examples/Shop` |
| angle-bracket syntax | F6, 2026-08-14 (ticket 28 resolved) | `examples/Parcel` |
| modules and imports | F11 and F15, 2026-08-17 | `examples/Shop/Reports/` |
| FFI | F19 and F23 | `examples/Interop`, `examples/Foreign` |
| OTP behaviours | F10, 2026-08-15 | `examples/Counter` |
| refinements | F2, 2026-08-16 | `examples/Wire` |
| binaries | F13, 2026-08-20 | `examples/Frame` |

The parenthetical ticket states were stale in the same way: tickets 26 and 28 are both resolved,
and the fog the third one named was lifted by two feature files.

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
- ~~**`bs_emit:int_part/1`'s bounded branches are not reachable from the surface yet.**~~
  **RESOLVED by F2, 2026-08-16** — and left here rather than deleted, because the shape of the gap
  is the useful part. Intervals were in the algebra and the checker used them, but they arose only
  from *guards*, and a guard refines a clause rather than a signature, so a parameter declared `int`
  emitted `integer()` whatever its clauses tested. The surface the entry said was owed now exists:
  `examples/Wire/wire.bs` declares `type Octet = int where value >= 0 and value <= 255` and
  compiles. This entry said *"that is the next slice increment"* and stayed that way for two days
  after the increment landed.

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
