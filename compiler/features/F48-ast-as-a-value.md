# F48 — the AST as a B# value: `bs_front` and the syntax module

**Status**      not started · [ENG-376](https://linear.app/davewil/issue/ENG-376)
**Implements**  [ticket 100](../../wayfinder/issues/100-bootstrapping-which-layer.md), resolved
                2026-09-15: the AST is a B# value obtained from the Erlang front end through the
                FFI and established with `ValidateAs<Expr>` at the boundary; no parser in B# is
                owed. Draws on [18 §2](../../wayfinder/issues/18-boundary-defence.md) for what a
                foreign return may promise, [32](../../wayfinder/issues/32-ffi-surface.md) for
                the `using :module { }` spelling, and F28 for the recursive type and its
                validator. It **decides nothing**.
**Unblocks**    the first analyzer written in B#, and through it every tool Valim's list names
                except the formatter; `bsc --ast` on F16's channel once `bs_front` exists.
**Depends on**  F28 (recursive types, F28.9's validator), F46 (`List.Map`, `List.Sum` over a
                function value), F41 (`using` of a foreign module), F15 (module as a directory).

## Why this one now

Because ticket 100 resolved it as a feature and not a decision: every rule it needs was taken
before it was asked. The compiler README records Erlang as the host by choice; 18 §2 says a
recursive union crosses as `term` and is established at a visible call; F28.9 built the
validator that establishes it. What is missing is a producer on the Erlang side and a declaration
on the B# side, and the gate that keeps the two in agreement.

And because it is the defining feature on the language's own syntax. An AST walker is a
multi-clause function over a recursive union type. Delete a clause and the residual names the
node kind; add a node kind to the grammar and every walker is refused until it carries the
clause. No exemplar in ticket 25's set shows that as directly.

## What ships

- **`bs_front`**, an Erlang module: `parse_expr/1` and `parse_module/1` take a binary of source
  and return the parser's tree converted to the tuple shapes the B# declaration names. One clause
  per yecc node kind, 53 at `057fec6`: 26 `e_*`, 18 `p_*`, 9 `t_*`, plus the declaration tuples
  (`bind`, `dbind`, `record_decl`). Names are atoms and string literals are binaries, because §11
  refuses `string` in a foreign return.

  *Refreshed 2026-09-25, when this file and its ticket reached master ten days after they were
  written (on an unmerged branch; the ticket is 100, since master reused 80). The count written
  then was 47 as 23/15/9; the fork point `3fb8bb7` actually held 23/16/8. Six kinds have arrived
  since: `e_float`, `e_neg` and `p_float` (F51), `e_map` (F57's brace expression), `p_type`
  (F53's type prefix) and `t_map_open` (F59's open field set). The gate below is what keeps this
  number true, so it is no longer load-bearing here. Re-checked and unchanged: §11 still refuses
  `string` in a foreign return, and `List.Map` and `List.Sum` are still rows (F62's table) —
  ENG-453 may move the analyzer's calls to `Enum`.*
- **`examples/Syntax/`**, a B# module declaring `Expr`, `Pattern`, `Type` and `Decl` as recursive
  unions, with `Read(binary)` declared over `term parse_module(binary)` and established by
  `ValidateAs<Decl>`. It ships as an example because the examples surface is the must-run one;
  whether a prelude carries it is F28's own `iodata` question and is not this feature's.
- **An analyzer example** over the result, ticket 100's `ForeignCalls` or its module-level
  equivalent, so the exhaustiveness argument is visible in the tree and refused by the gate when
  a clause is deleted.

## The compiler delta

- `compiler/src/bs_front.erl`: the converter. The B# declaration is the contract; F28 emits a
  recursive `-type` for it, and the converter is written against that type, never the reverse.
- The `Syntax` example module and the analyzer, both under `compiler/examples/`, both rows in
  `every_shipped_surface_form_has_an_example_test`'s list.
- No change to `bs_parser.yrl`, `bs_check`, `bs_lower` or `bs_emit`. If the converter needs a
  change to the parser's records, that is a finding to record here, not a silent edit.

## The scenarios

| Id | Input | Command | Expected | Exit |
|---|---|---|---|---|
| F48.1 | `examples/Syntax` with a source binary holding `1 + f(2)` | `bsc examples/Syntax ReadExpr '<<"1 + f(2)">>'` | `(:ok, (:op, :+, (:int, 1), (:call, :f, [(:int, 2)])))` | 0 |
| F48.2 | the analyzer over a module that makes two foreign calls | `bsc examples/Calls Count …` | `2` | 0 |
| F48.3 | the analyzer with its `(:call, _, args)` clause deleted | `bsc examples/Calls` | the residual naming `(:call, atom, list<Expr>)` | 1 |
| F48.4 | every module under `compiler/examples/`, through `bs_front:parse_module/1` and `ValidateAs<Decl>` | the gate | no `(:error, _)` anywhere | 0 |
| F48.5 | a term `bs_front` did not produce, `(:node, :leaf, 7)`, handed to `ValidateAs<Expr>` | `bsc examples/Syntax ReadTerm …` | `(:error, (["(3)"], "Expr"))` — F28.9's pathed error, so the boundary is real and not decorative | 0 |

## The gate

`bin/check-syntax.sh`: every example parses through `bs_front` and validates under
`ValidateAs<Decl>`. Its `--self-test` builds both defects it names, a node kind added to the yecc
grammar and not to the declaration, and the reverse, requires a red on each, and a green on the
tree beside them. Written before `bs_front`, red on the tree until it exists.

## Out of scope

- **A formatter.** AST in, text out, and binary construction in expression position is unbuilt
  with no decision behind it (the exemplars README row 25c and 25e stop on). It gets a ticket
  when something wants to print the tree.
- **A parser in B#.** An exemplar candidate for ticket 25's set, never a compiler axis. Ticket 100
  Q1 answered.
- **`bsc --ast`.** The same term on F16's channel for a consumer that is not a B# program. Cheap
  once `bs_front` exists; its own row when asked for.
- **Source positions.** F35 split line and column for diagnostics; whether the AST carries them
  is the first thing a rewriter will ask and is deferred to that rewriter.

## Done when

`bsc examples/Calls` counts the foreign calls in a module it read through `bs_front`, deleting a
clause of the analyzer is refused naming the node kind, `check-syntax.sh` is green over every
example and red under its own self-test, and `verify.sh` passes twice from a clean checkout.
