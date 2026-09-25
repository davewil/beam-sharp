# 106 — May a `using` declaration bind a B# name to a foreign atom?

Type: grilling
Status: resolved 2026-09-25 — [ENG-469](https://linear.app/davewil/issue/ENG-469). Raised and
answered 2026-09-25 out of [ENG-250](https://linear.app/davewil/issue/ENG-250); one question, one
round
Blocked by: —

## Why this is raised

Elixir's raising variants (`get!`, `fetch!`, `decode!`) compile to atoms B# cannot spell, and
[50](50-naming-a-foreign-struct.md)'s decisions entry says reaching one needs an alias: a B# name
bound to the foreign atom. [32](32-ffi-surface.md)'s decisions entry had decided that shape, *"a
foreign function is declared, and the declaration carries both spellings"*. What shipped is
LANGUAGE.md §11's `using :module { }`, which *"attaches types to the name Erlang already has. It
does not introduce a B# name"*, and [41](41-imports-and-cross-module-scope.md) argued its native
`using` from that property. ENG-250 carried the conflict.

## The program

Measured at `f1180d8`:

```csharp
module Fetch

using :'Elixir.Req' {
    term get(binary url)
    term get!(binary url)
}

public term Page(binary url)
Page(u) -> get!(u)
```

is refused at `get!` with F27's `beam-sharp has no !`, whose text explains **negation**
(*"negation is not an operator here … `!=` for `not ==`"*), which misleads here since the `!` is
part of a name.

## Q1 — May a `using` entry bind its own B# name?

Under yes:

```csharp
using :'Elixir.Req' {
    term GetOrCrash(binary url) = :'get!'
}

public term Page(binary url)
Page(u) -> GetOrCrash(u)
```

Under no, the bang functions stay unreachable and the non-raising `get/1` is declared as an
ordinary union (ticket [56](56-foreign-value-returned-error.md)) and handled in a `switch`.

**A1 (David, 2026-09-25):** *"Yes."*

## The compiler delta

- The grammar gains an alias on a `using` entry: the B# signature, then `= :'atom'` naming the
  foreign function. The spelling shown to David is the proposal; the build confirms it against
  `bs_parser.yrl` and the tree-sitter grammar with a measured conflict count, both before and after.
- `bs_check` binds the B# name in the module's scope and records the foreign atom; `bs_emit`
  emits the remote call to the atom. An entry with no alias behaves exactly as today.
- An entry whose own name B# cannot spell (`get!`) is refused with a message that says so and
  names the alias form, replacing F27's negation text at that site. F27's message stays as it is
  in a guard or refinement, where negation is what was meant.
- LANGUAGE.md §11's *"does not introduce a B# name"* becomes *"introduces no B# name unless the
  entry gives one"*, with the alias demonstrated; ticket 41's argument from that property is
  amended in place, dated.

## Not decided here

- **What aliases are conventionally called.** Elixir's plain name returns and `!` raises; C#'s
  plain name throws. For user aliases the author chooses. The standard environment already has a
  precedent: ticket [96](96-standard-environment-breadth.md) Q3 made the crashing form the plain
  name (`Map.Get`), with the non-crashing form waiting on ENG-324's spelling.
- Whether the alias is allowed on a native (B#-to-B#) `using`. This ticket reaches foreign
  entries only.

## Decisions entry

<!-- This ticket's entry. Read whole, here; the map (ENG-165) carries one line. -->

```decisions-entry
- [May a `using` declaration bind a B# name to a foreign atom?](issues/106-a-using-alias.md)
  — **yes: a foreign `using` entry may bind its own B# name to the foreign atom, `term
  GetOrCrash(binary url) = :'get!'`, so Elixir's bang functions are reachable.** Raised and
  resolved 2026-09-25 in one round on one question, out of
  [ENG-250](https://linear.app/davewil/issue/ENG-250), where ticket
  [50](issues/50-naming-a-foreign-struct.md) required an alias and LANGUAGE.md §11 said a `using`
  introduces no B# name. It returns to [32](issues/32-ffi-surface.md)'s both-spellings form on a
  per-entry basis; an entry with no alias is unchanged, and §11 and
  [41](issues/41-imports-and-cross-module-scope.md) are amended in place. An unspellable name
  without an alias is refused naming the alias form, replacing F27's negation text at that site.
  Naming convention not decided: the author chooses, and 96 Q3's crash-is-plain is the standard
  environment's precedent. Unbuilt — ENG-250.
```
