# beam-sharp

The design of a BEAM-targeting language with C#-family brace syntax, multi-clause function heads,
and a set-theoretic type system that proves clause exhaustiveness. This glossary fixes the terms
the design effort uses; the decisions themselves live in `wayfinder/`.

## The type lattice

**term**:
The top type — the set of all BEAM values. Every value from outside the language arrives as one.
Deliberately not an epistemic "we don't know", but a set you take complements of.
_Avoid_: `unknown`, `any`, dynamic, `dynamic()`

**none**:
The bottom type — the type with no values, and therefore a subtype of every type. An expression of
type `none` does not return.
_Avoid_: `never`, `no_return`, void, bottom

**Residual**:
What remains of a function's declared input type after subtracting everything its clauses match.
Empty means the function is exhaustive; non-empty names the case that has no clause.
_Avoid_: gap, uncovered set, remainder

**Open residual**:
A residual containing an unbounded top, so its inhabitants cannot be enumerated — typically because
a foreign sender chooses them.
_Avoid_: dynamic residual, unbounded gap

**Closed residual**:
A residual built only from declared cases, so the compiler knows each one by name.
_Avoid_: finite residual, known gap

**Discriminable**:
Of union members: distinguishable from one another by a synthesised BEAM guard. Indiscriminable
members are an error at the declaration.
_Avoid_: disjoint, tagged, distinguishable

**Alias**:
A name bound to a type by `type X = ...`. The single naming construct in the language; the name
never enters the type algebra, so two names over the same set are the same type. May take type
parameters (`type option<T> = T | :nothing;`), in which case it is a type-level function whose
application is substitution.
_Avoid_: declaration, definition, nominal type, newtype

**Type variable**:
A parameter standing for a type, declared on a signature or an alias (`Map<TSource, TResult>`) and
named by C#'s convention. **Opaque**: no clause head or guard may inspect a value whose declared
type is a bare type variable. **Unbounded**: it ranges over every type, and carries no constraint.
_Avoid_: generic parameter, type argument, rigid variable, `a`

## The language surface

**Clause**:
One `pattern -> body` equation of a function. A function is a list of them, dispatched by pattern
matching in order.
_Avoid_: case, branch, arm, overload, equation

**Signature**:
The declared type of a function, written above its clauses. Mandatory for multi-clause functions —
exhaustiveness is only well-posed against a declared input type.
_Avoid_: spec, type annotation, prototype, header

**Guard**:
A `when` condition refining a clause head. A **named guard** is one declared with the `guard`
modifier for reuse.
_Avoid_: predicate, filter, constraint, precondition

**Boundary clause**:
The clause that matches a function's open residual — the foreign case. Its existence is forced by
the checker; what it does is the author's choice.
_Avoid_: catch-all, default case, fallback

**raise**:
The construct that deliberately crashes. Typed `none`, and produces the BEAM's *error* class —
not its `throw` class, which is catchable.
_Avoid_: throw, panic, crash, abort, fail

**Atom**:
An interned constant, written `:name`. Each atom is its own singleton type; the universe is open
and nothing declares an atom.
_Avoid_: symbol, enum member, constant, tag

**option&lt;T&gt;**:
`T | :nothing`. The **absence** channel: a value is missing, and there is nothing further to say
about why. Bare because absence carries no information. Partial — an instantiation is rejected at
the declaration when `T | :nothing` ≡ `T`, which catches an atom top, a nested `option`, and a
colliding tuple shape alike.
_Avoid_: maybe, nullable, optional

**result&lt;T, E&gt;**:
`T | (:error, E)`. The **failure** channel: something went wrong and there is a reason to carry.
Tagged because it carries a payload, not for discrimination's own sake. The success side is
untagged — there is no `:ok`.
_Avoid_: either, try, outcome, Result with an ok tag

**foreign_error**:
`(:error, term) | (:throw, term) | (:exit, term)`. The `E` produced by a compiler-emitted foreign
wrapper, preserving *which* of the BEAM's three exception classes fired. Compiler-known: a user
cannot mint one.
_Avoid_: exception, error tuple, catch result

**Exit signal**:
A process-termination signal delivered from another process. **Not catchable** — distinct from a
locally-raised `exit`, which is, despite sharing the keyword. The distinction is why a foreign
wrapper may catch all three classes without swallowing a supervision decision.
_Avoid_: exit, exception, kill

**Prelude**:
The definitions and codegen obligations available without import.
_Avoid_: stdlib, core, builtins, runtime

## Codegen obligations

**Codegen obligation**:
A construct the compiler *generates* from a type rather than one a programmer writes. Monomorphic
at every use, and requires a **ground** type argument — so it is not a generic function, even
though the language has those.
_Avoid_: generic, template, macro, intrinsic

**ValidateAs&lt;T&gt;**:
A generated deep structural check that a `term` inhabits `T`, called explicitly. Returns
`result<T, ValidationError>`. Rejects arrow types at compile time, since a fun's type is not
recoverable at runtime.
_Avoid_: cast, coercion, decoder, parser, validator

**ValidationError**:
`ValidateAs<T>`'s reason: a path into the offending term plus the type expected there. A tuple
today; a record candidate if one is ever introduced.
_Avoid_: DecodeError, error message, failure

**Foreign wrapper**:
The `try`/`catch` the compiler emits around a foreign call declared to return a `result`. The only
place exception handling exists — there is no `try` in the surface language.
_Avoid_: FFI shim, catch block, rescue, guard

**ParseAtom&lt;T&gt;**:
A generated check that a runtime-built value is one of `T`'s atoms.
_Avoid_: to_atom, intern, atom cast

## The design effort

**Lowering**:
A hand-written translation of beam-sharp source into Erlang that compiles and runs, used to falsify
sample code. Every lowering written so far has found errors in code that had only been read.
_Avoid_: compilation, transpilation, desugaring, example

**Silent unsoundness**:
The outcome where a badly-typed value from an untyped caller neither crashes nor is rejected, and
the type system is simply wrong. Worse than a crash, and the reason a crash counts as honest.
_Avoid_: type hole, unsafety, corruption

**Standing constraint**:
The premise that beam-sharp is written by agents and read by humans — so write cost carries little
weight, and read and review cost carry full weight.
_Avoid_: assumption, principle, requirement
