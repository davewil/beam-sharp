# 21 — Escape-hatch precedents: Roc platforms, Unison abilities, and two contrast cases

Research for [issue 21](../issues/21-escape-hatch-precedents.md). Feeds
[ticket 22](../issues/22-how-opinionated.md) directly and [ticket 18](../issues/18-boundary-defence.md)
substantially. Read against [research 06](06-interop-surface.md), which established that the BEAM
has **eight** violation channels, not one, and that neither Gleam nor purerl validates anything at
an FFI boundary.

**Elm is descoped from this ticket by instruction (2026-08-12) and is not researched here.**

## Method and provenance

| Mark | Meaning |
|---|---|
| **doc** | Official language documentation, specification, release notes, or the designers' own writing |
| **src** | Source code or repository artefacts (issues, PRs, commits, tests) of the implementation |
| **local** | Observed directly on this machine |

Nothing in this file is **local**: none of Roc, Unison, Eiffel or Rails is installed here. Every
claim is **doc** or **src**, and where a source could not be recovered the gap is stated rather
than filled by inference.

---

## Part 1 — Roc: platforms

Roc's own reference documentation lives in the compiler repository at `docs/langref/`; that is
the source used here (**src**), in preference to `roc-lang.org`, which is mid-rewrite and still
serves pages describing the *removed* `Task` design (see [Gaps](#gaps-and-where-i-looked)).

### 1.1 What a platform is, and what it provides

> "Something that sets Roc apart from other programming languages is its _platforms and
> applications_ architecture. Every Roc application is built on exactly one _platform_, and that
> platform (not Roc's standard library) provides all of the application's I/O primitives." [1]

The scope claim is the important one and it is stronger than "a framework":

> "In most languages, I/O primitives come with the standard library. In Roc, the standard library
> contains only functions and data structures; an application gets all of its I/O primitives from
> its platform." [1]

A platform is also responsible for **memory management** — the host supplies `malloc`/`free`
implementations the compiled Roc application calls [1] — and for **scheduling** concurrent I/O,
though the docs flag scheduling as not yet practical to implement ("there are currently some
missing pieces to make it practical for platform authors to implement") [1].

A platform has two halves, and only one of them is Roc:

> "**The Roc API** is the part that application authors see. For example, `Stdout.line!` is part
> of the Roc API of roc-platform-template-zig. […] **The host** is the under-the-hood
> implementation written in a language other than Roc." [1]

### 1.2 Where the boundary sits — and there are two boundaries, not one

This is the part that matters for beam-sharp, and it is easy to miss when the model is described
as "ports and adapters". There are **two** boundaries stacked on top of each other:

**Boundary A — app ↔ Roc API.** Declared in the platform module header, and fully typed [2]:

```roc
platform "my-platform"
    requires { main : Str -> Str }
    exposes [Http, File]
    packages { json: "../json/main.roc" }
    provides { "roc__entrypoint": main }
    targets : { ... }
```

- `requires` "declares what the application must provide to the platform" [2] — the platform
  states the *shape of the app*. It can demand a whole record of functions, and can hold an app
  type parameter opaque: `requires { [Model : model] for main : { init : model, update : model,
  Event -> model, render : model -> Str } }`, where "`[Model : model]` syntax maps an uppercase
  type alias (`Model`) to a lowercase rigid type variable (`model`). This allows the app to
  provide a `Model` type which remains opaque to the platform." [2]
- `exposes` "lists the types the platform provides to the application" [2].
- The app header mirrors it: `app [main!] { pf: platform "https://…" }`, where the exposed list is
  "Implementations the app provides to satisfy the platform's requirements" [2].

Boundary A is checked by the Roc compiler on both sides. It is a genuine two-way typed contract:
the platform constrains the app's shape (an inversion of control the app cannot escape), and the
app sees only what `exposes` names.

**Boundary B — Roc API ↔ host.** This is a *linker* boundary, not a type boundary:

> "The `provides` section maps each symbol name Roc will link with the platform host to the
> function that will be exposed under that symbol" [2]

and at build time:

> "1. The Roc compiler builds the Roc application into a binary object file. 2. Since that
> application specified its platform, the compiler then looks up the platform's host
> implementation (which the platform will have provided as an already-compiled binary). 3. […] it
> links them together into one combined binary in which the host portion calls the application
> portion as many times as it likes." [1]

> "a useful mental model […] is: the Roc application compiles down to a C library which the
> platform can choose to call (or not)." [1]

**Nothing in the Roc reference documentation describes any validation of values crossing
boundary B.** The host is a pre-compiled binary in Zig, Rust, C, Go or .NET [1]; the agreement is
symbol names and an ABI. This is an absence-of-evidence claim, marked as such [g1], not a
positive finding that Roc is unsound — but it is the structurally significant point: **Roc has not
removed the unverified edge. It has moved it out of the application author's reach and made it the
platform author's problem.**

### 1.3 What the type system says about effects

Roc removed the `Task` type and replaced it with **purity inference** [3]. The rules, verbatim:

> "Roc makes a first-class distinction between _pure functions_ and _effectful functions_
> (functions that are not pure) […] A function is effectful if it calls another effectful
> function, and otherwise it's pure. **Effectful functions can only be called by other effectful
> functions; pure functions and top-level constants can only call pure functions.**" [3]

> "`pure_fn : Str, Str -> Str` […] `run_fx! : Str, Str => Str` […] `pure_fn` uses a `->` to
> indicate that it's a pure function, whereas `run_fx!` uses a `=>` instead" [3]

> "By design, Roc has no syntax for 'either pure or effectful.' That is, there's no concept of
> _effect polymorphism_ like you might find in some languages that support algebraic effects." [3]

Effects are therefore tracked as **one bit in the arrow**, inferred, not as a set of named effects.
Naming is a lint on top: "Roc's compiler reports a warning if an effectful function's name does not
end in `!`" [3]. Purity may be annotated, and a wrong annotation is intended to be a *warning* so
you can add debug I/O to a pure function without a refactor — though "this is not fully implemented
yet. Currently, the compiler reports an incorrect purity annotation as a type mismatch error rather
than a warning" [3].

And the sentence that closes the loop between the effect system and the platform boundary:

> "One reason for this rule is that all effectful functions originate in the platform, which
> provides their implementations using low-level code that has been compiled for a specific target
> system." [3]

That is what makes the purity bit *mean* something. It is not an honour system: there is no way to
manufacture an effectful function inside the app, because every effectful function's implementation
comes from outside the app's compilation unit.

### 1.4 Is an app portable between platforms?

Effectively no, and the design says so.

- "Every Roc application is built on exactly **one** platform" [1]. On whether an app can have
  multiple platforms or platforms can compose, the FAQ is blunt: **"The short answer to each of
  these questions is 'No.'"** [4]
- The app imports platform-qualified modules (`import pf.Stdout` [1]), so the app's source is
  written against a *specific platform's* Roc API. Swapping platforms means the new platform must
  expose the same module and function names with the same types, and must impose the same
  `requires` shape. Nothing in the docs describes an interface or signature standard that would
  make two platforms interchangeable [g2].
- What *is* portable is packages: "Applications can use platform-agnostic packages, as well as
  packages involving I/O, as long as their platform supports the I/O operations in question." [4]

So portability in Roc is at the *package* layer, not the *application* layer. The app is bound to
its platform by name.

### 1.5 Is this really ports-and-adapters?

Partly, and the differences are the interesting bit.

**Where it matches.** The app is written against an interface it does not implement; the
implementation is swapped at link time; the app cannot reach around the interface to the operating
system. The last point is stated as a security property, which is a stronger claim than most
architectures make:

> "These security guarantees can be relied on because platforms have _exclusive_ control over all
> I/O primitives, including how they are implemented. **There are no escape hatches that a
> malicious program could use to get around them.** For example, Roc programs that want to call
> functions in other languages must do so using primitives provided by the platform, which the
> platform can disallow (or sandbox with end-user prompts) in the same way." [1]

That is the whole thesis in one paragraph: the escape hatch is not merely *discouraged*, it is
*not reachable* — because the only route out of Roc is a primitive the platform chose to expose.

**Where it differs — and these matter.**

1. **The dependency arrow is inverted relative to hexagonal architecture.** In ports-and-adapters
   the *application core* defines the port and the adapter conforms. In Roc the *platform* defines
   both the API the app calls and, via `requires`, the shape the app must have [2]. The app is the
   plugin. That is closer to a framework's inversion of control than to a hexagon — the difference
   being that in Roc it is the language's module system enforcing it, not a convention.
2. **One platform, no composition** [4] — you cannot assemble an app from a database port plus an
   HTTP port from different vendors. A real hexagon has many ports with independent adapters.
3. **The "port" is not an abstract interface with multiple conforming implementations.** It is a
   concrete named API belonging to one platform. Substitutability, the point of a port, is not a
   property the language provides.
4. **The boundary is enforced by the build, not only by types.** The platform is a URL in the app
   header and its host is a pre-built binary [1][2]; you cannot link an app to I/O the platform did
   not compile in.

Verdict: it is **capability-based effect provisioning enforced by the module system and the
linker**, correctly described as removing escape hatches, and only loosely described as
ports-and-adapters. Calling it hexagonal oversells the substitutability and undersells the
inversion of control.

## Part 2 — Unison: abilities

### 2.1 The mechanism

Unison's abilities are algebraic effects, "based on the Frank language" [5]. The separation Roc
achieves with *one platform per app* and *one bit in the arrow*, Unison achieves with *named effect
sets in the arrow* and *lexically scoped handlers*.

> "The general form for function types is `I ->{A} O`, where `I` is the input type, `O` is the
> output type, and `A` is the set of ability requirements of the function." [5]

> "The abilities that a function performs are visible in curly braces `{ }` to the right side of
> the function arrow in a type signature." [6]

> "An ability requirement is expressed in curly braces within the type signature of a function. It
> specifies that an ability may be performed in a given function and therefore **the caller of the
> function needs to provide a handler for the ability or pass the ability requirement along to its
> callers**." [6]

The propagation rule is what makes an ability requirement a real obligation rather than a comment:

> "Functions inherit the ability requirements of the functions that they call." [6]

> "a function can't secretly throw an exception or emit a value without an ability requirement
> appearing in the function signature, so you can reason about a program's behavior at the type
> level." [6]

The typechecking rule, stated precisely in the compiler repo's own design note:

> "Unison's typechecker prevents calling a function whose required abilities aren't available in
> the current expression. We say that at each subexpression of the program, there's an _ambient_
> set of abilities available, and when calling a function `f : a ->{e1,e2} b`, the ambient
> abilities must be at least as big as `{e1, e2}` […] Verifying that these requested abilities are
> available is called an 'ability check'." [7]

> "The ambient abilities at a subterm is defined to be equal to the required abilities on the type
> of the _nearest enclosing lambda_ […] plus the abilities eliminated by enclosing handlers." [7]

### 2.2 What a handler boundary guarantees

> "`handle e with h` gives `e` access to abilities handled by the function `h`. Specifically, if
> `e` has type `{A} T` and `h` has type `Request A T -> R`, then `handle e with h` has type
> `R`." [5]

> "`Request` is a special builtin provided by Unison which will pass arguments of type
> `Request A T` to a handler for the ability `A`." [5]

Three guarantees follow, and they are the ones beam-sharp should care about:

1. **Discharge is total and visible in the type.** A handler *removes* an ability from the
   requirement set. The result type `R` carries no `A`. There is no way to have used `A` without
   either an enclosing handler or an `A` in your own signature — the ability check is over the
   whole call graph, by inheritance [6][7].
2. **The handler chooses the semantics, not just the implementation.** A handler pattern-matches on
   the ability's operations and receives a continuation: "`resume` is a function whose argument is
   always the return type of the request operation in question" [8]. It may resume once (ordinary
   effect), never (abort), or many times (nondeterminism). So a handler can implement `Store` with
   an in-memory map for tests and with a database in production — the doc's own worked example —
   and the *calling code is byte-identical*. This is the strongest form of the ports-and-adapters
   claim on offer anywhere in this file.
3. **The boundary is lexical and dynamic, not architectural.** `handle … with` is an expression.
   The "port" is a type; the "adapter" is a value passed to `handle`. Nothing forces the handler to
   live at the edge of the program — but nothing lets an effect escape one either, because an
   unhandled ability is a type error at the top: "Abilities cannot be left unhandled 'at the top
   level' of a file" [9], and "Top-level definitions outside of function bodies are required to be
   pure" [10].

### 2.3 The cost in inference

This is the honest weak point, and it is documented by Unison's own maintainers rather than
inferred here.

**The naked-arrow problem.** `a -> b` does *not* mean "pure" and does not mean "for all effects":

> "The type `a -> b` means `a ->{e} b` for some existential `e` to be inferred by Unison. It
> doesn't mean `forall e . a ->{e} b` or `a ->{} b`." [7]

The consequence, from the issue that has tracked it since 2020 and is **still open** [11]:

> "if either `someLibFn` or `toBaz` uses concrete abilities, a concrete ability type will be
> inferred for `foo` as well, even though it 'looks like' a pure function." [11]

The original report is starker — a user wrote `hello : '()`, Unison accepted it, and inferred
`hello : '{base.io.IO} ()` [12]. **A signature you wrote and believed said "pure" silently
absorbed `IO`.** The proposed fix — "making it a _type error_ to infer a concrete ability type
(other than monomorphic purity `{}`) on an unadorned arrow" [11] — remains unimplemented six years
later.

Note what this means precisely: the *ability check* is sound (you cannot call an effectful function
without the ambient ability), but the *notation* is not honest by default. The guarantee is in the
elaborated type, not in the type you wrote. That is a different failure from Gleam's `@external`
(where the annotation is simply trusted, per research 06) but it lands in the same place for a
reader: the text on screen does not say what the compiler concluded.

**Why not the obvious fix.** The maintainer's note explains why Frank-style generalisation after
typechecking was rejected: "I realized it's not sound to do Frank-style effect generalization after
typechecking […] what if that function `a ->{e} b` were actually being passed (within the body of
`map`) to some other function that was expecting an `a ->{} b`? We can't just generalize this willy
nilly, we actually need to typecheck with the enriched type." [7] So the ergonomics cost is not
laziness; it is the price of soundness in an inferred effect system.

**Partial-application subtlety.** Ability access does not flow to inner lambdas:

> "`foo2 : Text ->{IO} Text ->{} ()` … also triggers an ability check failure. The inner lambda
> still requires only `{}` and we don't get access to abilities required by outer lambdas. This
> would be unsound (you could partially apply the function, then obtain a function with a smaller
> abilities requirement than what it actually used)." [7]

Correct, and a genuine cognitive load: *where* your effects are permitted depends on arity and on
where you put the lambda.

### 2.4 Do abilities scale?

Mixed, and the evidence cuts both ways.

**For.** Abilities are the mechanism for Unison's most ambitious feature, not a toy — the same
apparatus carries `IO`, exceptions, parsing, streams and *distributed computation*: abilities
enable "the same ordinary Unison syntax for programs that do (asynchronous) I/O, stream processing,
exception handling, parsing, distributed computation, and lots more" [5]. That is a real load-test.

**Against.** Composition is manual and order-sensitive:

> "When a function performs multiple effects it's common to nest handlers inside one another, with
> each handler peeling off one ability requirement." [9]

> "One caveat: the order in which the handlers are applied can change the value returned! Handlers
> respect the rules of regular function application." [9]

Ordering-dependent semantics is the classic monad-transformer problem in new clothes — it does not
compound linearly with the number of abilities, and it is not something a compiler can check for
you because both orderings are well-typed and both are sometimes what you want.

Combined with §2.3, the shape of the cost is: **abilities stay elegant in the small and stay
*correct* in the large, but stop being self-documenting in the large** — signatures accumulate
ability variables, naked arrows quietly absorb concrete effects, and handler nesting order becomes
load-bearing semantics that lives in one place in the program and is invisible everywhere else.

### 2.5 The escape hatch is itself an ability

The detail that makes Unison relevant to ticket 22. Unison's FFI, per the project's own FAQ:

> Unison "is currently adding a FFI (Foreign Function Interface) for invoking code written in other
> languages. It's still in its infancy." The sketch: foreign APIs are exposed through **top-level
> abilities** (e.g. a `GPU` ability), with the runtime permitting programs of type `'{GPU} ()` the
> same way it permits `'{IO} ()`. [13]

And the payoff they name for doing it that way:

> "You can define a test handler, in pure Unison, to handle your `GPU` ability, and use it to add
> regular Unison tests for your GPU code, that can run anywhere regardless of whether the right GPU
> is installed." [13]

**The escape hatch is denominated in the same currency as the guarantee.** Foreign code does not
get a special unchecked syntax; it gets an ability, so it appears in every caller's signature by
the ordinary inheritance rule and can be handled — including by a pure fake. Contrast Gleam's
`@external`, which is a hole in the type system rather than a value in it (research 06).

## Part 3 — Contrast A: Eiffel's Design by Contract

## Part 4 — Contrast B: Rails and Phoenix

## Part 5 — Synthesis: what does the escape hatch owe the core, and who enforces it?

## Part 6 — Which model could work on the BEAM

## Gaps and where I looked

## Claim → source
