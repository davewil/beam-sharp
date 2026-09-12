# 76 — Two calls the F46 build took: where `n => e` may be written, and what a polymorphic callee's extent is once a parameter is an arrow

Type: grilling
Status: claimed 2026-09-13 — [ENG-367](https://linear.app/davewil/issue/ENG-367). Raised 2026-09-12 by
the F46 build ([ENG-365](https://linear.app/davewil/issue/ENG-365), landed `cd79a57`) as a decision
to confirm or overrule; grilled the same evening. Round 1's two questions were answered after
midnight and the ticket resolved at `272d35e`; reopened the same hour for round 2, because the
rule round 1 recorded for Q2 refuses function composition.
Blocked by: —

## Why this is raised now

[Ticket 75](75-a-function-as-a-value.md) decided a lambda is *an expression in C#'s spelling*, both
forms, on a table that measured `n => e` at one shift/reduce conflict against a switch arm's guard.
The build found the conflict reaches every guard that ends in a name — `x when x > m => 0`, F7's
own test — and moved the bare form into an `arg` nonterminal. It also found that a polymorphic
callee's maximal extent, ticket 37's *every variable at `term`*, refuses `Map`'s own recursive
call once a parameter is an arrow, and made the extent variance-aware. Both were taken as the
build found them; ENG-367 says confirming them costs nothing.

Two facts were measured for this grill that the issue did not have, and one of them makes that
sentence false.

## What was measured

**The bare form's real boundary is a parenthesis, not an argument list.** `arg` is reached only
through `expr_list`, and `expr_list` is used by every call form, the lambda's parameter list, *and*
the tuple `expr -> '(' expr_list ')'`, whose one-element branch returns the element. Probed at
`cd79a57` (scratch modules, `bsc` plain):

| program | at `cd79a57` |
|---|---|
| `Large(xs) -> xs \|> List.Filter(n => n > 100)` | compiles |
| `Rule(:member) -> n => n - 100` | `syntax error before: '=>'` |
| `Rule(:member) -> (n => n - 100)` | compiles, runs |
| `Pair() -> (1, n => n + 1)` under `public (int, fn(int) -> int) Pair()` | compiles, runs |
| `Fns() -> [n => n + 1]` | `syntax error before: '=>'` |

**C# has the same collision and resolves it in the guard, not in the lambda.** Roslyn parses a
switch-expression arm's `when` clause at `Precedence.Coalescing`
(`LanguageParser_Patterns.cs`, `ParseWhenClause(Precedence.Coalescing)` in
`parseSwitchExpressionArms`), and `Lambda = Assignment = Expression` is the loosest tier of its
precedence enum, so `x when x > m => 0` never reads `m => 0` as a lambda and `x => e` stays an
expression everywhere else. The same shape in yecc, measured on a copy of `cd79a57`'s
`bs_parser.yrl` with `{report, true}` (OTP 28, run plain):

| grammar | counted conflicts | `x when x > m => 0` | `x when (n > 3) => :high` | `n => e` at a clause body, in a list, after `var f =` |
|---|---|---|---|---|
| `cd79a57` as landed | 4 s/r, 0 r/r | ok | syntax error | syntax error |
| two tiers: `expr` = the three lambda productions over `expr_low` = the 30 existing productions; `guard_expr -> expr_low`; `arg` deleted | 5 s/r, 0 r/r | ok | **ok** | **ok** |
| the same with `expr -> expr_low '=>' expr` | 4 s/r, 0 r/r | ok | ok | ok |

The four counted at `cd79a57` are the type-level `fn(…) -> T | U`, `rule(`, `Double(` and
`Double{` — not `Double<` and `Double/`, which yecc resolves by operator precedence and does not
count; the grammar's comment is imprecise there. The fifth under two tiers is the `rule(` shift
reported again from a second LALR core, the same decision with the same shift target. The 4-count
variant buys that back at the price of a wrong message for `1 + n => n` (*a lambda's parameter is a
pattern*, pointing at `1 + n`). The change is 81 diff lines, all a rename of `expr` to `expr_low`
on the operand productions plus three moved lambda rules; `Right 45 '=>'` becomes inert, and the
build chooses which tier `raise`'s operand sits in (C#'s `throw` takes a `null_coalescing_expression`).

**The variance-aware extent is right and, alone, unsound.** Ticket 37's rule — *containment fails
exactly when an argument escapes its parameter's maximal extent* — was proved over covariant
positions. At `cd79a57` the callee table holds `erased_sig/4`'s output, `call/6` checks each
argument against it independently, and `instantiate/2` then solves the variables by union and
substitutes into the return only. The extent of `fn(T) -> U` is `fn(none) -> term`, which every
unary arrow satisfies, so an arrow argument can no longer fail the only check there is. With F46's
own `Map<T, U>`:

```csharp
public int Inc(int n)
Inc(n) -> n + 1

public list<int> Incs(list<string> xs)
Incs(xs) -> Map(xs, Inc/1)                // accepted; `Incs '["a"]'` crashes: function_clause

public int Len(string s)
Len(_) -> 0

public list<int> Lens(list<int> xs)
Lens(xs) -> Map(xs, Len/1)                // accepted; T is solved to int | string
```

and with `Twice<T>(T x, fn(T) -> T f)`, `Bad() -> Twice("a", Inc/1)` is refused only at the
return, where the compiler offers `public int | string Bad()`; taking the offer compiles clean and
crashes. The recursive `Map(t, f)` compiles under the new extent, and `Twice(3, Inc/1)` returns 5.
A nested arrow, `fn(fn(T) -> U, T) -> U`, neither crashes the compiler nor misbehaves.

Observed beside it, not this ticket's: `Apply2(3, (h) => h(4))` instantiates `T` at the singleton
`3`, ticket 37's least solution, and refuses `h(4)` — the literal-argument case of a decided rule.

## Round 1 (2026-09-12)

❓ **Q1 — Where the bare-name lambda may be written.** The same programs under the two grammars:

```csharp
//                                                        landed        C#'s line
Large(xs)     -> xs |> List.Filter(n => n > 100)          ok            ok
Rule(:member) -> n => n - 100                             syntax error  ok
Rule(:member) -> (n => n - 100)                           ok            ok
Pair()        -> (1, n => n + 1)                          ok            ok
Fns()         -> [n => n + 1]                             syntax error  ok
Grade(n) -> n switch { x when (n > 3) => :high, _ => :low }   syntax error  ok
Cmp(n, m) -> n switch { x when x > m => 0, x => 1 }           ok            ok
```

*Landed:* `n => e` is legal inside any parenthesis and nowhere else; the two guard shapes ticket
75 accepted as syntax errors stay so. *C#'s line:* the guard is parsed at the tier below the
lambda, so `n => e` is an expression at every site an arrow can be expected — clause body,
switch-arm body, `var` initialiser, list, tuple, record field, argument — and no guard shape is a
syntax error. Its compiler delta: split `expr` into a top tier holding the three lambda productions
over `expr_low` holding the existing thirty; `guard_expr -> expr_low`; delete `arg`; rewrite the
grammar's comment block and the `binary_tests` pin from 4 to 5 (or take the variant at 4 and its
worse message for `1 + n => n`); `CONTEXT.md`'s *Lambda* loses *"in argument position"*. The
keyword `fn(n) => e` is not on the table: 75 chose C#'s spelling.

➡️ **C#'s line.** It is the borrow 75 made, taken whole rather than at one position; it deletes
three syntax errors (two 75 accepted, one F46 added) and the parenthesis accident; and it was
measured at the same four intended shifts. What it costs is a rename in the grammar, not a
program.

---

❓ **Q2 — The extent, and the check beside it.** The variance-aware extent stands: `fn(none) ->
term` is ticket 11's top arrow, and `fn(term) -> term` refused `Map`'s own recursion. What
confirming it costs is the step ticket 37's proof let the compiler skip: once `instantiate/2` has
solved the variables, **each argument is re-checked against its instantiated parameter**, and an
occurrence under an arrow's domain **checks the solution rather than widening it** — 37's least
solution comes from the covariant occurrences, so `Lens` refuses `Len/1` because `int` is not
inside `string`, `Incs` refuses `Inc/1` because `string` is not inside `int`, and `Twice(3,
Inc/1)` still returns 5. Delta: the failing test first — `Incs` and `Lens`, refused, in
`function_value_tests` as F46.13 — then the re-check in `call/6` after `instantiate/2`, and
`solve`'s arrow clause stops joining the domain into the variable. Ticket 37's decisions entry
amends one phrase: *every variable at `term`* becomes *every variable at its extent — `term` in a
covariant position, `none` under an arrow's domain*. ENG-367's *"confirming costs nothing"* is
corrected on the issue.

➡️ **Confirm the extent; the re-check is owed as an F46 amendment, test first, under a build
issue this ticket names when it resolves.** Reverting to `fn(term) -> term` refuses every program
that passes a polymorphic function on, `Map` included; the extent was never the check, the
equivalence was, and it holds again once the arguments are looked at under the solution.

---

Assumed, not asked: the answers land here as this ticket's decisions entry, with a dated line in
75 beside Q2 and in 37 beside the extent rule pointing at it; which tier `raise`'s operand takes,
and 5 versus the 4-count variant, are the build's; the singleton instantiation above stays an
observation until a real program meets it.

**Answered 2026-09-13 (David):** Q1 — **C#'s line.** Q2 — **yes**: the extent stays and the
re-check is owed.

## Round 2 — what a domain occurrence does to the solution (2026-09-13)

Round 1's Q2 said the choice of solution *follows from ticket 37's least rule* and recorded: an
occurrence under an arrow's domain checks the least solution rather than widening it. That is
false for a variable the arguments mention only under a domain. Three programs, and the shipped
crash, under three rules:

```csharp
// 1 — composition: A occurs only under f's domain
public fn(A) -> C Compose<A, B, C>(fn(A) -> B f, fn(B) -> C g)
Compose(f, g) -> (a) => g(f(a))

public int Marked(int cents)
Marked(cents) -> var step = Compose(Inc/1, Double/1)
                 step(cents)

// 2 — a predicate declared wider than the list
public option<T> Pick<T>(list<T> xs, fn(T) -> bool p)
Pick([], _)       -> :nothing
Pick([h, ..t], p) -> p(h) switch { true => h, false => Pick(t, p) }

public bool Cheap(int | :free price)
Cheap(:free) -> true
Cheap(n)     -> n < 500

public option<int> FirstCheap(list<int> prices)
FirstCheap(prices) -> Pick(prices, Cheap/1)

// 3 — the crash from round 1
public list<int> Incs(list<string> xs)
Incs(xs) -> Map(xs, Inc/1)
```

| rule | `Marked` | `FirstCheap` | `Incs` | `Map`'s own recursion |
|---|---|---|---|---|
| **join every occurrence, then re-check** — today's `solve` plus the owed check | `A = int`, `step(cents)` runs | `T = int \| :free`; `option<int \| :free>` refused against the declared `option<int>` | refused | ok |
| **least from covariant occurrences, then check** — what round 1 recorded | `A` has no covariant occurrence: `A = none`, `step : fn(none) -> int`, `step(cents)` refused | `T = int`, ok | refused | ok |
| **solve by the variable's variance in the declared return** — lower bounds from covariant occurrences, upper bounds from domain occurrences; the variable takes the join of its lower bounds where the return is covariant in it or does not mention it, and the meet of its upper bounds where the return is contravariant in it; then every argument is re-checked | `A` is contravariant in `fn(A) -> C`: `A = int`, runs | `T` is covariant in `option<T>`: `T = int`, and `int` is inside `int \| :free`, ok | `string` is not inside `int`, refused | ok |

The third is the rule local type inference uses for the same problem (Pierce and Turner's
*Local Type Inference*, the choice of the best solution by the result type's variance — to be
checked against the paper before the F-file cites it). Ticket 37 chose *least* on the return
type's evidence over templates whose return was always covariant in its variables; this is that
choice extended to the first return that is not. Delta: `solve` keeps two bounds per variable
instead of one union; `instantiate/2` picks the bound by the variable's polarity in the declared
return, refuses when a lower bound escapes an upper one, and `call/6` re-checks the arguments
under the substitution. Round 1's delta had the re-check and the wrong choice.

❓ **Q3 — Which solution a variable takes when its occurrences pull two ways.**

➡️ **The third rule, by the return's variance.** It is the only one of the three under which all
four programs do what their author meant, and it is 37's *least* rule at every position 37
measured.

## Decisions entry

<!-- This ticket's entry. Read whole, here; the map (ENG-165) carries one line. -->

```decisions-entry
- [Two calls the F46 build took](issues/76-the-bare-name-lambda-and-the-arrows-extent.md) — **the
  bare-name lambda `n => e` is an expression everywhere, and the switch arm's guard is parsed at
  the tier below the lambda; a polymorphic callee's maximal extent is variance-aware, and every
  argument is re-checked against its instantiated parameter once the variables are solved.**
  Raised 2026-09-12 by the F46 build, which had shipped `n => e` as an argument only and the
  extent of `fn(T) -> U` as `fn(none) -> term`, and resolved 2026-09-13 in one round. **Ticket 75
  Q2 stands as answered** — both spellings, general expressions — and F46's narrowing is reversed:
  the collision F46 found, every guard ending in a name reading as a lambda, is the collision C#
  has, and C# resolves it in the guard (Roslyn parses a switch-expression arm's `when` clause at
  `Precedence.Coalescing`, above `Lambda`). In yecc that is `expr` split into a top tier of the
  three lambda productions over `expr_low`, the existing operand productions, with `guard_expr ->
  expr_low` and `arg` deleted — **measured** at 5 shift/reduce against the landed 4, 0
  reduce/reduce, the fifth being the `rule(` shift reported from a second LALR core, and a
  one-line variant at exactly 4. It deletes three syntax errors — `x when (n > 3) => :high` and
  `x when flag => 1`, which 75 accepted, and `Rule(:member) -> n => n - 100`, which F46 added —
  and the accident by which `(1, n => n + 1)` parsed while `[n => n + 1]` did not. **The extent is
  confirmed and was, alone, unsound**: ticket 37's *containment fails exactly when an argument
  escapes its maximal extent* was proved over covariant positions, and with the top arrow as the
  extent no arrow argument could fail the only check the compiler ran — `Map(xs, Inc/1)` with `xs
  : list<string>` compiled at `cd79a57` and crashed `function_clause`. The owed step: after
  `instantiate/2` solves the variables, each argument is checked against its instantiated
  parameter; how a domain occurrence enters the solution is round 2's Q3, open. 37's phrase *every variable at `term`* reads *every variable at its extent — `term`
  in a covariant position, `none` under an arrow's domain*. **Unbuilt, both**: the guard tier and
  the re-check are F46 amendments, the failing tests first (`Incs` and `Lens` refused; the seven
  programs of Q1's table), and *ENG-367's "confirming costs nothing" was false*.
```
