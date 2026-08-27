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

Two commands. The first needs [mise](https://mise.jdx.dev); the second needs nothing else.

```sh
mise install        # reads .tool-versions
./bin/verify.sh     # every gate, in CI's order, from any directory
```

`.tool-versions` is the **single source of truth** for the toolchain — Erlang/OTP, rebar3, Node
and the Tree-sitter CLI, each pinned to an exact version. `.github/workflows/ci.yml` repeats those
four strings because a GitHub Actions `with:` input cannot read a file, and
[`bin/check-toolchain.sh`](bin/check-toolchain.sh) fails the build the moment the two disagree —
including the near-miss that reads as agreement, a workflow saying `28` where the manifest says
`28.5`.

If you get the toolchain some other way, `./bin/check-toolchain.sh --env` will tell you exactly
which tool is at the wrong version, before anything compiles.

**Supported surfaces: macOS and Linux.** Both are exercised — macOS locally, Ubuntu on every push
in CI, and CI runs the same `./bin/verify.sh` a clean clone runs rather than a parallel recipe.
Windows is not supported: every gate is a bash script and none has been run there. Nothing in the
compiler is known to depend on the platform, so the gap is in the gates rather than in `bsc`.

Without mise, install those four versions however you prefer and run the same check. The
Tree-sitter CLI is also on npm at the same version number:
`npm install -g tree-sitter-cli@0.25.10`.

## Verifying

`./bin/verify.sh` is the whole suite: every gate, its `--self-test` first, the escript, the test
suite, Dialyzer over the emitted specs, and the two editor grammars. It stops at the first red
stage and names it. It works from any directory, and it gives each run a fresh `SPEC_CHECK_DIR`,
because the PLT that makes a second run fast is also what stops it being an independent one.

**The bar is two consecutive clean passes from a clean checkout.** Not two runs in the same tree:

```sh
git clone <this repo> /tmp/bs-check && cd /tmp/bs-check
./bin/verify.sh && ./bin/verify.sh
```

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
bin/                  repo-wide gates, and verify.sh
compiler/             bsc: the compiler, its tests, its gates, its corpus
compiler/features/    what has been built, feature by feature
editor/               tree-sitter, Neovim and VS Code grammars, and their gates
handoff/              the clean-room audition packet
wayfinder/            the design record (not shipped)
```
