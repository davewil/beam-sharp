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

## Part 3 — Contrast A: Eiffel's Design by Contract

## Part 4 — Contrast B: Rails and Phoenix

## Part 5 — Synthesis: what does the escape hatch owe the core, and who enforces it?

## Part 6 — Which model could work on the BEAM

## Gaps and where I looked

## Claim → source
