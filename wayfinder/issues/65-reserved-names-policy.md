# 65 — Reserved names: the policy, not one name at a time

Type: grilling
Status: open — [ENG-255](https://linear.app/davewil/issue/ENG-255)

Raised 2026-08-25 when [ticket 48](48-a-map-type-in-the-prelude.md)'s question 9 escaped its scope.
The answer there was about `map<K, V>`'s operations; the rule it implies reaches the whole standard
environment, and belongs somewhere more central than a map ticket.

## Question

**B# reserves no name today. 48 decided `Map` becomes the first. What governs the rest?**

## What 48 settled, and what it left

`Map.Get` is reached through a qualifier, and the qualifier is **reserved** — a user cannot declare
`module Map`. Measured before deciding: nothing declares `module Map` today, and the only bare
`module List` in the tree sits inside probe [`48h`](../prototypes/48h_map_name_is_free.sh), not
shipped code. B# reserves no identifier or module name at all; ticket 08 reserved the `=>`
**token**, which is a different thing.

So `Map` costs nothing. **The next one might.**

## The question, stated as a policy

The same rule applied to the rest of the standard environment reserves `List`, `String`, and
whatever else it eventually names. Decide it **once, while the list is empty**, rather than one name
at a time as each module lands.

1. **Reserve per module.** One burned name each, refused at the declaration with a diagnostic.
   Predictable, and every language protects its standard module names somehow. The list grows
   forever.
2. **A namespace the user's syntax cannot reach** — 48's question 9 option (d). Nothing is burned,
   but it needs a spelling B# has not got.
3. **User names win.** The standard-environment name is shadowed rather than protected.

## The evidence points at 3 harder than expected

Surveyed 2026-08-25 against primary sources
([research](../research/prelude-the-word-across-languages.md)): **five languages independently
landed on "user names must win"**, and four of the five only after shipping.

| | how it landed there |
|---|---|
| Haskell | abolished `PreludeCore` (1.3, 1996) after users were *"deeply unhappy"* they could not redefine `+`, `==`, `>` |
| Rust | prelude editions in 2021 and 2024, because adding a trait breaks method resolution |
| Erlang | OTP 26 permitted a user type to shadow a built-in type name |
| Scala | root contexts are *"lowest precedence… **always shadowed by user code**"* — **by design** |
| Elm | keeps default imports small and *"very unlikely to overlap"* |

**Scala is the one that designed it in rather than retrofitting.** And Elixir is the counter-example
showing what not protecting costs: `defmodule Map` warns, clobbers the standard module, and then
**crashes Elixir's own type checker**, which was calling `Map.update!/3`.

## The consideration that may make 1 right anyway

That lesson is about namespaces that **accrete**. A closed, compiler-owned set does not have the
problem at all — nothing new ever arrives to collide. If B#'s standard environment is small and
closed *by intent*, reserving is cheap and shadowing solves a problem it does not have.

**Deciding whether it is closed is deciding this ticket**, and that is the question to put first.

## Notes

Do not read the five-language table as a verdict. Four of those languages have preludes that
accrete over decades of library growth; B#'s standard environment is currently `map` plus a
collection library that has not been designed. The table says what happens *if* it grows.
