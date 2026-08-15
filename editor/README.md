# Editor support

Three things live here, in ascending order of how much they know about the language:

| | What it is | Knows | Gated by |
|---|---|---|---|
| `tree-sitter-beam-sharp/` | a real parser | the grammar | `bin/check-corpus.sh` |
| `vscode/` | a TextMate grammar | tokens | `bin/check-tokens.sh` |
| `nvim/` | a vim `syntax` file | tokens | `bin/check-tokens.sh` |

**Tree-sitter is the destination.** The other two are the stopgap, and the section below on angle
brackets is why they can only ever be a stopgap.

None of this is a language server. **Syntax highlighting is not LSP** — the protocol has no
"highlight this file" request. Editors get highlighting from a *grammar*, and LSP adds *semantic
tokens* only as a refinement on top of one that already exists. What an LSP would additionally buy
here is at the bottom of this file.

## Installing

**neovim, Tree-sitter (recommended).** With `nvim-treesitter`, register the grammar as a local
parser:

```lua
require('nvim-treesitter.parsers').get_parser_configs().beam_sharp = {
  install_info = {
    url = '/path/to/beam-sharp/editor/tree-sitter-beam-sharp',
    files = { 'src/parser.c' },
    branch = 'master',
  },
  filetype = 'bs',
}
vim.filetype.add({ extension = { bs = 'bs' } })
vim.treesitter.language.register('beam_sharp', 'bs')
```

then `:TSInstall beam_sharp`. Copy `tree-sitter-beam-sharp/queries/highlights.scm` to
`~/.config/nvim/queries/beam_sharp/highlights.scm`.

**neovim, regex fallback.** Symlink or copy `nvim/syntax/bs.vim` and `nvim/ftdetect/bs.vim` into
`~/.config/nvim/`. Nothing to build; works without the Tree-sitter toolchain.

**VSCode.** Symlink `vscode/` into `~/.vscode/extensions/beam-sharp` and restart. There is no build
step and no `npm install` — a TextMate grammar is data.

`src/parser.c` is committed deliberately, so neither neovim nor a packager needs the `tree-sitter`
CLI to build the parser. Regenerate it with `tree-sitter generate` after any `grammar.js` edit;
`bin/check-corpus.sh` does that for you and fails if you have not.

## The one thing only Tree-sitter gets right

`list<int>` and `a < b && c > d` are the **same characters**. Ticket 28 settled the rule
*positionally* — a bracket in type position, a comparison everywhere else — and F6.9 pins it with a
test. A regex grammar has no notion of position, so it must colour one of the two wrongly; both
`vscode/` and `nvim/` colour every angle as an operator and accept that generics look like
comparisons.

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
editor/bin/check-tokens.sh    every keyword in bs_lexer.xrl has a rule in both regex grammars
editor/bin/check-corpus.sh    every .bs the compiler compiles, Tree-sitter parses with no ERROR
```

Neither checks that a rule is *correct* — a rule can be present and wrong, and only looking at a
coloured file catches that. What they check is that a capability cannot ship invisible, which is the
same bargain `every_shipped_surface_form_has_an_example_test` strikes for `examples/`.

**Two ambiguities are declared in `grammar.js` and both are the yecc grammar's own.** `bs_parser.yrl`
records that `binding -> pattern '=' expr` reports twelve reduce/reduce conflicts, because after `(`
nothing with one token of lookahead can tell `(a, b) = pair` from the tuple `(a, b)`; the compiler's
escape is to parse the wider language and narrow afterwards, which is what Erlang itself does.
Tree-sitter is GLR and needs no escape — it explores both and keeps whichever survives, which is why
patterns and expressions stay distinct nodes here. The generator rejects any conflict beyond
`[pattern, _expression]` and `[list_pattern, list]` as unnecessary, so the real overlap is narrower
than twelve.

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

1. **There are no columns anywhere.** The lexer captures `TokenLine` only, so every diagnostic is
   `{error, Line, Fn, Payload}`. LSP ranges want start and end line *and* character. That is a change
   through leex, the parser's `line/1`, and every diagnostic tuple.
2. **Resolve-time errors carry no position at all.** `unknown_type`, `unknown_builtin`,
   `generic_arity`, `needs_type_args`, `not_parametric` and `cyclic_type` are raised via
   `erlang:error` from below the level that has a line, and caught in `check_and_emit`. They would
   land as file-level diagnostics. `kind_field_is_minted` and `list_pattern_needs_rest` already carry
   lines, so the fix has precedent in the same module.
3. **First error wins.** `with_stages` bails at the first lex or parse failure, which is poor while a
   file is being typed into.
4. **Diagnostics are prose on stderr**, and this is *literally ticket 23's open question* — whether
   the residual gets a machine-readable form as well as a human one. An LSP is the second consumer
   that makes the answer obviously yes; the first was an agent.

One thing is already right: ticket 13's standing obligation that the frontend never depends on
in-process compiler state means a server can shell out to `bsc` per save. No daemon, no incremental
engine. F6 measured a full compile-and-error at 0.093s, comfortably inside a save cycle.

**And the payoff is unusually good.** Ticket 04 established that the residual *is* the missing case,
and `bsc` already synthesises pasteable text — `heads/2` prints the clause to add, `caller_head/3`
prints the one the caller must write, and F7 prints the missing switch arm. A code action that
inserts a clause derived from the residual **cannot be wrong**, which is a rare property for a quick
fix. Semantic tokens would separately fix what no grammar can: `Order` and `Describe` are the same
token class, and only the compiler's symbol table knows which is which at a use site.
