# Editor support

Five things live here, in ascending order of how much they know about the language:

| | What it is | Knows | Gated by |
|---|---|---|---|
| `tree-sitter-beam-sharp/` | a real parser | the grammar | `bin/check-corpus.sh` |
| `vscode/` | a TextMate grammar | tokens | `bin/check-tokens.sh` |
| `nvim/` | a vim `syntax` file | tokens | `bin/check-tokens.sh` |
| `syntect/` | a Sublime syntax, for Codex | tokens | `bin/check-tokens.sh`, `bin/check-syntect.sh` |
| `zed/` | a Zed extension over the Tree-sitter grammar | the grammar | `bin/check-corpus.sh` (its query) |

**Tree-sitter is the destination**, and neovim and Zed both run it. The regex three are the
stopgap, and the section below on angle brackets is why they can only ever be a stopgap.

None of this is a language server. **Syntax highlighting is not LSP** — the protocol has no
"highlight this file" request. Editors get highlighting from a *grammar*, and LSP adds *semantic
tokens* only as a refinement on top of one that already exists. What an LSP would additionally buy
here is at the bottom of this file.

## Installing

Replace `~/dev/misc/beam-sharp` below with wherever your checkout lives. Each route was run on
2026-09-24 against Neovim 0.12.5 with nvim-treesitter `main`, VSCode, and Zed 1.18; the one step
not seen working end to end is marked.

**Neovim.** `nvim/` is a plugin directory. With lazy.nvim (LazyVim included), add one spec, e.g.
in `~/.config/nvim/lua/plugins/beam-sharp.lua`:

```lua
return { { dir = '~/dev/misc/beam-sharp/editor/nvim', lazy = false } }
```

Restart, then `:TSInstall beam_sharp` once. That needs the `tree-sitter` CLI (0.25 or later) on
`PATH`, which nvim-treesitter `main` requires for every parser anyway. Before the install, and in
any neovim without nvim-treesitter, `syntax/bs.vim` colours the buffer; after it, Tree-sitter
does. Without a plugin manager, `set runtimepath^=~/dev/misc/beam-sharp/editor/nvim` does the
same.

The plugin does three things, each for a reason measured on 0.12.5:

- `vim.filetype.add({ extension = { bs = 'bs' } })`, because **neovim ships `.bs` as
  `brighterscript`**, and without this line a `.bs` buffer gets that filetype.
- registers `beam_sharp` with nvim-treesitter from this checkout, `queries/` symlinked, so an
  edit to `highlights.scm` shows on the next buffer with no reinstall. A `grammar.js` edit needs
  `:TSInstall! beam_sharp`.
- calls `vim.treesitter.start` on `FileType bs`, because nvim-treesitter `main` starts nothing
  itself and LazyVim starts it only for parsers in a list it caches at startup.

nvim-treesitter's old `master` branch used `get_parser_configs()` instead of the `TSUpdate`
table; this plugin speaks only `main`.

**VSCode.** Package and install once:

```sh
cd ~/dev/misc/beam-sharp/editor/vscode
npx @vscode/vsce package --allow-missing-repository --skip-license -o beam-sharp.vsix
code --install-extension beam-sharp.vsix
```

A TextMate grammar is data, so there is no build, but VSCode installs extensions from a `.vsix`;
re-run both lines after editing the grammar.

**Zed.** Extensions → *Install Dev Extension* (or `zed: install dev extension` from the command
palette), and choose `editor/zed/`. No Rust is needed: the extension has no `Cargo.toml`, and Zed
downloads the wasi-sdk it compiles the grammar with. Zed's own loader reading this directory is
**the step not seen working** — the native folder picker would not take a path from the driving
tool — so it rests on Zed's source. Everything under it was run: the grammar fetched from GitHub
at the extension's `rev` and `path`, compiled to wasm, and `highlights.scm` compiled against it.

`zed/languages/beam-sharp/highlights.scm` is a symlink to the one query file, not a copy: Zed
maps `@keyword.conditional` to its theme's `keyword` by longest dotted prefix and skips `@spell`,
so neovim's capture names serve both. **The grammar is pinned, the query is not.** Zed clones
the repo at `rev` in `zed/extension.toml` and never reads the working tree, so a `grammar.js`
change reaches Zed only when `rev` is moved to a pushed commit carrying it, then *Rebuild* on the
extension's card. The query is read from disk and follows the checkout.

**Codex.** Not yet, and the section *Codex, and the three hops it is behind* below says why. The
grammar is here and checked; what is missing is a released binary that carries it.

`src/parser.c` is committed deliberately, so neither neovim nor a packager needs the `tree-sitter`
CLI to *generate* the parser. Regenerate it with `tree-sitter generate` after any `grammar.js` edit;
`bin/check-corpus.sh` does that for you and fails if you have not. It also compiles every query
in `queries/` against the grammar, since neovim and Zed both refuse a whole query over one pattern
naming a node the grammar lacks.

## The one thing only Tree-sitter gets right

`list<int>` and `a < b && c > d` are the **same characters**. Ticket 28 settled the rule
*positionally* — a bracket in type position, a comparison everywhere else — and F6.9 pins it with a
test. A regex grammar has no notion of position, so it must colour one of the two wrongly; all
three of `vscode/`, `nvim/` and `syntect/` colour every angle as an operator and accept that
generics look like comparisons.

The Tree-sitter grammar knows which production it is in. Measured, on
`type Pair<T>` / `a < b && c > d` / `Pair<int>`:

| Source | Captures |
|---|---|
| `a < b && c > d` | `@operator` only |
| `Pair<T>`, `Pair<int>`, `list<int>` | `@operator`, then `@punctuation.bracket` — and last wins |

The same argument applies to the other place a regex must guess: **a type and a function are the
same token class**. Ticket 27 §4 forced PascalCase for both, so nothing but the production
distinguishes `Order` from `Describe`. The regex grammars use "a `(` follows" as a heuristic and get
record construction wrong; the Tree-sitter grammar has `function_name` and `type_identifier` as
different nodes and simply asks.

## What the grammars do reproduce faithfully, including a trap

`Id: int` and `Id:int` highlight **differently**, and that is correct rather than a bug. Longest
match prefers the atom sigil, so `:int` with no space lexes as an atom literal — which is why
`bs_parser.yrl` catches that exact shape by name and tells you to add a space. All three grammars
mirror the lexer, so the one-character mistake is visible before you compile.

## Keeping them honest

The lexer and parser are the source of truth. These are hand-written second copies of part of them,
and this repo designs duplicate sources of truth away where it can — `resolve/2` is exported so the
checker and the emitter do not have two resolvers, `qualified/2` is "THE SINGLE MINTING POINT". A
TextMate grammar cannot be derived from a leex file and a Tree-sitter grammar cannot be derived from
a yecc one, so **the copies are unavoidable and only the drift is**.

```
editor/bin/check-tokens.sh    every keyword in bs_lexer.xrl has a rule in all three regex grammars
editor/bin/check-corpus.sh    every .bs the compiler compiles, Tree-sitter parses with no ERROR
editor/bin/check-syntect.sh   every construct keeps its recorded scope when syntect colours the corpus
```

`check-tokens.sh` greps each grammar for the keyword, and **a grammar is half prose that names the
very keywords it matches** — so a keyword mentioned in a comment survives the deletion of its rule.
Measured: `type`, `with`, `or`, `atom` and `result` were all shadowed that way. The Syntect column
is stripped of its YAML comments before the grep, so the hole is closed there; the other two
columns still have it, because a TextMate `_comment` is a JSON array no line filter can find the
end of, and vim's `"` opens a comment at the start of a line and also appears inside every
`syn match` pattern. Both want a parser rather than a grep.

The first two do not check that a rule is *correct* — a rule can be present and wrong, and only
looking at a coloured file catches that. What they check is that a capability cannot ship invisible,
which is the same bargain `every_shipped_surface_form_has_an_example_test` strikes for `examples/`.

**`check-syntect.sh` is the one that looks at the coloured file**, and it is the newest of the
three. It runs syntect — the crate Codex links — over `compiler/examples/`, and asserts that 40
named constructs come out carrying the scope `vscode/syntaxes/beam-sharp.tmLanguage.json` records
for them: `Classify` is `entity.name.function`, `Octet` is `entity.name.type`, `=>` is
`keyword.operator.arrow`, and so on. It makes five other assertions: the two projections declare the
same scope names, all three fence spellings resolve, every file handed over was coloured, and
nothing is matched inside a `//` line.

That last one is the claim a roster of positive obligations cannot make, and **it is the one this
gate got wrong first.** A stack is outermost-first, so a nested match *inherits* the comment scope
and adds its own on top; the original check asked whether the comment scope was *absent*, which for
a nested match it never is, and looked only at regions whose text began `//`, which a nested
match's never does. Both mistakes pointed the same way and the check could not fire at all.
Measured on a grammar whose comment rule pushes a context: 4,315 scoped regions became 13,842 and
the gate printed "nothing matched inside a comment" and exited 0. The test is *position* — the
required scope must be the **last** element — and it now reaches the positive rows too, which were
being satisfied out of the corpus's own prose. Control 4 builds that grammar.

The obligations live in the shell, not in `syntect/scope-dump/`. That program prints what syntect
saw and holds no opinion about any of it; if the expected scope names sat beside the code producing
them the gate would agree with whatever grammar it was written beside. And the roster is hand-copied,
so part 0 compares the two files' scope-name sets directly: rename a scope in the TextMate grammar
alone and this goes red, which nothing in `editor/` could see before.

Measured 2026-09-20: 40 constructs across 25 examples, 4,315 scoped regions, and the dump is
byte-identical under syntect's two regex engines (`fancy-regex` and Oniguruma) — 4,319 records each,
built into separate target directories, which `scope-dump/Cargo.toml` explains is load-bearing.

**Two constructs have no obligation, and each absence is a measurement.** Every `:'quoted atom'`
under `compiler/examples/` is inside a comment, in the `bsc …` invocation a file's header prints;
and so is every `or`. The rules are in all three grammars and no compiling example spells either, so
an obligation for them would be red on a clean tree. That is the examples corpus's gap, not the
grammars'.

**Two ambiguities are declared in `grammar.js` and both are the yecc grammar's own.** `bs_parser.yrl`
records that `binding -> pattern '=' expr` reports twelve reduce/reduce conflicts, because after `(`
nothing with one token of lookahead can tell `(a, b) = pair` from the tuple `(a, b)`; the compiler's
escape is to parse the wider language and narrow afterwards, which is what Erlang itself does.
Tree-sitter is GLR and needs no escape — it explores both and keeps whichever survives, which is why
patterns and expressions stay distinct nodes here. The generator rejects any conflict beyond
`[pattern, _expression]` and `[list_pattern, list]` as unnecessary, so the real overlap is narrower
than twelve.

## Codex, and the three hops it is behind

**Nothing in this directory makes Beam# highlight in a Codex you can install today.** The grammar
is written, it is checked by the real highlighter, and it is three releases upstream of any binary.
Saying that plainly is the point of this section: `check-syntect.sh` going green is local
completion, not availability.

Codex loads custom `.tmTheme` colour mappings but its grammar database is the immutable
[`two-face`](https://crates.io/crates/two-face) bundle, which is why a `csharp` or an `elixir` fence
colours only incidental overlap. Adding a language to it is a chain:

```
editor/syntect/BeamSharp.sublime-syntax
  -> bat            assets/syntaxes/02_Extra/   (a submodule, and assets/create.sh regenerates the dump)
  -> two-face       bumps its vendored bat, regenerates syntaxes.bin
  -> codex          bumps its two-face dependency
  -> a codex release
```

`two-face` is not an independent collection: it vendors bat as a submodule and describes itself as
"a bundle of bat's `syntaxes.bin` and `themes.bin` files, but with proper versioning". So the
contribution is to **bat**, and the hops after it are dependency bumps nobody here controls.

**And bat's front door is shut, on a criterion this language cannot meet yet.** `doc/assets.md`
sets the inclusion bar at *"More than 10,000 downloads at Package Control"*. Beam# has no Package
Control listing and no users. The measured options, none of which a session may take:

| Route | What it needs | Cost |
|---|---|---|
| The submodule route | a Package Control listing, and 10,000 downloads | the language shipping first |
| A manual addition | bat accepting one outside its own criterion — `doc/assets.md` records that Nim, Rego, SML and others were added this way | an ask, and a maintainer's discretion |
| A Codex custom-grammar loader | Codex learning to read a `.sublime-syntax` from disk | explicitly out of ENG-262's scope |

`fancy-regex` matters for the first two: two-face drops some definitions when that feature is
selected, because the engine does not support everything Oniguruma does. This grammar was measured
under both and the dumps are identical, so it would survive either build.

Until one of those routes is taken, the honest description is the one at the top of this section.

**What the grammar is usable for today** is anything that links syntect and can be pointed at a
syntax directory — which is what `check-syntect.sh` itself does, and it is the same engine Codex
runs. That is measured. `.sublime-syntax` is Sublime Text's own format, but no-one here has opened
the file in Sublime, so that is not.

One thing the gate does **not** measure: it resolves `bs` against syntect's own bundled set, not
against two-face's, which is bat's and is larger. Whether something in there already claims the
extension is a question for the hop that adds this grammar to it.

## Exemplars do not parse, and it is not the grammar's fault

`compiler/examples/*.bs` — the "must run" corpus — parses **8 of 8**. `examples/exemplars/` parses
**1 of 17**, and both causes are documented forks between the exemplars and the compiler rather than
gaps here:

- **The bare clause head.** Exemplars write `(o, r, n) -> …` without repeating the function name.
  The compiler's grammar has exactly one clause production and it requires the name. That divergence
  is already written up in `compiler/examples/exemplars/README.md` against ticket 01.
- **`[module: GenServer]`**, an attribute syntax the compiler does not have either — it spells this
  `behaviour GenServer`.

This grammar tracks the **compiler**, deliberately. When those forks close, it follows.

## What an LSP would need from the compiler first

Worth knowing before it is scheduled, because most of it is compiler work rather than protocol work:

1. **There are no columns anywhere — and this is cheaper to fix than it looks.** Every diagnostic is
   `{error, Line, Fn, Payload}` because `bs_lexer.xrl` writes `TokenLine` in every rule action. It is
   *not* a toolchain limit: measured in the parsetools 2.7.1 source, leex predefines **`TokenCol`**
   and **`TokenLoc`** (`{TokenLine, TokenCol}`, available even when `error_location` is `line`), and
   yecc's own `error_location` already **defaults to `column`**. Since the parser's `line/1` is just
   `element(2, T)`, swapping `TokenLine` for `TokenLoc` in the lexer makes locations become
   `{Line, Col}` transparently. What then needs work is everything that assumes an integer: the
   `~s:~p:` format strings in `bsc:report/2`, and the annotations handed to the Abstract Format.
2. **Resolve-time errors carry no position at all.** `unknown_type`, `unknown_builtin`,
   `generic_arity`, `needs_type_args`, `not_parametric` and `cyclic_type` are raised via
   `erlang:error` from below the level that has a line, and caught in `check_and_emit`. They would
   land as file-level diagnostics. `kind_field_is_minted` already carries a
   line, so the fix has precedent in the same module.
3. **First error wins.** `with_stages` bails at the first lex or parse failure, which is poor while a
   file is being typed into.
4. **Diagnostics are prose on stderr**, and this is *literally ticket 23's open question* — whether
   the residual gets a machine-readable form as well as a human one. An LSP is the second consumer
   that makes the answer obviously yes; the first was an agent.
   <!-- Answered and built: the term (F16, `--diagnostics term`, 2026-08-18) and its JSON
        encoding (F47, `--diagnostics json`, 2026-09-15, ENG-298). Items 1 and 2 are F35
        (2026-09-05); item 3 stands. -->

One thing is already right: ticket 13's standing obligation that the frontend never depends on
in-process compiler state means a server can shell out to `bsc` per save. No daemon, no incremental
engine. F6 measured a full compile-and-error at 0.093s, comfortably inside a save cycle.

**And the payoff is unusually good.** Ticket 04 established that the residual *is* the missing case,
and `bsc` already synthesises pasteable text — `heads/2` prints the clause to add, `caller_head/3`
prints the one the caller must write, and F7 prints the missing switch arm. A code action that
inserts a clause derived from the residual **cannot be wrong**, which is a rare property for a quick
fix. Semantic tokens would separately fix what no grammar can: `Order` and `Describe` are the same
token class, and only the compiler's symbol table knows which is which at a use site.
