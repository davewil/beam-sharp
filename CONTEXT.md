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
type is a bare type variable — though comparison and equality between two values of the same
variable are permitted, being non-dispatching and total. **Unbounded**: it ranges over every type,
and carries no constraint; there is no syntax for a bound. **Recoverable**: it must appear in at
least one parameter position, so instantiation is always determined by matching the arguments — user
code never writes a type argument.
_Avoid_: generic parameter, type argument, rigid variable, `a`, bounded type variable

**Binary type**:
`<<_:M, _:_*N>>` — a base of `M` bits followed by any number of repetitions of an `N`-bit unit.
`M` alone is a fixed size and a **closed** set; any `N > 0` makes the type **open**. Both halves
are decided by one BEAM guard in O(1), `M` by `byte_size`/`bit_size` and `N` by a modulus. Unions
over binary types are exact: two members where one contains the other absorb, and two that overlap
without containment are indiscriminable and rejected at the declaration.
_Avoid_: bitstring pattern, size specifier, binary spec

**Refinement**:
A predicate narrowing a type without changing its representation. Two tiers, divided by whether
the predicate is a BEAM guard: a **guard refinement** is reasoned about by the checker and is legal
in a clause head and in a foreign declaration, and may be user-declared; an **opaque refinement** is
O(n), is established once by generated code where a value enters and never reasoned about
afterwards, and is compiler-known only. A refinement is a set, so it does not confer type identity.
_Avoid_: predicate type, dependent type, constraint, subset type, newtype

**Interval**:
A set of integers with a lower and upper bound, unbounded at either end. Finite unions of them are
closed under union, intersection and complement, which is what lets a guard like `n > 1` be
credited as a type operation.
_Avoid_: range, bounded int, refined integer

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

**Pipe**:
`|>`, the single chaining form. `x |> F(a)` rewrites to `F(x, a)`; the name is always **qualified**,
so nothing is resolved by the type of `x`. There is no dot-call and no comprehension syntax.
_Avoid_: chain, fluent call, method call, forward operator

**Valve**:
`|?>`, the pipe that stops the flow. Where its left operand is `(:error, _)` the remaining stages do
not run and that error is the result; otherwise the stage applies. Named for what it is: a valve
stops flow in a pipe.
_Avoid_: bind, andThen, try operator, safe pipe, monadic pipe

**switch**:
The only branching construct, written postfix — `subject switch { pattern => expr, … }`. The clause
head's pattern grammar in expression position, so exhaustiveness is a hard error and the residual is
the missing arm. A ladder of unrelated conditions takes a tuple subject. There is no `if`, no `else`,
no `cond` and no ternary.
_Avoid_: case, match, if, cond, conditional expression

**Atom**:
An interned constant, written `:name`. Each atom is its own singleton type; the universe is open
and nothing declares an atom.
_Avoid_: symbol, enum member, constant, tag

**string**:
`binary` refined by valid UTF-8, and the language's only opaque refinement. A literal is a `string`
by construction, checked at compile time; a binary built or received at runtime becomes one only
through the generated entry check. Distinct from a bare `binary`, which is bytes.
_Avoid_: text, char list, String, utf8 binary

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

**Capability**:
An operation wanted over many types ("comparable", "serialisable", "has a length"). **Not a
construct** — the language has no ad-hoc polymorphism mechanism. A capability is served in one of
three ways, chosen by what the capability is: a codegen obligation where the type determines the
result, a union parameter where the set of types is known at the definition, or an ordinary
argument where it is not.
_Avoid_: type class, protocol, interface, trait, constraint

**Term order**:
The BEAM's total order over all values, which compares any two terms of any types. Reachable as a
named prelude function; it is **not** what `<` means, since comparison operators require operands
of the same type.
_Avoid_: natural order, default ordering, universal comparison

**Record**:
A type whose values are maps of named fields. Declared with `record`, which is sugar for a `type`
whose field set carries a **minted tag**. `type X = { ... }` declares the same shape without one.
Every declared field is always present in the term; there are no absent fields.
_Avoid_: struct, class, object, entity, POCO

**Minted tag**:
The discriminating field a `record` declaration adds, valued from the type's **qualified** name. It
is data *in the term*, not identity *in the type* — a hand-written `type` carrying the same tag is
the same type. It is what makes two records with otherwise identical fields distinct.
_Avoid_: type name, nominal tag, class marker, discriminant, `__struct__`

**Projection**:
`o.Field`, reading a field from a record value. The receiver's case decides what a dot means —
lowercase is a value and projects, PascalCase is a module and qualifies. Legal over a union where
every member carries the field. **Never a call**: nothing is dispatched by writing a dot.
_Avoid_: member access, property access, getter, attribute lookup

**Record update**:
`o with { Field = v }`, producing a new record differing in the named fields. **Width-preserving** —
it cannot add or remove a field, because a different field set is a different type. There is no
spread form.
_Avoid_: spread, merge, copy-with, mutation, setter

**Rest pattern**:
`[h, ..t]` — a fixed prefix of elements followed by the remainder bound as a list. Prefix-plus-rest
only: the rest is always final, and there is no form matching a suffix or an interior span. The same
spelling constructs (`[f(h), ..Map(t, f)]`).
_Avoid_: cons pattern, spread, splat, slice pattern, tail pattern

**Instantiation bracket**:
The `<...>` carrying a ground type argument to a codegen obligation, as in `ValidateAs<Order>(x)`.
Admissible **only** after a compiler-known codegen obligation, which is what makes `<` elsewhere
unconditionally a comparison. User code has no instantiation syntax, because a type variable is
always recoverable by matching.
_Avoid_: type argument list, generic argument, turbofish, explicit instantiation

**Prelude**:
The definitions and codegen obligations available without import.
_Avoid_: stdlib, core, builtins, runtime

## Codegen obligations

**Codegen obligation**:
A construct the compiler *generates* from a type rather than one a programmer writes. Monomorphic
at every use, and requires a **ground** type argument — so it is not a generic function, even
though the language has those. Admitted when the type determines the result uniquely, either
inherently or because the language publishes the mapping that fills the gap. The functional
equivalent of C#'s static abstract interface member, with the compiler supplying the
implementation.
_Avoid_: generic, template, macro, intrinsic, derive

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

**Boundary guard**:
A guard the compiler emits on an exported function's parameter, testing that the term supplied
inhabits the declared type. Emitted only where the function's own body would not already reject a
wrong term, and always where generated code will consume the value. Tests **shape**, never origin.
_Avoid_: runtime check, assertion, contract, precondition, type check

**The state channel**:
The three ways a value reaches a process's declared state type — `init`, `code_change/3`, and
`sys:replace_state`. Named as one channel because the defence sits at the entrances rather than on
the per-message path. Wider than the `code_change/3` state alone.
_Avoid_: state boundary, process state, code_change channel

**The boundary manifest**:
What the compiler publishes about an aggregate's exported surface: which functions are the client
API, which are contract callbacks, which are neither; where an asynchronous operation has no
synchronous observation; and which checks were **elided** rather than emitted. One artefact with
three outputs, not three artefacts.
_Avoid_: API dump, export list, manifest file, test manifest

**Elision**:
A check the compiler decided not to emit because something else already makes it unnecessary — a
literal that is a `string` by construction, a body whose own clause heads would reject the term, an
inlined prelude operation. Named because an elided check makes a test of that path measure nothing.
_Avoid_: optimisation, omission, skipped check

**The test boundary**:
The client API function exercised against a running process — the default level at which a
beam-sharp program is asserted on. Distinct from the **boundary guard**'s boundary, which is every
exported function; the test boundary is the narrower surface a caller is meant to use.
_Avoid_: unit, test level, public API, system boundary

## The design effort

**Lowering**:
The translation of a beam-sharp construct into the form actually emitted. Two senses, deliberately
one word: the **compiler's** lowering, which is a design choice with consequences for what the
emitted code's types say; and a **hand-written** lowering, a translation into Erlang that compiles
and runs, used to falsify sample code. Every hand-written lowering so far has found errors in code
that had only been read.
_Avoid_: compilation, transpilation, desugaring, example

**Silent unsoundness**:
The outcome where a badly-typed value from an untyped caller neither crashes nor is rejected, and
the type system is simply wrong. Worse than a crash, and the reason a crash counts as honest.
_Avoid_: type hole, unsafety, corruption

**Named limit**:
A case the design knowingly does not defend, recorded in the spec with the reason it is
unreachable rather than left to be discovered. Distinct from an open question: a limit is decided.
_Avoid_: known issue, caveat, gap, TODO

**Standing constraint**:
The premise that beam-sharp is written by agents and read by humans — so write cost carries little
weight, and read and review cost carry full weight.
_Avoid_: assumption, principle, requirement
