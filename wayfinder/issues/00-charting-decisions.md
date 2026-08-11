# 00 — Charting decisions: differentiator, typing stance, scope

Type: grilling
Status: resolved

## Question

What is this language for, given Gleam already exists; what typing discipline does it
commit to; and what is deliberately outside the effort?

## Answer

### The differentiator is multi-clause function heads

Gleam is already a statically-typed, brace-syntax, no-OOP BEAM language, so "C# syntax on
the BEAM" alone is redundant with it. The gap is a **semantic** one: Gleam gives you one
function body and makes you `case` inside it.

> "Gleam does not support multiple function heads, so to pattern match on an argument a
> case expression must be used."
> — [Gleam for Erlang users cheat sheet](https://gleam.run/cheatsheets/gleam-for-erlang-users/)

The language exists to provide Erlang/Elixir-style **multi-clause function heads with
pattern destructuring in the argument position**, in a syntax a mainstream imperative
developer reads on sight.

Two supporting observations, recorded because they shape later tickets:

- **C# already has a syntactic shape that reads as multi-clause**: method overloads.
  Several bodies, one name, different parameter shapes. C# dispatches on static types;
  the BEAM dispatches on values and structure. The visual shape may be reusable.
- **The feature's best showcase is OTP callbacks.** `handle_call/3`, `handle_cast/2` and
  `handle_info/2` are where Elixir developers spend most of their multi-clause budget, one
  clause per message shape. It is also where Gleam's single-head rule hurts most. The
  headline feature and the OTP interop model are therefore not separable questions — which
  is why OTP is inside the destination rather than deferred.

### Two premises corrected during charting

- **Static typing on the BEAM is not novel.** Gleam is fully static, using
  [Hindley-Milner inference with pattern-match exhaustiveness checking](https://deepwiki.com/gleam-lang/gleam/2.3-type-inference-system),
  and [purerl](https://github.com/purerl/purerl) puts PureScript's Haskell-grade type
  system on the BEAM — and PureScript *does* support multiple equations per function. The
  defensible gap is narrower: static typing **plus** multi-clause heads **plus** mainstream
  imperative syntax.
- **Elixir's set-theoretic types are further along than assumed.**
  [Elixir v1.20 shipped in June 2026 as "a gradually typed language"](https://elixir-lang.org/blog/2026/06/03/elixir-v1-20-0-released/):
  every program is gradually type checked with no annotations required, using inference and
  a `dynamic()` type that behaves as a range. Type *signatures* are not yet shipped; the
  roadmap is typed structs first, then set-theoretic function signatures, gated on
  type-checker performance.

### Typing stance: static-by-default, set-theoretic, exhaustiveness enforced

Set-theoretic types and multi-clause heads are a natural pair. Each clause's pattern
describes a **set** of accepted values; a function's domain is the **union** of its clauses'
patterns; exhaustiveness is the question of whether that union covers the declared input
type. That is precisely the arithmetic semantic subtyping is built for — Castagna's CDuce
had overloaded functions with pattern-matched arguments as a founding use case.

Hindley-Milner fights this shape: it wants one nominal ADT per parameter and one match
site, which is a plausible reason Gleam landed on single heads plus `case`. Choosing HM
would mean re-fighting a battle Gleam already lost.

**Committed**: set-theoretic types as the machinery; **strict by default** — inference
everywhere, `dynamic()` an opt-in escape hatch mainly at the Erlang/Elixir interop
boundary; clause exhaustiveness enforced at compile time.

Difficulty was raised as a cost and explicitly dismissed: *"Hard to build is not a reason
not to proceed. Because it's hard is more of a reason."*

### Destination and scope

The destination is a design spec covering syntax, type system, multi-clause semantics,
OTP/concurrency and interop, and compilation target — plus a walking-skeleton compiler over
a slice **carved later**. An attempt to fix the skeleton's scope during charting was
correctly rejected: describe the language first, then carve. That scope is therefore fog,
not a ticket.

Ruled out of scope: tooling and ecosystem; standard library breadth; macros and
metaprogramming; alternative backends. See the map's Out of scope section.

### A tension surfaced but not resolved here

C# 15 ships discriminated unions with a `union` keyword in .NET 11
([csharplang #8928](https://github.com/dotnet/csharplang/issues/8928),
[preview April 2026, GA expected November 2026](https://benjamin-abt.com/blog/2026/03/09/csharp-15-unions-and-unio/)),
with compiler-checked exhaustive switching and no `default` arm. But **C# unions are
nominal and closed** — a declared, fixed set of case types — whereas **TypeScript's and
set-theoretic unions are structural and open**. BEAM data is structural and carries no
nominal identity. The headline feature pulls structural; the syntax goal pulls nominal.
Deferred to ticket 09.
