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

## Round 1 — 2026-11-12

Measured on Erlang/OTP 28.5 (built from `otp_src_28.5`, the pinned release) with rebar3 3.27.0,
against an unmodified `compiler/` at `24e769f`. The probes are in
[the research file](../research/65-reserved-names-policy.md) and are printed by
[`65a`](../prototypes/65a_what_is_reserved_today.sh).

**Everything above was written while the list was empty, and it no longer is.**
[Ticket 67](67-stdlib-shape-as-a-principle.md) Q1 answered *"is it closed"* on 2026-09-03: closed
by construction. Its Q6 answered what the compiler says to a user module of a reserved name.
[Ticket 96](96-standard-environment-breadth.md) Q6 answered which names on 2026-09-25: *"what the
standard environment qualifies is reserved, and nothing else."* F32, F51, F62, F64 and F75 built
it. Ticket 67 left this ticket open with one sentence, *"its reservation policy stays its own to
decide"*, and no program was found that the sentence still covers.

### The program

```csharp
// List/List.bs
module List

public int Go(int n)
Go(n) -> n
```

```csharp
// Shop/List/List.bs
module Shop.List

public int Sum(list<int> xs, int acc)
Sum([], acc)          -> acc
Sum([x, ..rest], acc) -> Sum(rest, acc + x)
```

```csharp
// Short/Short.bs
module Short

using Shop

public int Go(int n)
Go(n) -> List.Sum([n, n, n], 0)
```

Today the first is refused at its declaration:

```
List/List.bs:1:1: error: `List` is a reserved qualifier, so no module may be called it
  `List.` names operations the compiler knows and inlines at the site;
  no beam ships for it and no `using` is ever written. The name is
  taken only as a WHOLE module name — `Shop.List` is still legal, and
  so is any other path with `List` as a segment.
```

The second compiles, and `Sum([1, 2, 3], 0)` prints `6`. The third is refused at the call:

```
Short/Short.bs:6:14: error: Go calls List.Sum, and `List` means two things here
  `List` is a reserved qualifier — the compiler's own operations —
  and a `using` line also short-qualifies these to it:
    Shop.List.Sum(...)
  write the module's full path to reach it, or drop the namespace
  import to reach `List.Sum`.
```

Written `Shop.List.Sum([n, n, n], 0)`, it prints `6`. `Map`, `Term`, `Float` and the protocol
name `Enumerable` behave as `List` does. In no probe did a user module answer to a reserved word.

So of the three policies above, the first is what is built, for the bare name only: ticket 48
refused `module Map`, ticket 67 Q6 declined to refuse the path segment and refused the ambiguous
call instead, and ticket 96 Q6 made the list a rule.

The two entries other tickets handed here are held by the grammar. `bs@`
([ticket 87](87-an-export-the-author-did-not-write.md)) cannot be written: `public int bs@x(int n)`
is `illegal characters "@"`. `not` ([ticket 63](63-negation-has-no-spelling.md)) is an identifier,
and nothing since has asked to take it.

### The question

**Is this ticket closed as settled by ticket 67 Q6 and ticket 96 Q6?**

### Under each answer

**Yes.** All three programs do what they do today. The compiler gains nothing. This file gains a
`## Decisions entry` that says where the policy lives: a bare module of a reserved name is refused
at the declaration (48), a path holding the word is legal and the short-qualified call is refused
(67 Q6), the reserved names are the qualifiers the standard environment has and no others (96 Q6),
`bs@` is the compiler's by the lexer's rule, and `not` stays an identifier. ENG-255 is set Done.

**No.** All three programs do what they do today and the ticket stays open. It then needs the
program that 67 Q6 and 96 Q6 leave undecided, and the probes did not find one. The nearest is
`module String`, which compiles at `24e769f` and is refused on the day ENG-455 lands the `String`
rows. Ticket 96 Q6's *"every qualifier the standard environment adds is reserved"* already reads
as reserved when added, and ENG-455's title carries *"and `String` reserved"*.

**Recommended:** yes, because every program this ticket's three policies disagree about already
compiles or is refused by a rule a later ticket decided and a feature built.
