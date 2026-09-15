# 80 — Bootstrapping: which layer of B# is written in B#

Type: grilling
Status: resolved 2026-09-15 — [ENG-284](https://linear.app/davewil/issue/ENG-284). Named by David
2026-08-13 as the map's *Bootstrapping* patch; raised into Linear 2026-08-31 by the §19-as-queue
rule; claimed 2026-09-15 on David's reading of a post by José Valim
Blocked by: —

## Why this is raised now

David read this, 2026-09-15:

> Late to the party but self-hosting mostly doesn't matter. You will eventually want the parser
> (or a parser) written in the language, so you and the community can build formatters, AST
> rewriters, perhaps some static analyzers, but that's it.
>
> — José Valim, replying to *"been working on my programming language for a few weeks now. pretty
> sure self hosted compilers are a conspiracy theory"*

and asked what it means for B#. It means the ticket's axis (a) is smaller than the ticket wrote
it. ENG-284's body already says the question is *"not does it self-host but which layer"*, and
already records, measured on Elixir 1.19.5, that Elixir's tokenizer, parser and Erlang emitter are
`.erl` fourteen years in while `Kernel`, `GenServer` and `Supervisor` are `.ex`. Valim's post is
the author of that precedent saying which part of it was load-bearing: not the compiler in the
language, and not even the parser in the language, but **the AST as a value the language's own
programs can walk**, so that formatters, rewriters and analyzers get written. Elixir's own parser
is `yecc`; what makes it "in the language" is that `Code.string_to_quoted/1` returns ordinary
Elixir data, and `Code.Formatter` is written over that data in Elixir.

So axis (a) splits into two things, and only the first is load-bearing:

1. **The B# AST as a B# type, obtainable from a B# program.** What a formatter, a rewriter or an
   analyzer needs.
2. **A parser in B# that produces it.** Optional. Elixir has done without one.

The checker, lowering and emit stay Erlang. That is not asked here, because ticket 13 already
freed the host language and nothing since has put pressure on it.

## What is already decided, and is not reopened here

- **13** — the emission contract is abstract-format forms, and `erlc +from_abstr` builds from the
  serialised text. The host language is free; the compiler README records Erlang as a choice made
  for `leex`, `yecc` and `merl`.
- **18 §2, 32, F40** — a foreign declaration may promise only what one BEAM guard decides in O(1).
  A recursive union crosses as `term` and is established with `ValidateAs<T>` at a visible call
  site. A foreign return may not contain `string` anywhere; `binary` and `atom` are admissible.
- **F28** — recursive types are built, and **F28.9 built the recursive validator**:
  `ValidateAs<Tree>` generates a validator that calls itself, and `LANGUAGE.md` shows it shipped.
  Recorded here because F18's *Out of scope* still lists that validator as owed; the note is
  stale since 2026-08-30 and is corrected in place with this ticket.
- **F46** — a function is a value, `List.Map`, `List.Filter` and `List.Fold` take one, and
  `List.Sum` exists. An AST walker needs nothing more.
- **23 §10** — the map's out-of-scope entry rules out the *ecosystem track*, formatter and LSP
  named in it, and David's clarification the same day: *"Tooling is not out of scope if there's a
  genuine need."* `CLAUDE.md` now names the tooling as part 4 of the goal. The formatter is the
  first place those two statements meet, and this ticket is where they are reconciled.
- **Axis (b)** — graduated to [ticket 32](32-ffi-surface.md) and resolved 2026-08-14.
- **Axis (c)** — B# over `:gen_server`, never over Elixir's `GenServer`, because Elixir's macros
  export as `MACRO-` functions no other language can call ([prototype 32b](../prototypes/32b_name_census.md)).
  F10 shipped OTP callback emission 2026-08-15. Axis (c) is not asked in this round; see *What
  follows*.

## Why this matters more to B# than to the language Valim was replying to

An AST walker is a multi-clause function over a recursive union type. That is the language's
defining feature applied to its own syntax. Add a node kind to the language and every formatter,
rewriter and analyzer written in B# stops compiling, with the missing head printed as a
pasteable clause (F29). A formatter written in Erlang gets none of that. So for B# the AST as a B#
value is not ecosystem convenience. It is the thesis, demonstrated on the one program every tool
author has to write.

## What was measured, 2026-09-15

- `bs_parser.yrl` is 785 lines and `bs_lexer.xrl` 217. The parser builds **47 node kinds**:
  23 expression forms (`e_*`), 15 pattern forms (`p_*`), 9 type forms (`t_*`), plus the
  declaration records (`signature`, `param`, `type_alias`, `report`, `sized_by`, and the module
  and `using` forms).
- Of Valim's three consumers, two are writable in B# today and one is not. An **analyzer** and a
  **rewriter** are AST in, value or AST out; every construct they need has shipped. A
  **formatter** is AST in, text out, and **binary construction in expression position is
  unbuilt with no decision behind it** — the exemplars README row that 25c and 25e stop on
  (tickets 20 and 30, unasked). The formatter waits on the same wall as the dynamic web page.
- Recursion through `list<T>` resolves: `type Iodata = binary | list<Iodata>` is F28's own
  self-test. The AST type below needs exactly that shape.
- The tree-sitter grammar in `editor/` is already a second grammar kept in agreement with the
  yecc one by hand. A parser in B# would be a third.

## The program

A static analyzer, the smallest of Valim's three, over a slice of the expression grammar. Names
are atoms and string literals are binaries, because §11 refuses `string` in a foreign return and
an identifier is bounded anyway.

```csharp
module Calls

type Expr = (:int, int)
          | (:atom, atom)
          | (:var, atom)
          | (:str, binary)
          | (:tuple, list<Expr>)
          | (:op, atom, Expr, Expr)
          | (:call, atom, list<Expr>)
          | (:foreign_call, atom, atom, list<Expr>)

using :bs_front {
    term parse_expr(binary src)
}

public result<Expr, ValidationError> Read(binary src)

Read(src) -> ValidateAs<Expr>(parse_expr(src))

public int ForeignCalls(Expr e)

ForeignCalls((:int, _))                  -> 0
ForeignCalls((:atom, _))                 -> 0
ForeignCalls((:var, _))                  -> 0
ForeignCalls((:str, _))                  -> 0
ForeignCalls((:tuple, es))               -> es |> List.Map(ForeignCalls) |> List.Sum()
ForeignCalls((:op, _, l, r))             -> ForeignCalls(l) + ForeignCalls(r)
ForeignCalls((:call, _, args))           -> args |> List.Map(ForeignCalls) |> List.Sum()
ForeignCalls((:foreign_call, _, _, args)) -> 1 + (args |> List.Map(ForeignCalls) |> List.Sum())
```

Delete the `(:call, _, args)` clause and the compiler refuses the module with

```
not covered by the declared parameter type:
    (:call, atom, list<Expr>)
```

which is the whole argument in one residual: a language change that adds a node kind breaks every
tool at compile time, naming the clause each one owes.

### Under "yes, the AST crosses from the Erlang front end"

`ForeignCalls` compiles today; F28 partitions the eight members and F46 supplies the map. `Read`
compiles the day `bs_front` exists: `parse_expr/1` is declared `term`, which 18 §2 permits, and
`ValidateAs<Expr>` is F28.9's recursive validator, one O(n) pass at the boundary and never again.
The whole program runs with **no B# parser**.

### Under "no, the parser itself must be B#"

`ForeignCalls` compiles the same day. `Read` does not: the `using :bs_front` block has nothing
behind it, and `parse_expr` is a lexer over binary patterns (F13) plus a recursive-descent parser,
on the order of the thousand lines of `yecc` and `leex` it replaces, written before the first
analyzer can run. It is also a third grammar to keep in agreement, beside the yecc one that is the
oracle and the tree-sitter one that serves editors.

## The compiler delta, under "yes"

Concrete work, none of it a decision:

- **`bs_front:parse_expr/1`, `parse_module/1`** — a new Erlang module, one clause per yecc node
  kind, converting the parser's records to the tuple shapes the B# type declares. About 47
  clauses. The B# declaration is the contract: F28 already emits a recursive `-type` for it, so the
  converter is checkable against the declared type by ordinary Erlang tooling.
- **The AST as a B# module** — `Expr`, `Pattern`, `Type` and `Decl` declared in B#, in the tree,
  where a program reaches it through ticket 41's imports. Whether a prelude carries it is F28's own
  open question (its `iodata` note) and is not asked here. It ships as an example first, because
  the examples surface is the must-run one.
- **The failing test and the gate, before either** — every module under `compiler/examples/`
  parses through `bs_front` and validates under `ValidateAs<Decl>` with no error; and one
  example is an analyzer over the result. The gate is that the declared type and the converter
  agree, and it is red the first time a node kind is added to one and not the other, which is the
  defect it names.

## What follows the answer, and is not asked in this round

- **The order of (a) and (c).** ENG-284 owes it. Under yes, axis (a) is a feature and axis (c)
  is still the valuable target, so the order is (c) then (a) unless David says otherwise. Round 2
  asks only if the answer to Q1 leaves it open.
- **A parser in B#.** Under yes it is an exemplar candidate for ticket 25's set, not a compiler
  axis, and the hardest one there. Nothing in this ticket depends on it.
- **The formatter.** Gated by binary construction in expression position, which is 25e's wall and
  has no ticket. It gets one when the AST module exists and something wants to print it.
- **`bsc --ast`**, the same term on F16's channel for a consumer that is not a B# program. Cheap
  once `bs_front` exists, and F47 already carries the JSON encoding.

## Round 1 (2026-09-15)

**Q1.** Read `ForeignCalls` and `Read` above, and the residual. Is that the answer to axis (a):
the AST as a B# value, obtained from the Erlang front end through the FFI and established with
`ValidateAs<Expr>` at the boundary, with the checker, lowering and emit staying Erlang and no
parser in B# owed?

Under yes, the compiler delta above becomes a feature file, the parser in B# becomes an exemplar
candidate, and the ticket resolves with (c) ordered ahead of (a). Under no, round 2 asks the
parser in B# as the sole route and what it costs, starting with the third grammar.

**A1 — yes** (David, 2026-09-15): *"Self hosted parser is not required correct? I think for now
yes to q1 is there way forward."* Resolved on the one question, one round.

## The answer

Axis (a) is the AST as a B# value, obtained from the Erlang front end through the FFI and
established with `ValidateAs<Expr>` at the boundary. A parser in B# is **not required**. The
checker, lowering and emit stay Erlang, as ticket 13 already allowed and as Elixir's have.

Three things go with the yes, taken knowingly:

- **The declared B# type is the contract, and the Erlang side conforms to it.** The converter is
  written against the `-type` F28 emits for the declaration, not the other way round. When the
  grammar gains a node kind, the type gains a member first, and every walker in B# is refused
  until it carries the clause.
- **Names are atoms and string literals are binaries** in the AST, because §11 refuses `string` in
  a foreign return and an identifier is bounded. A walker that wants a `string` establishes it
  where it looks.
- **The formatter is not this ticket's.** It waits on binary construction in expression position,
  the wall 25e stops on, and gets a ticket when the AST module exists and something wants to
  print it. An analyzer and a rewriter compile today.

### What follows

- **[F48](../../compiler/features/F48-ast-as-a-value.md), [ENG-376](https://linear.app/davewil/issue/ENG-376)** — the feature: `bs_front`, the syntax module shipped as an example, the analyzer
  example, and the gate that the converter validates every example under `ValidateAs<Decl>`.
  Failing test and gate first.
- **Ordering.** Axis (c), the OTP layer in B#, is still the valuable target and stays ahead of
  F48 in the queue; F10 shipped the callback emission and (c) has no ticket of its own yet.
  Neither blocks the other.
- **A parser in B#** is an exemplar candidate for [ticket 25](25-exemplar-programs.md)'s set,
  the hardest one there, and nothing depends on it.
- **`LANGUAGE.md` §19's Bootstrapping bullet** now records the decision instead of a guess.

## Decisions entry

<!-- This ticket's entry. Read whole, here; the map (ENG-165) carries one line. -->

```decisions-entry
- [Bootstrapping: which layer of B# is written in B#](issues/80-bootstrapping-which-layer.md) —
  **the AST is a B# value, obtained from the Erlang front end through the FFI and established
  with `ValidateAs<Expr>` at the boundary; a parser in B# is not required, and the checker,
  lowering and emit stay Erlang.** Raised 2026-08-13 as the map's Bootstrapping patch, claimed
  and resolved 2026-09-15 in one round on one question, prompted by José Valim's *"you will
  eventually want the parser (or a parser) written in the language, so you and the community can
  build formatters, AST rewriters, perhaps some static analyzers, but that's it"*. What made
  Elixir's parser "in the language" was never its host: `Code.string_to_quoted/1` returns
  ordinary data and the formatter is written over it. For B# that is the thesis on its own
  syntax: an AST walker is a multi-clause function over a recursive union, and a new node kind
  refuses every tool naming the clause it owes. Measured: 47 node kinds in `bs_parser.yrl`; an
  analyzer and a rewriter compile today, a formatter waits on binary construction (25e's wall);
  F28.9 already built the recursive validator, correcting F18's stale note. Axis (b) was ticket
  32; axis (c), the OTP layer over `:gen_server`, remains the valuable target and stays ahead.
  Unbuilt — [F48](../compiler/features/F48-ast-as-a-value.md), ENG-376.
```
