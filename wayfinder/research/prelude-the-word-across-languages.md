# "Prelude" — where the word came from, and what it reliably means

Raised 2026-08-25 by David, after the prelude/standard-library vocabulary was corrected:
*"prelude is a term I heard from Haskell, so probably worth considering why that Haskell term, and
which other languages have a prelude that was picked up in this project."*

Primary sources only. Where no primary source exists, that is stated rather than filled in.

## 0. Provenance inside this project — the word was never chosen

`prelude` appears in [ticket 10](../issues/10-atoms-in-a-csharp-skin.md) as **established
vocabulary from its first use** — *"`bool` is a prelude alias"*, *"the prelude cannot mint"* — and
**no ticket ever settles it**. `CONTEXT.md` defines it without citing one. What *was* borrowed
deliberately is the **structure**, not the name: `decisions.md` records *"The prelude is stratified
à la Elixir's `Kernel.SpecialForms`"*, so stratum 2 ≈ SpecialForms (compiler-owned, a user may not
add to it). **The shape is Elixir's; only the word is Haskell's, and it arrived unexamined.**

## 1. Why "prelude" in Haskell — no primary source says

| Checked | Result |
|---|---|
| Haskell 2010 Report §5.6 | names it, no gloss |
| *A History of Haskell* (HOPL III, 2007) | 8 occurrences, **none etymological** |
| Haskell 1.0 Report preface (1990) | explains why *"Haskell"* (Haskell B. Curry); **silent on "Prelude"** |
| Haskell 1.0 `modules.verb` | introduces the term in scare quotes, no explanation |
| Miranda system manual | **zero** occurrences |

**One attested prior use, and its limit.** *A History of Haskell*, written by the designers, says
the first GHC prototype found *"the larger Haskell prelude stressed the LML prelude mechanism quite
badly"* — which attests that **LML had one first**. It does *not* attest that Haskell took the word
from LML, and no LML manual was located. A lead, not a derivation.

Notably **Haskell's closest ancestor did not use the word.** Miranda's is *"the standard
environment"*, in a file called `stdenv.m`.

## 2. The word connotes very little

- **Not implicitness.** PureScript: *"There is no implicit `Prelude` import in PureScript, the
  `Prelude` module is just like any other."*
- **Not one thing.** Rust has **five** preludes — standard library, extern, language, macro_use,
  tool. *"The prelude"* unqualified is ambiguous there.
- **Not a module.** Rust: *"A prelude is a collection of names… not part of the module itself."*
- **Not functions.** Gleam's contains none (§4).

**And Rust does not credit Haskell for it.** Its Influences page credits Haskell for *"typeclasses,
type families"*; the word "Haskell" appears nowhere in `std::prelude`, the Reference's Preludes
page, RFC 0503, or RFC 3114.

## 3. The direct historical precedent — and why it failed

**Haskell 1.0 (April 1990) had exactly the split this project is contemplating, and Haskell 1.3
(May 1996) abolished it.** `PreludeCore` held *"all the algebraic data types, type synonyms, classes
and instance declarations"*, was *"always implicitly imported"*, could not be hidden or renamed, and
its export list contained **no free-standing functions**. Its own header comment: `-- Standard
types, classes, and instances`.

It was killed because *"names defined in PreludeCore cannot be redefined in any way. Since many
operators, like `+`, `-`, `>`, and `==`, are defined in PreludeCore this has made some users deeply
unhappy."* What replaced it: *"an implicit (and unavoidable) qualified import of the Prelude which
is used to define the meaning of various pieces of syntactic sugar."*

**The failure mechanism does not reach B#, and that is the load-bearing point.** PreludeCore was
types **+ classes + instances**, and the class *methods* — `+`, `==`, `max` — came in with the
classes. A types-only layer locked operators only because classes were in it.
[Ticket 16](../issues/16-ad-hoc-polymorphism.md) killed type classes for B#: *"dead on ticket 09…
Resolution keys on a nominal head"*. **With no class-like construct, B#'s types-only layer cannot
capture operators, so the 1996 failure cannot recur here.**

## 4. Who has a types-only one — Gleam, on this platform

**Gleam is the direct hit.** Its prelude module contains types `BitArray, Bool, Float, Int, List,
Nil, Result, String, UtfCodepoint` and constructors `True, False, Ok, Error, Nil` — every entry a
data constructor, **zero function values**. Same platform, and shape-identical to B#'s. The word is
used throughout the compiler source (`PRELUDE_MODULE_NAME`, `is_prelude_module`) and in the
changelog; it was not found on the user-facing tour pages, though those are JS shells so that is
weak evidence of absence.

**Rust's *language* prelude** is the other: types and built-in attributes, *"always in scope"*, and
explicitly exempt from `no_implicit_prelude`. Note what versioning history says — Rust needed new
preludes in **2021** (`TryFrom`, `TryInto`, `FromIterator`) and **2024** (`Future`, `IntoFuture`)
because *"adding a trait to the prelude can break existing code in a subtle way"*. **Only the
trait/function layer ever needed versioning. The types-only language prelude never has.**

## 5. The C#-family answer is not a prelude at all

C# solves this with **grammar**: `predefined_type` is a nonterminal in the standard —
`'bool' | 'byte' | 'char' | 'decimal' | 'double' | 'float' | 'int' …` — and *"these keywords are
simply aliases for predefined `struct` types in the `System` namespace"*. Its implicit `global
using` directives are a **build feature**, not a language one, generated into `obj/` and varying by
SDK.

**B# has already drifted this way without deciding to.** `PRELUDE.md`'s own Drift section records
that ticket 10 says *"`bool` is a prelude alias not a builtin"* while `bs_check.erl` has
`builtin(bool) -> union(atom_lit(true), atom_lit(false))` — decided one way, built the other.

## 6. What renaming costs, measured

OCaml renamed `Pervasives` → `Stdlib` over **4.5 years**: introduced 4.07.0 (July 2018), deprecated
4.08.0 (June 2019), docs updated 4.09.0 (Sept 2019), removed 5.0.0 (Dec 2022).

## 7. The cross-cutting warning

Rust (prelude editions), Erlang (OTP 26 permitting a user type to shadow a built-in *"so that when
Erlang/OTP introduces a new type, code that happened to define its own type having the same name
will continue to work"*) and Haskell (PreludeCore's abolition) independently learned the same
lesson: **an implicit namespace that will grow must let user names win.** A closed, compiler-owned
set avoids this. One that accretes needs its shadowing rule decided up front.

## 8. Terms other languages use for the concept

| Language | Official term |
|---|---|
| Haskell, Rust, PureScript, Gleam | **prelude** |
| Elixir | `Kernel` — and `Kernel.SpecialForms` for the non-overridable half |
| Erlang | **auto-imported** BIFs; **predefined** / **built-in** types |
| Elm | **Default Imports** |
| Kotlin | **Default imports** |
| F# | namespaces **open by default** (`AutoOpen`) |
| OCaml | *"the default opened module"* (`Stdlib`) |
| Python | **builtins** |
| C# | **implicit `global using` directives** (build feature); types are **grammar keywords** |
| Agda | **Built-ins** / `BUILTIN` pragmas — `agda-prelude` is third-party |
| Miranda | **the standard environment** |

**Gaps, not filled from general knowledge:** Idris 2 (index page was a JS shell, so zero hits is not
evidence), Scala's `Predef` (no primary source retrieved), OCaml's `-nopervasives` (unverified),
Swift (no primary source found naming the concept at all).

## 9. Gaps closed — addendum, same day

**Idris 2 uses the word**, implicitly imported and suppressible: *"A library module `prelude` is
automatically imported by every Idris program"*, with `--no-prelude` in `Idris/CommandLine.idr`.
Contents are types **and** functions, so Idris joins Haskell as a full "implicit module, both kinds
of thing" prelude.

**Scala has the concept and not the word**, and states the convergent lesson more explicitly than
anyone. The spec's term is **root contexts**:

> *"The compiler supplies bindings from well-known packages and objects, called "root contexts"…
> These bindings are taken as lowest precedence, **so that they are always shadowed by user code**,
> which may contain competing imports and definitions."*

`java.lang`, `scala` and `scala.Predef` are implicitly imported in that order. Zero *"prelude"*
across three spec chapters.

**OCaml's manual splits types from functions, which is the split this project is contemplating.**
Chapter 28, *"The core library"*, has two sections: **1. Built-in types and predefined exceptions**,
and **2. Module `Stdlib`: the initially opened module** — *"automatically 'opened' when a
compilation starts… it is possible to use unqualified identifiers to refer to the functions provided
by the `Stdlib` module"*. Zero *"prelude"*. F# splits the same way across `FSharp.Core` (types) and
`FSharp.Core.Operators`. **In neither case is the split a suppressibility boundary**, so it is
weaker evidence than the Rust/Elixir/Haskell pattern — but it is a recurring instinct to keep
builtin *type* names on a different footing from the function library.

**Swift is a genuine auditable negative**: zero *"prelude"* and no statement that the standard
library is implicitly imported, across *The Basics*, *Declarations* (including the Import
Declaration grammar), *About Swift*, and the compiler repo's *Standard Library Programmer's Manual*.

**`-nopervasives` stays unverified** — not found in the manual's `ocamlc` options chapter. Treat it
as undocumented unless a source appears.

### The "user names win" lesson is five languages, not three

| Language | How it landed there |
|---|---|
| Haskell | abolished `PreludeCore` (1.3, 1996) after users were *"deeply unhappy"* |
| Rust | prelude editions, because adding traits breaks method resolution |
| Erlang | OTP 26 permitted shadowing built-in type names |
| Scala | root contexts are *"lowest precedence… always shadowed by user code"* — **by design** |
| Elm | keeps default imports small and *"very unlikely to overlap"* |

**Four of the five arrived at it after shipping. Scala designed it in.** If B#'s prelude will ever
accrete names, that rule wants deciding now rather than retrofitting — and if the set is closed and
compiler-owned, the problem does not arise at all.
