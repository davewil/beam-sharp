# F12 — `public` / `private` at the signature

**Status**      in progress · [ENG-222](https://linear.app/davewil/issue/ENG-222)
**Implements**  [ticket 40](../../wayfinder/issues/40-module-and-namespace-system.md) §3, resolved
                2026-08-15 — decides nothing
**Unblocks**    no exemplar. It closes the last open section of ticket 40, and it is the **last
                whole-corpus rewrite** the language has queued
**Depends on**  F10 (the contract-scoped callback table), F11 (`exports_of/1`, the qualified-call
                resolution this filters)

## Why this one now

**Cost, not capability — the F8 precedent exactly.** F8 took its slot ahead of binaries because it
rewrote every `.bs` file in the repo and every later feature adds more of them. This rewrites all
32, and the corpus has grown by three since F8 made that argument. Sooner is cheaper, and the
argument does not improve with age.

The second reason is that the language currently defaults to *open*, and ticket 40 §3 recorded
that this is **the option with no precedent behind it**: C# defaults members to private, the BEAM
defaults to unexported, TypeScript defaults to module-private. Every tier-1 and tier-2 source
defaults to closed. "Keep today's behaviour" was never the conservative choice.

## What is being built

The marker sits on the signature, one per function — **Elixir's placement, C#'s words**:

```csharp
module Fib

public  list<int> Fib(int n)
Fib(n) when n <= 0 -> []
Fib(n) when n > 0  -> Series(n, 0, 1, [])

private list<int> Series(int n, int a, int b, list<int> acc)
Series(n, a, b, acc) when n <= 0 -> Reverse(acc, [])
Series(n, a, b, acc) when n > 0  -> Series(n - 1, b, a + b, [a, ..acc])
```

`'Fib'.beam` then exports `Fib/1` and nothing else. `Series/4` and `Reverse/2` are still *there* —
still called, still `-spec`'d, still named by a crash — they are simply not in the export list.

**Every function is marked**, which is the half of `def`/`defp` ticket 40 §3 takes: a signature
carries `public` or `private`, never neither. That is decided; this feature does not reopen it.

## The three things this feature decides, all mechanism

Ticket 40 §3 specified four compiler deltas and left three questions of *diagnosis* open. Each is
settled below the way `name_redeclared` was — the feature names the error term, the ticket having
named the condition.

### 1. An unmarked signature is a CHECK error, not a syntax error

The cheap reading is `signature -> visibility type_prim uident '(' params ')'`, making `visibility`
mandatory in the grammar. It is the wrong one, and the reason is this project's oldest recurring
finding rather than taste: an unmarked signature would then report

```
fib.bs:3: syntax error before: 'list'
```

which is a remark about the token after the missing word, and says nothing about the missing word.
That is F7's costume and ticket 40 §2's — *"the defect is the diagnosis, not the outcome"*.

So the grammar makes `visibility` **optional**, and `bs_check` raises `{missing_visibility, Name,
Line}` at the declaration, into the `bsc:resolve_error/2` path `kind_field_is_minted` already takes.
The rule ticket 40 §3 decided is enforced exactly as strictly; only the message changes, and the
message is the whole reason the rule is worth having.

### 2. A private function called from another module is `private_function`, never `unknown_callee`

`bs_check:exports_of/1`'s own comment predicted this feature would be *"one comprehension guard"*.
It is not, and the reason is worth recording because the prediction was a good one:

```erlang
%% Every function is public today — ticket 40 §3's `public`/`private` is F12 —
%% so this is the whole signature list, and the filter this becomes when F12
%% lands is one comprehension guard.
```

Filtering **at table construction** destroys the information needed to tell *private* from
*absent*. A qualified call to a private function would then resolve to nothing and report
`{unknown_callee, Callee, Arity}` — telling the author the function does not exist when it plainly
does, and sending them to fix the wrong thing. It is the third appearance of exactly the shape
ticket 40 §2 was written about.

So the typing table filters, and a **second table carries the private names for diagnosis only**.
The `World` entry already is a map (`#{exports => …}`), so this is one more key beside a key that
exists, and no consumer of `exports` changes. The call site raises
`{private_function, Module, Name, Arity, Line}`.

### 3. Naming a private function at `bsc` or `ibs` reports privacy — and the BEAM already knows

`bs_run:resolve_and_call/2` reads `Mod:module_info(exports)`, so after this feature a private name
is simply not in the list. Measured on today's build, `bsc examples/Fib Series 3` would then fall
through `resolve/3` to `resolve_without_name/4`, match the file-name rule, take `Fib/1`, and try to
read `"Series"` as an **argument** — reporting an unreadable argument for a function name. Fifth
instance of the fails-quietly shape, and it would have shipped invisibly.

**No plumbing is needed to fix it.** `module_info(functions)` lists every function the module
defines, exported or not, so the runner can subtract one list from the other and say the true thing:

```
bsc: Series is private in Fib
```

That is a property of the emitted beam rather than of the compiler's own tables, which is why the
REPL gets it for the same zero cost — and the REPL is worth naming explicitly, since the features
README records that F4, F5 and F7 each found a hole at the `ibs` prompt and none closed the gap.

## Scenarios

| id | input | command | expected | exit |
|---|---|---|---|---|
| F12.1 | `examples/Fib` with `public Fib/1`, `private Series/4`, `private Reverse/2` | `bsc examples/Fib 10` | `[0, 1, 1, 2, 3, 5, 8, 13, 21, 34]` | 0 |
| F12.2 | as F12.1 | the emitted beam's export list | `[{'Fib',1}]` only — `Series/4` and `Reverse/2` absent | 0 |
| F12.3 | a signature with no `public` and no `private` | `bsc` it | `{missing_visibility, 'Series', L}` reported with the `.bs` file and line | 1 |
| F12.4 | module `B` calls `A.Helper(1)` where `A` declares `private … Helper(int)` | `bsc` the set | `Helper/1 is private in A` — **not** `unknown_callee` | 1 |
| F12.5 | `examples/Counter` (`behaviour GenServer`) with `private … HandleCall(…)` | `bsc examples/Counter` | error at the declaration naming the behaviour and the callback | 1 |
| F12.6 | as F12.1 | `bsc examples/Fib Series 3` | `bsc: Series is private in Fib` | 2 |
| F12.7 | as F12.1 | `ibs -S examples/Fib` then `Series(3, 0, 1, [])` | the same sentence, and the prompt survives it | — |
| F12.8 | as F12.1 | a private function still calls and is called **within** its module | `Fib(10)` works, which is F12.1 | 0 |
| F12.9 | the whole corpus, rewritten | `rebar3 eunit`, `bin/check-language.sh`, `bin/spec-check.sh`, `editor/bin/check-corpus.sh` | green | 0 |
| F12.10 | `public` and `private` as identifiers | grep the corpus | no `.bs` file uses either word as a name — **re-measured, not inherited** | — |

## What the corpus rewrite must not get wrong

**The forced-public set is enumerated before a single file is edited**, because the alternative is
discovering it one red test at a time across 32 files. A function must stay `public` if it is
invoked by the eunit suite, by a gate in `bin/` or `editor/bin/`, by a recorded `bsc`/`ibs`
invocation in any README or `.bs` comment, by another module in the corpus, or if it is a callback
of a behaviour its module declares.

**Everything else becomes `private`, and that is the point.** Marking all 32 files `public` would
pass every gate and demonstrate nothing; `fib.bs`'s `Series` and `Reverse` are ticket 40 §3's own
example of implementation detail that is currently public.

**Run the corpus gate before writing any rejection test.** F5's lesson, and a rewrite this size is
exactly where a regression hides behind a green new test.

## The editor grammars, and why one commit

There are **three**: `editor/tree-sitter-beam-sharp`, `editor/vscode` (TextMate) and `editor/nvim`.
`editor/bin/check-tokens.sh` derives its keyword list from `bs_lexer.xrl`, so it goes red the moment
the two lexer lines land — and it proves only that a keyword is *present*, never that a rule uses
it. `check-corpus.sh` is the one that stays red until the tree-sitter **signature rule accepts the
modifier**, and it is the gate that has now twice been found not looking. Lexer and all three
grammars land together.

## Out of scope

- **Any visibility on a type, record or `using` line.** §3 puts the marker on the signature and
  nowhere else. Whether a record can be module-private is not asked and not answered here.
- **`protected`, `internal`, or any third level.** Two words, because the BEAM has two states.
- **A foreign declaration.** `foreign_decl` names an *Erlang* function to call; it defines nothing
  and contributes nothing to `Exports` — verified, so "every function is marked" has no unmarked
  case hiding in the FFI.
- **`index.bs`.** It may hold no functions at all (F15's `function_in_index`), so no marker.
- **Whether the filename fixes the exported name** — ticket 40 §2's sub-question, still open.

## Done when

`bsc examples/Fib 10` runs with `Series` and `Reverse` absent from the export list; all ten
scenarios hold; every `.bs` file in the repo carries a marker on every signature; and all ten CI
gates are green.
