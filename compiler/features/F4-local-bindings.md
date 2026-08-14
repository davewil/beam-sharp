# F4 — Local bindings: a body is names, then one expression

**Status**      **done 2026-08-14**
**Implements**  [ticket 34](../../wayfinder/issues/34-local-bindings.md) — decides nothing
**Unblocks**    nothing that was blocked; it removes a papercut every author hits
**Depends on**  F1

## Why this one, out of order

It was not on the list. It was raised, decided and built in one session because **David hit it in
the first minute of using the compiler** — `o = Order{Id = 1, Total = 500}` at the REPL, moments
after F3 shipped — and because the ticket that came out of it was answered the same day.

The ordering rule is *build what unblocks the most exemplars first*, and by that rule this is not
next: **no exemplar is blocked on it**, and the three that exist contain zero bindings. It is
built anyway on a different ground, which is worth stating so the rule is not quietly bent:
**the first thing a fluent reader reaches for should not be absent by accident.** It was absent by
accident — see the ticket.

## What ticket 34 decided

**Yes**, and the smallest form: a body is **zero or more bindings followed by one expression**.
The value of the body is the last expression, so a body is still an expression with names in front
of it, not a statement list that happens to end in a value.

```csharp
int Squared(Order o)

Squared(o) ->
    t = o.Total
    t * t
```

**Bindings do not shadow.** A name means one thing in a clause: rebinding is an error, including
rebinding something the clause head bound. There is no mutation to assign with, so a second
`x =` can only be a mistake — and ticket 08's *narrowing is always written, never inferred*
applies to names as much as to types.

**Destructuring on the left is NOT in this feature.** `(a, b) = pair` can fail, and a failing bind
is a branch the exhaustiveness checker never sees — which cuts against ticket 12's position that
partiality is visible. The machinery to settle it exists (`subtract(TypeOfExpr, TypeOfPattern)`
empty ⇒ provably irrefutable), but it needs a body that is *typed*, which is
[ticket 33](../../wayfinder/issues/33-body-check-site.md). **Deferred there, not refused.**

## What it cost

**The lowering is not a design question, and the ticket said it was.** Ticket 34 claimed a binding
would need a `case`/`begin` block and called that "a real emission question". Measured before
building — an Erlang clause body is **already a sequence** and `{match, …}` is an ordinary form:

```
f(5)      = 12                        %% f(O) -> B = O + 1, B * 2.
g({3,4})  = 7                         %% g(P) -> {A, B} = P, A + B.
g(:oops)  = {error,{badmatch,oops}}
```

So `bs_emit` emits a flat list rather than wrapping in a block — which also keeps the last
expression in **tail position**, pinned by a test that recurses 1000 deep with a binding in front
of the self-call.

**The grammar needed no terminator and yecc reports no conflict.** A binding is the only thing
that can put `=` after a lowercase name, and `=` is not an expression operator (equality is `==`),
so one token of lookahead separates `x = 1` from a body whose value is the variable `x`.

## Scenarios

| id | claim |
|---|---|
| F4.1 | a binding names a value and the body's value is the last expression |
| F4.2 | several bindings run in order, each seeing the ones above it |
| F4.3 | a projection bound once is read once — `Bump` emits two `map_get`s (boundary guard + binding), not three |
| F4.4 | a binding before a self-call stays a tail call — 1000-deep recursion returns |
| F4.5 | rebinding a name is an error |
| F4.6 | a binding may not shadow a parameter |
| F4.7 | an unbound name is caught by `bsc`, **not** by `erlc` against the emitted `.abstr` |
| F4.8 | an unused binding compiles clean, with no warning |

All eight pass. 77 tests, up from 69.

## The one thing that reads oddly

**A scope check walks a body, and ticket 33 says the checker does not do that.** The two are not
in tension and the distinction is worth keeping sharp: **33 is about whether a body is *typed***,
and nothing in F4.5–F4.7 asks what type anything has. These are name questions, decidable
syntactically, and they live in `bs_check` because the alternative is `erlc` reporting them
against a file the author did not write.

F4 therefore does **not** pre-empt ticket 33, and nothing here should be read as the beginning of
a body type-checker.

## Out of scope

- **Destructuring binds** — → ticket 33, above.
- **`x = 1` as an expression** (C's assignment-as-value). A binding is a body form, not an
  expression, so `f(x = 1)` does not parse.
- **Rebinding as shadowing.** Decided against, not deferred.
- **Typing the bound value.** A binding's type is as unchecked as every other body expression
  today — F4 changes nothing about that, in either direction.

## Done when

A `.bs` file binds names in a body and runs; rebinding, shadowing and unbound names are errors
from `bsc` with the fix stated; an unused binding is warning-free; a binding before a self-call is
still a tail call; `examples/shop.bs` uses one; `rebar3 eunit` is green. **All met.**
