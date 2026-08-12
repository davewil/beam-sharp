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

Roc removed the `Task` type and replaced it with **purity inference**. The removal is recorded in
the basic-cli 0.18.0 migration guide — "`Task` is no longer needed, you can switch to using
`Result`, `=>` is used in the type of a function if it is effectful" and "`!` is now part of the
function name of effectful functions (= all platform functions), it is no longer syntax sugar for
`Task.await`" [14]. The rules that replaced it, verbatim from the language reference [3]:

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

Kept deliberately short, per the brief. The interesting finding is that **the brief's premise is
only half right**, and the correction matters for ticket 22.

**DbC is in Eiffel's grammar.** `require`, `ensure` and `invariant` are keywords, "official"
language constructs and not library features [15]. The inheritance rules are part of the language
too: a redefinition may weaken a precondition with `require else` and strengthen a postcondition
with `ensure then` [15]. That last part is the bit a library cannot replicate — the contract is
*inherited and composed* by the type system, not merely asserted at the top of a method body.

**The received story — "DbC survived as libraries and annotations elsewhere" — does not hold.**
The clearest death certificate available is for the *library* form, not the language form:

- .NET's Code Contracts: "Code contracts aren't supported in .NET 5+ (including .NET Core
  versions). **Consider using Nullable reference types instead.**" [16]
- `microsoft/CodeContracts` — last push 2018-10-06, repository **archived 2023-07-15** [17].
- What it needed to work: "classes for marking your code, a static analyzer for compile-time
  analysis, and a runtime analyzer", plus conditional compilation under a `CONTRACTS_FULL` symbol,
  plus a "contract rewriter" that edits compiled IL [16].

Meanwhile the *language-feature* forms survived. Ada expresses contracts as aspects — "Pre- and
postconditions are specified using an aspect clause in the subprogram declaration" — checked by
generated runtime assertions with no separate rewriting tool, though "by default […] assertions
aren't enabled" and require `-gnata` [18].

**So the pattern is not "language feature dies, library survives." It is close to the inverse, and
the discriminator is tooling weight:**

| Form | Needed to be useful | Outcome |
|---|---|---|
| Eiffel `require`/`ensure`/`invariant` | the compiler | in the language, still there [15] |
| Ada `Pre`/`Post` aspects | the compiler, plus a switch | in the language, still there [18] |
| .NET Code Contracts | a *binary rewriter*, a separate static checker, a `#define`, an IDE add-in | unsupported, archived [16][17] |

**The lesson for ticket 22, stated plainly:** a convention survives when the thing that already
compiles your code can check it, and dies when checking it requires a second tool in the build. And
the successor Microsoft points at is *nullable reference types* [16] — that is, the contract that
survived is the one that **became a type**. An attribute that the beam-sharp compiler itself reads
is on the surviving side of that line; an attribute that needs an external analyser is not.

## Part 4 — Contrast B: Rails and Phoenix

Also short. The question is what the *separation* bought, and the answer is checkable.

**Rails states the opinion explicitly and states its own limits.** "Convention over Configuration"
is doctrine — a `Person` class maps to a `people` table by convention, which "lower[s] the barriers
of entry for beginners" — and the framework is deliberately "omakase": "When most people are using
Rails in the same default ways, we have a shared experience." But the doctrine also refuses
rigidity: "Rails isn't like that. It isn't a single, perfect cut of cloth. It's a quilt." [22]
None of that is in Ruby's grammar.

**Phoenix is the cleaner experiment, because its conventions demonstrably churned while Elixir did
not.** Checkable evidence, all from the repository:

- **1.7 replaced route helpers with verified routes.** "Phoenix 1.7 includes a new
  `Phoenix.VerifiedRoutes` feature which provides `~p` for route generation with compile-time
  verification. […] **This feature replaces the `Helpers` module generated in your Phoenix
  router**, but helpers will continue to work and be generated. You can disable router helpers by
  passing the `helpers: false` option." [23] Note the shape: replace, keep the old one working,
  make it an option.
- **1.7 also revamped the generated application shape** — "The `phx.new` application generator has
  been improved to rely on function components for both Controller and LiveView rendering" [23].
- **1.8 added scopes to the generators** (commit "Add scopes to generators (#6102)", 2025-03-06)
  and the contexts guidance was restructured wholesale — the "Guides revamp (#6131)", 2025-03-21,
  moved `guides/contexts.md` into a new `guides/data_modelling/` directory that now holds
  `contexts.md`, `your_first_context.md`, `in_context_relationships.md`,
  `cross_context_boundaries.md`, `faq.md` and `more_examples.md` [24].
- **And the language underneath just went up by ordinary minor releases.** Phoenix 1.7 "requires
  Elixir v1.11+ & Erlang v22.1+" [23]; Phoenix 1.9-dev requires `~> 1.15` [25]. Elixir shipped no
  `defcontext`, no `defaggregate`. The conventions moved through *generator output, guide prose and
  a library module* — three artefacts a framework owns outright.

**What the separation bought:** the ability to change the architecture's name, shape, granularity
and generated scaffolding **without a language deprecation cycle**, and — the underrated half —
without breaking anyone who did not upgrade the generator. An app on the old convention still
compiles, because the old convention was never a grammar rule; it was code someone generated into
your repo, which is now just your code.

That is the precise thing beam-sharp forfeits by putting `aggregate` in the grammar. Not
"flexibility" in the abstract: the ability to have *two* conventions coexisting during a migration,
which is the only way a convention has ever actually changed in a large codebase.

## Part 5 — Synthesis: what does the escape hatch owe the core, and who enforces it?

The question the ticket exists for, one row per model.

| Model | What the escape hatch owes the core | Who enforces it | What happens when the debt is not paid |
|---|---|---|---|
| **Roc platforms** | Everything: there is no escape hatch reachable from the app. All I/O, all FFI, all memory comes from the platform [1]. The app owes the platform a *shape* (`requires`) and gets a *vocabulary* (`exposes`) [2]. | The **module system for the app half, the linker for the host half.** The app cannot name what the platform did not expose; the binary cannot contain a primitive the platform did not compile in [1]. | The unpaid debt sits entirely on the *platform author*, in the host, in Zig/Rust/C, outside Roc's type system [1][g1]. It is paid once per platform rather than once per call site. |
| **Unison abilities** | To be *named*, and to appear in the type of everything that transitively uses it [6]. The escape hatch is a value in the system, not a hole in it — even the planned FFI is "exposed through top-level abilities" [13]. | The **typechecker**, via the ability check against the ambient set [7], and the **`handle` expression**, which is the only way to discharge a requirement [5]. | You get an ability check failure at compile time [10]. The *soundness* debt is always paid. The **honesty** debt is not: a naked `->` can silently absorb a concrete ability, so a signature can read pure and elaborate to `{IO}` [11][12]. |
| **Eiffel DbC** | To satisfy `require` on entry and `ensure` on exit, and — the part only a language can do — to weaken preconditions and strengthen postconditions down an inheritance chain (`require else` / `ensure then`) [15]. | The **compiler and the runtime**, together, with contract violation raised as an exception [15]. | A violation exception at the point of breach, attributed to the guilty party (caller for a precondition, supplier for a postcondition). |
| **.NET Code Contracts** (the library form) | Nominally the same. | A **binary rewriter and a separate static checker**, outside the compiler [16]. | Nothing at all — you can simply not run the rewriter, or not define `CONTRACTS_FULL`. Which is, in the end, what everyone did [16][17]. |
| **Rails / Phoenix conventions** | Nothing enforceable. A context boundary is a suggestion; a module can call any other module's internals. | **Nobody.** Generators, guides and code review [22][24]. | Nothing. The convention drifts, and this is survivable precisely because nothing depended on it holding. |

Three things fall out of that table, and they are the ones ticket 22 needs.

**1. Every model that actually enforces anything enforces it with the tool that already builds the
code.** Roc: the compiler's module resolution plus the linker. Unison: the typechecker. Eiffel: the
compiler. The one entry that failed outright is the one that needed a second tool in the build
[16][17]. This is a strong argument for beam-sharp's attributes being read by the **beam-sharp
compiler**, and a strong argument against any design where the DDD rules live in a separate
analyser run by CI.

**2. There are exactly two enforcement strategies on offer, and they are not variants of each
other.**

- **Roc's is closure over what the code can reach.** You cannot violate the guarantee because the
  primitive is not in the binary. Enforcement happens *once*, at build time, and costs nothing at
  runtime.
- **Unison's is propagation of an obligation through types.** You cannot violate the guarantee
  because the requirement follows you up the call graph until something discharges it. Enforcement
  happens at *every* call site, statically.

Closure is stronger where it applies and applies in fewer places. Propagation is weaker per site
and reaches everywhere the type system reaches. Note that **neither validates a value**. Roc trusts
the host; Unison's handler receives whatever the runtime hands it. This is consistent with research
06's finding about Gleam and purerl — no language in this file defends its boundary by checking
data. They defend it by controlling *who may be on the other side of it*.

**3. The convention that can be changed is the one that was never enforced.** Phoenix could move
contexts three times because nothing in Elixir depended on them [24][25]. Roc apps are bound to one
named platform and the FAQ's answer on composing or swapping platforms is "No." [4]. There is no
model in this file that has both enforcement and revisability. That trade is real and beam-sharp
should choose it consciously rather than hope to escape it.

## Part 6 — Which model could work on the BEAM

Short answer: **neither Roc's nor Unison's mechanism transplants, and they fail for the same
reason in opposite directions.** Both control what a program may *reach*. Research 06's problem is
what may reach the *program*.

### 6.1 Roc's mechanism requires a closure property the BEAM is committed to not having

Roc's guarantee — "There are no escape hatches that a malicious program could use to get around
them" [1] — rests on link-time closure. The compiler "looks up the platform's host implementation
(which the platform will have provided as an already-compiled binary)" and "links them together
into one combined binary" [1]. The set of primitives in the artefact is fixed when the artefact is
built.

The BEAM's module system is the exact negation of that, per research 06 §C: a module's public
interface is its export table, dispatch is `Module:Function/Arity` on atoms, `apply/3` reaches
anything exported from runtime data, there is no visibility modifier, and there is **"no way to
publish a function to your own compiler but not to `erl`"**. Add hot code loading: a module can be
replaced in a running node. Nothing about a BEAM release is closed, and that openness is a headline
feature, not an oversight.

So a beam-sharp "platform" could constrain what beam-sharp *source* names — that much is just
module resolution and is worth having — but it could never make the claim Roc makes, because
`erlang:apply/3` from any other application in the release reaches the same code. **Roc's
enforcement mechanism does not survive the transplant; only its interface-design half does.**

The half that *does* survive is worth naming, because it is cheap: Roc's `requires` clause, where
the platform declares the shape the application must have and may hold an app type opaque via
`[Model : model]` [2]. That is a directly stealable idea for a beam-sharp OTP behaviour — a typed,
compiler-checked `requires` is strictly better than Erlang's `-callback` attributes, and it works
regardless of what the runtime allows.

### 6.2 Unison's mechanism reaches one of eight channels

A handler discharges an ability **at a call site, in a lexical scope** — the ambient set is "the
required abilities on the type of the nearest enclosing lambda, plus the abilities eliminated by
enclosing handlers" [7]. Everything in that sentence presupposes that the effect happens *because
your code called something*.

Research 06's channels 2–8 are not calls. Nothing invokes your handler when a monitor fires, when
a timer expires, or when someone else writes an ETS row you later read. Mapping the eight channels
against each enforcement mechanism:

| # | Violation channel (research 06) | Roc-style closure | Unison-style ability propagation | Compiler-emitted boundary check |
|---|---|---|---|---|
| 1 | Direct call from Erlang/`apply/3` | ✗ — no link-time closure on the BEAM | ✗ — the caller has no handler and no signature | ✓ — guard clause at function entry |
| 2 | Process mailbox | ✗ | ✗ — arrival is not a call | ✓ — validate in the generated `receive`/`handle_info` |
| 3 | `EXIT` / `DOWN` signals | ✗ | ✗ | ✓ — same, if the language owns the OTP callback |
| 4 | Timer delivery | ✗ | ✗ | ✓ — same |
| 5 | ETS read | ✗ | ~ — an `Ets` ability names *that you read*, never *what came back* | ✓ — validate at the generated read |
| 6 | Decoded external term | ✗ | ~ — same limitation | ✓ — validate at the generated decode |
| 7 | `code_change/3` from an old version | ✗ | ✗ | ✓ — validate the migrated state on entry |
| 8 | App env / `persistent_term` / process dictionary | ✗ | ~ — same limitation | ✓ — validate at the generated read |

`~` marks the honest half-credit: an ability system makes it *visible in the type* that a function
touches ETS or decodes a term, which is real value for review and for testing (research 06 channels
become greppable, and a pure test handler can stand in for the real one [13]). It does not make the
returned term trustworthy.

### 6.3 What that leaves

**The only mechanism that reaches all eight channels is a check emitted at the point where an
external term becomes a typed value.** That is a *codegen* obligation, not a type-system feature —
and it is available to beam-sharp for exactly the reason ticket 06 identified: beam-sharp compiles
the `receive`, the `handle_info`, the ETS wrapper, the `binary_to_term` wrapper and the
`code_change` entry, so it owns every point where a channel lands.

Consequences for [ticket 22](../issues/22-how-opinionated.md):

- **Roc's model is not on the table** as an enforcement mechanism. Its *design* contribution to
  beam-sharp is `requires` — a typed, compiler-checked contract in which the framework states the
  shape the application must have. That is an argument for the **attribute** side of ticket 22's
  split: `[Aggregate]`, `[Command]`, `[Port]` are the beam-sharp analogue of a platform declaring
  what an app must provide, and unlike a grammar keyword the framework can change its mind about
  them (Part 4).
- **Unison's model is partly on the table**, as the argument that an escape hatch should be
  *denominated in the same currency as the guarantee* [13] rather than being a hole punched through
  it. Concretely: a beam-sharp `[Port]` should be a declared, typed, compiler-visible thing that
  appears in the signatures of its callers — not a `@external`-style annotation the compiler simply
  believes (research 06). Its cost is documented and should be expected: an inferred effect
  discipline produces signatures that stop matching what the author wrote [11][12].
- **The three-outcome taxonomy from research 06 decides where the checks go**, and nothing in this
  file changes that. What this file adds is *why* it must be beam-sharp's own compiler emitting
  them: every precedent that put enforcement in a second tool lost it [16][17].
- **On grammar versus attributes** (ticket 22's actual question): Part 3 and Part 4 point the same
  way. Put in the grammar what the compiler must check and no framework will ever want to
  re-shape — Roc did this with the purity bit in the arrow [3], Eiffel with `require` [15]. Put in
  attributes the domain opinion that will churn on a shorter cycle than the language, because
  Phoenix changed contexts three times without an Elixir release [23][24][25], and a grammar keyword
  cannot be migrated behind a `helpers: false` option.

## Gaps and where I looked

Recorded rather than filled by inference.

- **[g1] Whether anything validates values crossing Roc's Roc-API↔host boundary.** `docs/langref/
  platforms.md`, `modules.md` and `functions.md` [1][2][3] describe the boundary as symbol names
  (`provides`) plus linking, and never mention checking. That is an argument from silence in a
  document that would plausibly have mentioned it, not a positive finding. Not checked: the Zig
  compiler's linking code in `roc-lang/roc/src`, or a platform template's host source. Would take
  30–60 minutes and is worth doing if beam-sharp seriously considers the platform model — but
  §6.1 concludes it cannot, so this was left open.
- **[g2] Whether any two Roc platforms are deliberately interface-compatible.** The FAQ rules out
  composition and multiple platforms [4]; nothing found describes a standard interface two
  platforms could both implement. Not checked: the `roc-lang/examples` repo, or whether
  `basic-cli` and `basic-webserver` share module signatures.
- **Roc's own website is partly stale and was not used as the primary source.**
  `roc-lang.org/functional` still describes the removed design — "Roc functions exclusively use
  _managed effects_ in which they return descriptions of effects to run, in the form of Tasks" —
  while `docs/langref/functions.md` in the repo describes purity inference with `->`/`=>` [3] and
  the basic-cli 0.18.0 migration guide records the removal: "`Task` is no longer needed, you can
  switch to using `Result`, `=>` is used in the type of a function if it is effectful" [14].
  `roc-lang.org/platforms` and `/platforms.html` served a builtins index / 404 on every attempt.
  **Anyone re-checking Roc facts should read `docs/langref/` in the repo, not the website.**
- **Unison at large scale is asserted by the project, not measured here.** [5] lists distributed
  computation among what abilities carry, and Unison Cloud is built on the `Remote` ability, but no
  post-mortem or large-codebase retrospective was located. The scale claims in §2.4 are derived
  from documented *mechanics* (handler nesting, ordering, inference) rather than from reported
  experience, and are marked as such in the prose.
- **Eiffel's commercial history was deliberately not researched** — the brief said "briefly", and
  the ticket's own attempt log identifies open-ended narrative questions as what killed two prior
  attempts. Part 3 answers the *mechanism* question with sources and declines the narrative one.
- **Rails is covered by one source** [22]. Phoenix carries the weight of Part 4 because its
  convention changes are checkable in a repository; Rails' are not, without narrative history.

## Claim → source

| # | Source | Mark |
|---|---|---|
| 1 | Roc language reference, *Platforms* — `roc-lang/roc`, `docs/langref/platforms.md` ([repo](https://github.com/roc-lang/roc/blob/main/docs/langref/platforms.md)) | **src** |
| 2 | Roc language reference, *Modules* — `roc-lang/roc`, `docs/langref/modules.md` (platform/application module headers, `requires`/`exposes`/`provides`/`targets`) | **src** |
| 3 | Roc language reference, *Functions* — `roc-lang/roc`, `docs/langref/functions.md` (pure vs effectful, `->` vs `=>`, purity inference, no effect polymorphism) | **src** |
| 4 | Roc FAQ — <https://www.roc-lang.org/faq> (one platform per app; no multiple or composed platforms; platform-agnostic packages) | **doc** |
| 5 | Unison language reference, *Abilities and ability handlers* — <https://www.unison-lang.org/docs/language-reference/abilities-and-ability-handlers/> (`I ->{A} O`, `handle e with h`, `Request`, Frank lineage) | **doc** |
| 6 | Unison docs, *Using abilities part 1* — <https://www.unison-lang.org/docs/fundamentals/abilities/using-abilities-pt1/> (ability requirements; inheritance of requirements; no secret effects) | **doc** |
| 7 | `unisonweb/unison`, `docs/ability-typechecking.markdown` ([repo](https://github.com/unisonweb/unison/blob/trunk/docs/ability-typechecking.markdown)) — ambient abilities, nearest enclosing lambda, existential inference, why Frank-style generalisation was rejected, partial-application unsoundness | **src** |
| 8 | Unison docs, *Writing ability handlers* — <https://www.unison-lang.org/docs/fundamentals/abilities/writing-abilities/> (`Request`, `resume` as continuation) | **doc** |
| 9 | Unison docs, *Using abilities part 2* — <https://www.unison-lang.org/docs/fundamentals/abilities/using-abilities-pt2/> (nested handlers peel one ability each; handler order changes the result; no unhandled abilities at top level) | **doc** |
| 10 | Unison docs, *The typechecking rule for abilities* — <https://www.unison-lang.org/docs/language-reference/the-typechecking-rule-for-abilities/> (ability check failure; top-level definitions must be pure) | **doc** |
| 11 | `unisonweb/unison` issue #1173, *Unison should protect against accidental inference of concrete ability types* — opened 2020-01-24, **still open** ([issue](https://github.com/unisonweb/unison/issues/1173)) | **src** |
| 12 | `unisonweb/unison` issue #691, *Unison accepts my incorrect type signature* — `hello : '()` inferred as `hello : '{base.io.IO} ()` ([issue](https://github.com/unisonweb/unison/issues/691)) | **src** |
| 13 | Unison docs, *General FAQs* — FFI "still in its infancy", foreign APIs exposed as top-level abilities, pure test handlers for a `GPU` ability — <https://www.unison-lang.org/docs/usage-topics/general-faqs/> | **doc** |
| 14 | `roc-lang/basic-cli` release 0.18.0 (2024-12-28) migration guide — `Task` removal, `!` naming, `=>` for effectful ([release](https://github.com/roc-lang/basic-cli/releases/tag/0.18.0)) | **src** |
| 15 | Eiffel documentation, *Design by Contract and Assertions* — <https://www.eiffel.org/doc/eiffel/Design_by_Contract_and_Assertions> (`require`, `ensure`, `invariant` as language constructs; `require else` / `ensure then`) | **doc** |
| 16 | Microsoft Learn, *Code Contracts (.NET Framework)* — "Code contracts aren't supported in .NET 5+ … Consider using Nullable reference types instead"; static analyzer, runtime analyzer, contract rewriter, `CONTRACTS_FULL` — <https://learn.microsoft.com/en-us/dotnet/framework/debug-trace-profile/code-contracts> | **doc** |
| 17 | `microsoft/CodeContracts` repository metadata — last push 2018-10-06, archived 2023-07-15 (via `gh repo view`) | **src** |
| 18 | AdaCore, *Introduction to Ada — Contracts* — `Pre`/`Post` as aspect clauses, runtime assertions, `-gnata` — <https://learn.adacore.com/courses/intro-to-ada/chapters/contracts.html> | **doc** |
| 19 | *(unused)* | — |
| 22 | *The Rails Doctrine* — Convention over Configuration, omakase, "It's a quilt" — <https://rubyonrails.org/doctrine> | **doc** |
| 23 | `phoenixframework/phoenix`, `CHANGELOG.md` on branch `v1.7` — verified routes replacing the router `Helpers` module; `phx.new` revamp; "Phoenix v1.7 requires Elixir v1.11+ & Erlang v22.1+" | **src** |
| 24 | `phoenixframework/phoenix` guide layout and commit history — `guides/data_modelling/{contexts,your_first_context,in_context_relationships,cross_context_boundaries,faq,more_examples}.md`; commits "Guides revamp (#6131)" 2025-03-21 and "Add scopes to generators (#6102)" 2025-03-06 (via `gh api .../commits?path=…`) | **src** |
| 25 | `phoenixframework/phoenix`, `mix.exs` on `main` — `@version "1.9.0-dev"`, `@elixir_requirement "~> 1.15"` | **src** |
| g1 | Gap — no source found on validation across Roc's host boundary; see [Gaps](#gaps-and-where-i-looked) | gap |
| g2 | Gap — no source found on Roc platform interface compatibility; see [Gaps](#gaps-and-where-i-looked) | gap |

Reference numbers 20 and 21 were allocated during drafting and not used; 19 is likewise unused.
Numbering is left intact rather than renumbered, so that quotations in the body keep their marks.
