# beam-sharp

A BEAM-targeting programming language with C#-family brace syntax, whose defining feature is
Erlang-style **multi-clause function heads with pattern destructuring**, statically checked by a
**set-theoretic type system that proves clause exhaustiveness**.

```
module Demo

type Status = :ok | :client_error | :server_error

public Status Classify(int)

Classify(>= 200 and < 300) -> :ok
Classify(>= 400 and < 500) -> :client_error
Classify(>= 500)           -> :server_error
```

That is not exhaustive, and the compiler does not shrug at it:

```
demo.bs:5: error: Classify is not exhaustive
  no clause matches:
    Classify(<= 199) -> ...
    Classify(>= 300 and <= 399) -> ...
```

**The residual is the missing case.** The compiler does not report that something is wrong
somewhere; it hands back the clause head you have not written, in the syntax you would write it
in. That is the whole bet of the language, and the reason the type system is set-theoretic:
subtracting what the clauses cover from what the signature promises leaves a type, and a type in
parameter position is a pattern.

`beam-sharp` is a working name; naming is unresolved.

`bsc` is a real compiler, written in Erlang, emitting Erlang Abstract Format. It is a walking
skeleton rather than a finished language: what it does and does not yet accept is recorded in
[`LANGUAGE.md`](LANGUAGE.md), which is compiled by CI block by block, so it cannot describe a
language the compiler does not have.

## Setting up

**This section, *Verifying* and *Building something* are about the source repository.** If you are
reading this inside the clean-room handoff package, you have the specification documents, the
compiler's feature record and the example corpus — but not the compiler, not its gates, and not
the toolchain manifest, so none of the commands in those three sections will run. That is deliberate: implementing the compiler from the
specification is the exercise, and shipping one would defeat it. The corpus is your oracle
instead, and every example opens with the command that runs it once you have a compiler to run.

Two commands. The first needs [mise](https://mise.jdx.dev); the second needs nothing else.

<!-- not shipped: bin/ and .tool-versions belong to the source repository, not the package -->
```sh
mise install        # reads .tool-versions
./bin/verify.sh     # every gate, in CI's order, from any directory
```

`.tool-versions` is the **single source of truth** for the toolchain — Erlang/OTP, rebar3, Node
and the Tree-sitter CLI, each pinned to an exact version. `.github/workflows/ci.yml` installs from
that same file through `jdx/mise-action` and repeats none of the four strings;
[`bin/check-toolchain.sh`](bin/check-toolchain.sh) fails the build the moment a version literal is
copied back beside the manifest, because that is a second source of truth with nothing reconciling
it against the first.

**Two further tools are required and deliberately carry no version line: `python3` and `mise`.**
`compiler/bin/check-switch-diagnostics.sh` shells to it to rebuild the audition packet and check
that the committed `PACKET.md` still matches `LANGUAGE.md`, so it is a hard dependency of a gate
that runs in CI. Any python3 will do — the scripts import nothing outside the standard library —
and `.tool-versions` records why it is not pinned.

`./bin/check-toolchain.sh --env` names exactly which tool is at the wrong version, missing, or
resolving to a copy mise does not own — before anything compiles.

**Supported surfaces: macOS and Linux.** Both are exercised — macOS locally, Ubuntu on every push
in CI, and CI runs the same `./bin/verify.sh` a clean clone runs rather than a parallel recipe.
Windows is not supported: every gate is a bash script and none has been run there. Nothing in the
compiler is known to depend on the platform, so the gap is in the gates rather than in `bsc`.

**mise is required, as of 2026-09-01.** It was optional until then, and this paragraph used to say
so. `--env` now also checks that each pinned tool resolves *on PATH* to a binary mise owns, not
merely to one reporting the right number — because a version string cannot see provenance, and an
unmanaged copy holding the pinned version satisfies every other check here while the build runs on
a toolchain nothing in this repository installed. A hand-installed OTP therefore fails that check
by construction. The Tree-sitter CLI is on npm at the same version number
(`npm install -g tree-sitter-cli@0.25.10`), and installing it that way now leaves the gate red for
the same reason.

## Verifying

`./bin/verify.sh` is the whole suite: every gate, its `--self-test` first, the escript, the test
suite, Dialyzer over the emitted specs, and the two editor grammars. It stops at the first red
stage and names it. It works from any directory, and it gives each run a fresh `SPEC_CHECK_DIR`,
because the PLT that makes a second run fast is also what stops it being an independent one.

Each stage reports its elapsed time, and a clean run reports the total. A failed stage reports its
time too, so a red run says both where it stopped and how long that stage ran.

In GitHub Actions, those stages become collapsible log groups. Local output stays plain; grouping
is enabled only when `GITHUB_ACTIONS=true`.

**The bar is two consecutive clean passes from a clean checkout.** Not two runs in the same tree:

<!-- not shipped: bin/ belongs to the source repository, not the package -->
```sh
git clone <this repo> /tmp/bs-check && cd /tmp/bs-check
./bin/verify.sh && ./bin/verify.sh
```

**The two halves catch different faults, which is why neither one alone is the bar.** A clean
checkout is what measures the repository rather than the disk. `compiler/src/bs_lexer.erl` and
`bs_parser.erl` have never been committed — they are leex and yecc output, and the `.xrl` and
`.yrl` beside them are the tracked sources — and `_build/`, `*.beam`, `*.plt` and `*.abstr` are
ignored for the same reason. So a gate in a warm tree can go green against a parser generated
three commits ago, or against a file edited and never added, and say nothing. The second run is
what measures state dependence, and it only does so with the fresh `SPEC_CHECK_DIR` above: warm,
run two asserts against the PLT run one left behind, in the 0.05 s that reusing it costs rather
than the 9 s that building it does. One clean-clone run cannot see the second fault and two warm
runs cannot see the first.

One mistake voids both at once. If `HEAD` moves after the clone — an amend, a rebase — the two
runs measured a commit that no longer exists. Commit first, then clone, then run twice.

The test stage has no retry. Local verification and CI both invoke `rebar3 eunit`, under EUnit's
five-second per-test timeout, so a red is believed on its first showing. Each EUnit VM owns a
separate fixture root under `compiler/_build/test/bsc_eunit/`; source fixtures are separate again
per case. A prior run, another checkout and a concurrent worktree therefore cannot enter this
run's source index or replace its emitted beams. Subprocess tests capture the CLI's exit status
through the shared CLI runner separately from merged output, rather than trusting a shell-appended
marker.
<!-- the fixed-root and subprocess-capture failures were ENG-229 -->

Every gate takes `--self-test`, which builds the defect the gate names, requires a red on it, and
requires a green on the correct form standing beside it. A gate here is not believed until it has
been seen to fail.

## Building something

```sh
cd compiler && rebar3 escriptize
./_build/default/bin/bsc --src-root examples -o /tmp/out examples/Wire
```

A module is a **directory**, so `bsc` takes one — a per-file invocation emits a `.beam` missing the
rest of its module. `--src-root` is how the compiler learns where dotted names like `Shop.Reports`
begin; it never guesses.

## Where to read next

| | |
|---|---|
| [`TOUR.md`](TOUR.md) | the language as a narrative, every line quoted from the corpus and every transcript replayed by CI |
| [`LANGUAGE.md`](LANGUAGE.md) | the reference. Untagged blocks compile; `not-yet` blocks are decided syntax the compiler has not reached |
| [`PRELUDE.md`](PRELUDE.md) | what the prelude contains, and what it deliberately does not |
| [`CONTEXT.md`](CONTEXT.md) | the glossary. Terms only — what a word means, never why it was chosen |
| [`compiler/features/`](compiler/features/) | numbered capabilities, each citing the decisions it implements |
| [`compiler/examples/`](compiler/examples/) | the corpus every gate compiles |

The design record — tickets, research, prototypes and the map of what is decided and what is still
fog — lives under `wayfinder/` and is deliberately **not** part of the shipping package. The
documents above are written to stand without it, and
[`bin/check-links.sh`](bin/check-links.sh) holds them to that.

## Layout

```
bin/                  repo-wide gates, and verify.sh                 (not shipped)
compiler/             bsc: the compiler, its tests, its gates, its corpus
compiler/features/    what has been built, feature by feature
editor/               tree-sitter and Neovim/VS Code grammars        (not shipped)
handoff/              the clean-room audition packet                 (not shipped)
wayfinder/            the design record                              (not shipped)
```

**"Not shipped" is relative to the clean-room handoff package.** It carries the five
specification documents, `compiler/README.md`, `compiler/features/` and `compiler/examples/` —
and none of the compiler's source, because implementing that from the specification is the
exercise. `handoff/MANIFEST` is the single definition of what ships, and
`bin/check-handoff-package.sh` holds the package to it: nothing may dangle out of it, and no
fenced command may name a path the recipient does not have.
