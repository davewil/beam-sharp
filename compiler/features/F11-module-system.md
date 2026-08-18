# F11 — The module system: dotted atoms, `using`, and cross-module scope

**Status**      **done 2026-08-17** · [ENG-220](https://linear.app/davewil/issue/ENG-220)
**Implements**  [ticket 40](../../wayfinder/issues/40-module-and-namespace-system.md) §1–§2 and
                [ticket 41](../../wayfinder/issues/41-imports-and-cross-module-scope.md) §1–§5,
                both resolved — decides nothing
**Unblocks**    the collection library, and through it `list<string>` operations, AoC file input,
                and the **imports / multi-file modules** row that blocks all three exemplars
**Depends on**  F1, F3, F5, F6

## Why this one now

It is the only remaining capability that blocks **all three** exemplars, and it was the only
substantial item that was fully decided and entirely unbuilt — tickets 40 and 41 both closed with
no feature file behind them. Four checks and one delta were specified in advance, so this feature
designs nothing.

It also unblocks more than any other candidate: `examples/exemplars/README.md` files four of its
seven dialect gaps under "module fog", and F9's own note records that `string` removed **one of
three** blockers on AoC input — the other two are the FFI entry check and the collection library,
and the collection library is blocked on exactly this.

## What ticket 41 §1 owed, and what running it found

§1 left one item explicitly unrun: *"the claim is that LALR(1) separates them on the following
token; it has not been run."* **It is run, and the claim is half false.**

The ticket's literal delta is right-recursive:

```
modpath -> uident | uident '.' modpath
```

That grammar **builds** — 2 shift/reduce conflicts, which yecc resolves by shifting — and then
**misparses the construct it exists for**:

```
probe.bs:4: error: syntax error before: '('        %  Go(x) -> List.Map(x)
```

The recursive arm greedily takes `List.Map` as the whole path and leaves no function name behind.
**Building is not parsing**, which is the entire reason this had to be run rather than reasoned
about — and it is the fourth time on this project that measuring a ticket's own claim changed what
the work was.

**Left recursion is the fix, and it is the whole fix**:

```
modpath -> uident | modpath '.' uident
```

**Zero conflicts**, and `List.Map(x)` parses. At `modpath '.' uident` with `(` ahead, yecc's shift
preference takes the `(`, so the last segment becomes the function name at a call site and stays
part of the path everywhere else. The ticket's *reasoning* — separated on the following token — was
right; it was attached to the recursion direction that cannot deliver it.

The owed conflict check is therefore **discharged**, with the correction on record.

## What is being built

```csharp
// Shop/Orders/index.bs
module Shop.Orders                 // emits the atom 'Shop.Orders'

record Order { Id: int, Total: int }
```

```csharp
// Billing/Invoice.bs
module Billing

using Shop.Orders                  // module tier — names come in UNQUALIFIED
using Shop                         // namespace tier — Orders.Sum(...) short-qualified

int Restate(Order o)
Restate(o) -> Sum(o)               // resolved to 'Shop.Orders':Sum/1 at CHECK time
```

## Scenarios

| id | input | expected | exit |
|---|---|---|---|
| F11.1 | `module Shop.Orders` | emits module atom `'Shop.Orders'`, file `Shop.Orders.beam` | 0 |
| F11.2 | a record in `module Shop.Orders` | tag mints `'Shop.Orders.Order'` — 26 §1 unchanged | 0 |
| F11.3 | *(moved — see “The directory half” below)* | — | — |
| F11.4 | `List.Map(xs)` with `List` compiled in the same invocation | typed from `List`'s signature; emits a remote call | 0 |
| F11.5 | `List.Map(xs)` where `List` declares no `Map/1` | error naming the qualified callee | 1 |
| F11.6 | `using Shop.Orders` then unqualified `Sum(o)` | resolves to `'Shop.Orders':Sum/1`, emits remote | 0 |
| F11.7 | `using Shop` then `Orders.Sum(o)` | namespace tier — resolves via the module table | 0 |
| F11.8 | two imports both exporting `Sum/1`, called unqualified | `{ambiguous_call, …}` printing **qualified** candidates | 1 |
| F11.9 | an import whose `Sum/1` collides with a local `Sum/1` | `{import_shadows_local, …}` | 1 |
| F11.10 | `Sum/1` imported beside a local `Sum/2` | **accepted** — resolution is by name *and* arity (40 §2) | 0 |
| F11.11 | two `Combine/2` signatures in one module | `{name_redeclared, Combine, 2, Line}` **before** the exhaustiveness walk | 1 |
| F11.12 | `Fib/1` and `Fib/2` in one module | **accepted** — arity overloading is permitted (40 §2) | 0 |
| F11.13 | *(moved — see “The directory half” below)* | — | — |
| F11.14 | two modules importing each other | a cycle error naming both, refused by name (F6 precedent) | 1 |
| F11.15 | diagnostics printing a call or head | **always fully qualified**, regardless of scope (41 §2) | — |

## The directory half, and why two scenarios moved out of this feature

Two of the four specified checks — `{module_path_mismatch, …}` (41 §5) and
`{function_in_index, …}` (41 §4) — **cannot be built here, and finding out why is worth more than
the checks would have been.**

Both are specified against a module that is a **directory**: 41 §5's rule is *"a file's `module`
declaration must match its **directory** path — `Shop/Orders/Total.bs` must say `module
Shop.Orders`"*, and §4's rule is about `index.bs`, which only exists if a module aggregates several
files. That is ticket 13's aggregate rule, and **it is not built**: `bsc` reads one `.bs` file and
writes one `.beam`, and every one of the 30 `.bs` files in this repo is a whole module in a single
file. `examples/Counter/counter.bs` is `module Counter`; its directory is `examples`.

So a path check written against directories today would fail every file in the repo, and
`function_in_index` guards a file that nothing can currently produce. **`index.bs` has never been
compiled** — 41 §4 says so itself.

The honest cut is therefore between *how modules see each other* and *what a module is made of*.
This feature builds the first against the one-file-per-module reality that exists. The second —
ticket 13's aggregation, `index.bs`, and the two checks that presuppose them — is its own feature,
and it now has a name and a reason rather than being discovered missing halfway through a third.

**It is also the smaller half than it looks.** `13b` already measured the mechanism working: two
functions in one `.beam` reporting against two source files with exact lines, via a repeated
`{attribute,ANNO,file,{Name,Line}}`. What is missing is the plumbing, not the technique.

## Out of scope

- **`public` / `private` on the signature — ticket 40 §3.** Deferred to **F12** deliberately, not
  overlooked. Three reasons: the features README defines this feature's unit as four checks plus
  the §3 delta plus the grammar rules, and visibility is in none of them; without it every function
  is public, which is *consistent* — imports import everything and §2's table is unchanged; and it
  costs a rewrite of all 30 `.bs` files, which is its own increment on the F8 precedent rather than
  a rider on this one.

  **It also cannot be added without touching the editor**, which this feature otherwise does not:
  `editor/bin/check-tokens.sh` **derives** its keyword list from `bs_lexer.xrl`, so the moment
  `public` and `private` become tokens, that gate goes red unless both editor grammars gain them in
  the same commit. Measured, not assumed. F12 owes that.

- **The import alias** — [ticket 47](../../wayfinder/issues/47-import-alias.md), open.
- **The boundary guard on a refined parameter** — [ticket 46](../../wayfinder/issues/46-refined-parameter-at-the-boundary.md), open.
- **A signature artefact in the `.beam`** — fork B in 41 §3, refused there and blocked on ticket
  16 §4 besides. This feature re-checks source, which is fork A.
- **A build tool.** 41 §3 draws the boundary: a build tool names the source root and the file set,
  never the order. `bsc` computes the order from the `using` edges itself.

## Done when

`bsc` compiles a two-module program where one imports the other, both qualified and unqualified,
with the dependency's signatures typed in the B# algebra; all fourteen asserting scenarios hold;
and every existing gate stays green.

**One gate is expected to go red on the way, by design.** `bin/check-language.sh` requires a
`not-yet` block to fail compiling. Any block in `LANGUAGE.md` holding `using Shop.Orders` or
`Module.Fn(…)` starts compiling the moment the grammar lands — which is the gate doing its stated
job of naming the paragraphs that now need promoting, not a regression.

**And the REPL must be exercised by hand.** `bs_repl` appears zero times in the suite and four
features in a row have found a hole at the `ibs` prompt. A shared environment threaded through a
fold is precisely the shape that under-serves a single-file entry point, so `ibs -S` against a
module with a `using` edge is a manual check this feature owes before it is done.

**DONE — 2026-08-17.** All fourteen asserting scenarios hold, 268 tests pass (up from 250), and
every gate is green. The REPL check was run and passes: `Restate(3)` returns `9` and `Counted(4)`
returns `2` at the `bs>` prompt, with the dependency compiled and loaded. It passes because `run/2`
and `repl/2` were moved onto the set path rather than left on `file/2` — which is the fifth feature
in a row to touch that prompt, and the first not to find it broken.

## What the building revealed

**Ticket 40 §2 was resolved and nothing implemented it.** The decision permitting arity overloading
landed on 2026-08-15; the compiler could not represent it. `callees` was keyed by name alone, so
`maps:from_list/1` kept whichever arity was written last — the *exact* mechanism the features README
had already written up for duplicate **type** declarations, one namespace along and unnoticed. And
`collect/1` gathered a signature's clauses by name alone, so `Length/1` also collected `Length/2`'s
clauses: three unreachable-clause warnings that were nothing of the kind, then a crash in
`boundary_guards/4` zipping a two-parameter signature against a one-argument head.

**No test could have caught it, and that is the point.** Not one `.bs` file in the repo had ever
overloaded an arity, because the language did not have the rule until two days ago. It was found by
*writing the example* — the harness rule at the top of this file working exactly as stated: a feature
is done when you can see it run, not when its scenarios pass.

**The namespace tier compiled and then failed at run time**, which is the fourth appearance of this
project's worst failure shape. The checker resolved `List` to `'Shop.Collections.List'` and the
emitter still had the short spelling the author wrote, so a program the checker had *passed* emitted
a call to a module that does not exist. `undef`, at run time, from green source. The fix is the one
this repo keeps reaching for: resolve once, at check time, and have the emitter read the table rather
than repeat the work — the same reason `resolve/2` is exported instead of copied.

**And the editor gate was hiding four more failures than it reported.** `check-corpus.sh` runs
`… | grep -F ERROR | head -3` under `set -e` and `pipefail`, so `head` closing early gives `grep` a
SIGPIPE and the whole gate exits at the **first** failing file. The one red file everybody could see
was masking four others, and every one was a shipped feature the grammar had never gained:

| Missing from the grammar | Shipped by |
|---|---|
| string literals | F9 |
| `and` / `or` — it still had the **removed** `&&` / `\|\|` | ticket 44 |
| `var` bindings | F8 |
| `== name` match patterns | ticket 45 |
| `where` refinements | F2 |

**None of that debt was F11's, and the ledger should say so.** Four of the five grammar rules were
owed by earlier features — strings by **F9**, `and`/`or` by **ticket 44**, `var` by **F8**, `== name`
by **ticket 45**, `where` by **F2** — and they are paid here only because they were discovered here.
F11 owed the sixth (its own module syntax) and the gate fix. A future session looking for why F9 did
not update the grammar will find the answer at F9, and this paragraph is the pointer.

`check-tokens.sh` passed throughout, and its own header says why: it checks that a keyword is
*present*, not that any rule *uses* it. `and`, `or`, `var` and `where` were all in both grammars as
tokens while nothing consumed them. **A gate that cannot see past its first failure is a gate
reporting one problem and holding four**, and both are fixed here: the pipeline no longer aborts, and
the grammar gained all five forms plus this feature's own module syntax. The corpus gate is green for
the first time since F9.

Neither editor gate is in CI. That is the finding that outlives this feature.
