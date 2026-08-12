# Map: beam-sharp — a C#-syntax BEAM language with multi-clause function heads

`wayfinder:map` · charted 2026-08-11

## Destination

A **language design specification** for a BEAM-targeting language with C#-family brace
syntax, whose defining feature is Erlang-style multi-clause function heads with pattern
destructuring, statically checked by a set-theoretic type system that proves clause
exhaustiveness.

The spec covers surface syntax, the type system, multi-clause semantics, the OTP /
concurrency and Erlang interop model, and the compilation target — complete enough that a
compiler build could start. It ends with a **walking-skeleton compiler** over a slice
carved from that spec; which slice, and in what implementation language, is fog until the
spec exists.

## Notes

- **Domain**: programming-language design; BEAM/OTP; C# language features; type theory
  (semantic subtyping / set-theoretic types).
- **Tracker deviation**: map at `wayfinder/map.md`, tickets at
  `wayfinder/issues/NN-<slug>.md`, research findings at `wayfinder/research/NN-<slug>.md`,
  prototypes at `wayfinder/prototypes/`. **Not** the local tracker's default `.scratch/`.
- **Canonicality is split with Linear** (2026-08-12). **Linear owns state** — status, native
  blocking relations, assignment, and the frontier query, because it renders the frontier
  *visually* where a `Blocked by:` line cannot. **This repo owns content** — ticket bodies,
  research files, prototypes. Map is [ENG-165](https://linear.app/davewil/issue/ENG-165);
  **ticket NN is ENG-(166+NN)**. Resolving a ticket means updating *both*: the answer here, the
  state there.
- **Execution override**: wayfinder is plan-only by default. This map sanctions execution
  for the **walking skeleton only**. Every other ticket produces a decision.
- **Skills each session should consult**: `/grilling` and `/domain-modeling` for decision
  tickets, `/research` for research tickets, `/prototype` for prototype tickets,
  `/diagram-artifact` before writing any mermaid.
- **Research findings land on `master`** as files under `wayfinder/research/`, linked from
  their ticket — not on throwaway branches, which parallel agents would collide over.
- The effort is understood to be large. The map exists so it need not fit in one session.
- **AUDIENCE — C# *or* TypeScript developers** (David, 2026-08-12). The target reader is fluent in
  one of the two, not necessarily both. This widens tier 1 of the heuristic below: a construct
  familiar to *either* audience qualifies as borrowed rather than invented.

  Consequences already visible, which later tickets must respect:
  - **TypeScript supplies what C# lacks for arrows.** TS overload signatures — several signatures,
    one implementation — are ticket 04's per-arrow interface with a different spelling. Union
    parameters (`Describe(int | Order)`) are TS-native too. Neither needs justifying from theory.
  - **`as` collides.** C#'s `as` is a **checked conversion**, null on failure — which is what makes
    the ticket 08 guard answer work, since lifted comparison then yields false. TypeScript's `as`
    is an **unchecked type assertion**: compile-time only, no runtime check, deliberately unsound.
    beam-sharp takes the C# meaning. **State this in the spec** — a TS reader will expect a no-op.
  - **`with` is C#-only**; a TS reader reaches for spread (`{...o, balance: x}`). Decide whether
    both spellings exist or one wins. → [ticket 26](issues/26-data-modelling.md).
  - **`->` for clauses holds up better under the wider audience**, since TS uses `=>` for arrow
    functions *and* for function types.

- **DESIGN HEURISTIC — borrow before inventing, in this order** (2026-08-12). Every good answer
  in ticket 01 came from an existing construct doing double duty, not from a new one.
  1. **Reach for C# first.** Before specifying a rule, check whether an existing C# construct's
     semantics already produce it. Not merely its *syntax* — its **semantics**. Worked examples:
     `as` gives fail-to-false in guards for free, because C#'s lifted comparison operators already
     return false when an operand is null (→ ticket 08); `[module: GenServer]` is C#'s own
     attribute-target syntax and needed no invention (→ prototype 01e); property patterns,
     positional patterns, `when`, `with`, pattern designations acting as as-patterns, and
     collection expressions with spread were all already there (→ ticket 01).
  2. **Reach for the BEAM second**, when no C# construct fits. `->` as the clause arrow is
     Erlang's; `:atom` is Elixir's. Both were chosen over inventing a spelling, and both are
     instantly legible to the ecosystem being joined.
  3. **Invent last, and say so.** Where neither applies, record it in the spec as a deliberate
     divergence with its reason — e.g. `as T` yielding `T | :nothing` for any `T`, where C#
     requires a reference or nullable value type (CS0077).

  The test for whether this is working: a construct a C# developer reads on sight, versus one they
  must be taught. Rules that have to be learned are the tax this heuristic exists to avoid — and
  it compounds under the standing constraint below, since anything a human must be taught is also
  something an agent must be prompted about.

- **STANDING CONSTRAINT — beam-sharp is written by agents and read by humans** (David,
  2026-08-12). Humans will generally not author these files; agents will, with tooling
  (mix/dotnet-style generators) scaffolding them. Humans review. The file-per-function separation
  exists for convention and separating concerns, not for typing ergonomics. Consequences that
  bind every ticket:
  - **Write-cost objections carry little weight.** Ceremony, boilerplate and file proliferation
    are near-free. Do not reject a design for verbosity alone.
  - **Read and review cost carry full weight.** Ambiguities that hurt a reader — `(0)`, `()`,
    colliding short names — remain real defects.
  - **Diagnostics are consumed by an agent in a loop**, so they should be machine-readable by
    design. Ticket 04's finding that the exhaustiveness residual *is* the missing case turns the
    compiler into something that hands an agent the clause it must write.
  - **Enforced conventions are guardrails on the agent**, which shifts ticket 22 toward more
    opinionation than a human-authorship analysis would justify.
  - **One function per file makes `write_scope` a file** — bounded blast radius, no merge
    conflicts between agents working different operations, and reviewable single-file diffs.
- **Evidence provenance**: research files mark claims `doc` / `src` / `local`, where `local`
  means directly observed here (OTP 28, Elixir 1.19.5, **Gleam 1.18.1**). **The Gleam gap is
  closed** (2026-08-12, ticket 10): Gleam is installed via `mise use -g gleam@1.18.1`, and its
  stance on foreign callers is now *observed* rather than inferred from the absence of guard
  emission — see [`prototypes/10c_gleam_forge.erl`](prototypes/10c_gleam_forge.erl). Prefer
  measuring Gleam to citing it. Remaining gap: Elixir 1.20 was not exercised. **Provenance
  warning for Roc**: `roc-lang.org` is stale — `/functional` still describes the *removed* `Task`
  design. Use `docs/langref/` in the `roc-lang/roc` repo.

## Decisions so far

<!-- one line per closed ticket: enough to judge relevance, then open the ticket for detail -->

- [Charting: differentiator, typing stance, scope](issues/00-charting-decisions.md) — the
  language exists for the multi-clause heads Gleam explicitly refuses; typing is
  static-by-default set-theoretic with enforced cross-clause exhaustiveness; tooling,
  stdlib breadth, macros and alternative backends are out of scope.
- [Prior art: static types plus multi-clause heads](issues/03-prior-art-static-multiclause.md)
  — **Gleam never rejected multi-clause heads; it never considered them.** No rationale
  exists, and the soundness hypothesis is affirmatively weakened (Gleam's shipped checker
  already runs Jules Jacobs' algorithm over nested multi-column patterns). Projects stall on
  **commercial dependency**, not type theory — purerl survives because a company ships on it;
  Hamler, Caramel and Alpaca each had zero internal consumers. The core bet is proven
  feasible: Alpaca shipped multi-clause heads on an HM BEAM language. **NVLang is a citation
  hazard** — see the ticket before citing it anywhere. *(One claim in this ticket was later
  retracted by ticket 19 — see there.)*
- [Audit of `purescript-backend-erl`](issues/19-purescript-backend-erl-audit.md) — **retracts a
  ticket 03 claim**: it emits **exactly one clause per function, always, with no guard**, not
  native clause heads. The cause is upstream and unreachable from any backend — `purs` merges
  equations into one CoreFn `ExprCase` and the optimiser's IR has no pattern node at all.
  **Net for ticket 13: no BEAM backend fed by a curried functional frontend emits clause heads.**
  The only two that keep heads are LFE and Elixir, whose surface syntax has them natively —
  which is beam-sharp's position, making this a counter-example rather than a template.
- [A page of idiomatic beam-sharp](issues/01-sample-code.md) — **Variant A settled**: equations
  under a signature. The design is smaller than expected — **C# already supplies every pattern
  form needed**, so the language is one structural move: C#'s pattern grammar out of `switch`
  arms and into the parameter position, N declarations where C# allows one. The showcase was
  lowered to Erlang and **run on OTP 28**: five clauses in, five native clause heads out.
  **It also amended ticket 00** — multi-clause heads are notationally, not semantically,
  distinct from Gleam's multi-subject `case`; the differentiator is now a stated design
  preference. Do not re-derive this.
- [Escape-hatch precedents](issues/21-escape-hatch-precedents.md) — **neither Roc's nor Unison's
  mechanism transplants, and they fail for the same reason in opposite directions: both control
  what a program may *reach*, where ticket 06's problem is what may reach the *program*.** Roc's
  guarantee rests on **link-time closure**, which the BEAM is committed to not having — `apply/3`,
  no visibility modifiers, hot code loading, and "no way to publish a function to your own compiler
  but not to `erl`". Unison's abilities discharge at a *call site*, so they reach **1 of the 8
  violation channels** — nothing invokes your handler when a monitor fires. **No language in the
  file defends its boundary by checking data; they defend it by controlling who may be on the other
  side.** So the only mechanism reaching all eight is a **check emitted where an external term
  becomes a typed value** — a codegen obligation, and available precisely because beam-sharp
  compiles the `receive`, the `handle_info`, the ETS wrapper and `code_change`. Three further
  findings: every model that enforces anything does so **with the tool that already builds the
  code** (the one needing a second tool, .NET Code Contracts, was simply not run); **no model has
  both enforcement and revisability** — Phoenix could move contexts three times because nothing
  depended on them, and Roc's FAQ answers "No" to swapping platforms; and Roc's **`requires`**
  clause is directly stealable as a typed, compiler-checked OTP behaviour contract, strictly better
  than Erlang's `-callback`. **A premise in my own brief was inverted by the research**: DbC did not
  survive as libraries — Eiffel's `require`/`ensure` are *still grammar*, Ada's `Pre`/`Post` are
  *still aspects*, and it is the **library** form that died (.NET Code Contracts, archived
  2023-07-15). The discriminator is **tooling weight**, and **Microsoft's named successor is
  nullable reference types — the contract that survived is the one that became a type.**
- [Head and guard syntax](issues/08-head-and-guard-syntax.md) — **the surface is settled.**
  Guards use the **expansion rule** (verified on Elixir 1.19.5: *"Only macros can be invoked
  inside a guard"*), with a **`guard` modifier** for named guards — `defguard` with a different
  spelling. Same-arity dispatch is a **union parameter**, not overload signatures, which means
  **one arrow per arity** and simplifies ticket 04's per-arrow check to a single pass. Defaults
  and variadics both kept, with arity generation as codegen — but **defaults cannot express the
  accumulator pair**, since they cannot change a parameter's type. `dynamic` narrowing is
  **always written**, never inferred: neither audience expects implicit cast insertion.
  Declarations file is `index.bs`. List patterns are prefix-plus-rest only.
- [Compilation targets](issues/02-compilation-targets.md) — **three tiers, not a binary.** The
  **Abstract Format expresses multi-clause heads natively** (a function *is* a clause list);
  Core Erlang does not at the head but hands you the primitive one level down, costing a
  mechanical ~50-line wrapper; BEAM bytecode needs a full match compiler. The cliff is between
  Core and bytecode, not between Abstract Format and Core. **Dialyzer is the sharpest
  discriminator and it fails silently**: compiling from `.core` emits an empty abstract chunk
  with no warning, and a `-spec` is lost through that path — which collides directly with
  ticket 06's recommendation to emit specs.
- [Cross-clause exhaustiveness](issues/04-crossclause-exhaustiveness.md) — **the mechanism is
  not a research risk; it has been solved and shipped since 2003.** But exhaustiveness is only
  well-posed against a **declared** input type: redundancy is relative, exhaustiveness is
  absolute. CDuce checks it because functions carry a mandatory interface; Elixir cannot,
  because it *builds* the function type from the clauses, making the check vacuous.
  **Therefore multi-clause functions in this language must carry signatures — inference alone
  doesn't weaken the guarantee, it makes the question disappear.** That is a binding constraint
  on tickets 08 and 11. Also: Elixir v1.20 ships **redundancy only, not exhaustiveness**.
- [Erlang/Elixir interop surface](issues/06-interop-surface.md) — the surface is **smaller than
  expected** (`-behaviour` has no runtime effect; Elixir needs no special machinery), but the
  violation surface is **eight channels**, not one. The load-bearing finding: **an untyped
  caller does not always crash** — there are three outcomes, and the third is *silent
  unsoundness* (`add(1.5, 2.5)` returning `4.0` from an `Int, Int -> Int` function). Only that
  third case argues for emitted guards. Neither Gleam nor purerl defends against any of it.
  Gleam's answer to typed OTP was to not implement the behaviour contract at all — a route
  closed to this language, since ticket 00 makes `handle_call/3` the showcase.
- [C# 15 `union` and TypeScript discriminated unions](issues/07-csharp15-and-ts-unions.md)
  — C# unions are **preview, not shipped**, and the design is still moving (champion issue is
  #9662, not #8928; no primary source for "GA Nov 2026"). They are nominal, closed struct
  wrappers; exhaustiveness only suppresses a *warning*. **The rejected designs matter more**:
  C# killed both structural/erased union designs on CLR artefacts — reified generics and
  nominal identity — **and neither rock exists on the BEAM**. TypeScript is structural but
  stops short of set-theoretic (syntactic intersections, no negation, opt-in exhaustiveness).
- [Union representation](issues/09-union-representation.md) — **structural and open; there is no
  nominal type in the language and no union declaration form.** Naming is **aliasing**: `type X =
  ...` is the single naming construct for records, tuples, scalars and unions alike, the name
  never enters the algebra, and two names over the same set are the same type. `union` was
  rejected on the borrow heuristic's own terms — C#'s spelling carries closed nominal semantics
  this language does not deliver, while C#'s `using` alias and TS's `type` both match the
  semantics exactly. Recursion is **equirecursive and must be contractive**, so subtyping is
  decided coinductively. Indiscriminable unions are an **error at the declaration**, normalised
  first, with **BEAM guards as the vocabulary** for what "discriminable" means. **The cost is
  newtypes** — `Meters` and `Feet` over `float` are one type; the remedy is the BEAM's free tuple
  tag, with refinement types the alternative (→ ticket 20). **This answers ticket 07 §5.0**:
  compile-time-only nominality *is* available on the BEAM and buys nothing, because erased
  nominality is exactly an alias — the wrapper premise was a CLR artefact, but removing that cost
  never addressed the capability gap (negation, union closure, boundary enforceability). Sharpest
  downstream consequence: **[ticket 16](issues/16-ad-hoc-polymorphism.md) loses its resolution
  key** — **dispatch cannot key on a name that is not in the term**, so type classes as
  PureScript/Haskell/Rust know them are not merely costly here, they are unresolvable. *Elixir's
  structs and protocols are not a counter-example but the worked remedy* — `__struct__` is an atom
  **in the data**, so the name is a tag, and beam-sharp can resolve it statically where Elixir
  needs a consolidation pass (verified: `prototypes/16a_elixir_protocol_dispatch.exs`).
- [C# functional feature inventory](issues/05-csharp-functional-inventory.md) — LINQ query
  comprehension is portable (ECMA-334 makes it a pure syntactic rewrite, bound before type
  binding, with no `IEnumerable<T>` dependency); extension-method chaining *is* already a
  pipeline rewrite; `with` becomes more central than in C#. Dropped: `init`/`readonly`,
  nullable reference types, iterators and `async`/`await`. Two debts left open — no ad-hoc
  polymorphism story, and slice patterns over cons cells.
- [Atoms in a C# skin](issues/10-atoms-in-a-csharp-skin.md) — **the atom universe is open**:
  `:ok` is a singleton type, `atom` the cofinite top, and nothing declares an atom. Declare-
  before-use was not a live option — it contradicts ticket 09's "no syntax that declares a type"
  — and **Gleam supplies the empirical case against it**, having taken that fork and needed a
  carve-out for `ok`/`error`/booleans in the shipped language. **`true`/`false` are the only
  keyword atoms** (semantics coincide with C#'s `bool`; `null` fails the same test `union`
  failed), `bool` is a prelude alias not a builtin, and there is **no truthiness** — so ticket
  09's Json example is corrected to `:null`. Module identifiers in value position are checked
  atom singletons. **The prelude cannot mint**, because minting from a literal is already
  spelled `:foo`. Three findings the ticket did not anticipate: the sigil's last objection is
  visual not lexical and is **withdrawn**; **atoms appearing only in type positions are not
  interned**, a codegen obligation Erlang does not have (→ 13); and **`erlc` constant-folds
  `binary_to_atom` on literals**, so the table can only be exhausted by a runtime-built string,
  which makes provenance — not minting — the real rule (→ 20). **Gleam is now installed and
  ticket 06's silent unsoundness is demonstrated**: a Gleam function spec'd `-> float()`
  returned a binary when called from raw Erlang.

- [Type system shape and the `dynamic` boundary](issues/11-type-system-shape.md) — **there is no
  `dynamic` in this language.** The ticket's own framing treated it as a *place*; both shipping
  implementations treat it as something else, and beam-sharp takes neither — Elixir makes it a
  **field on every type** (`%{dynamic: :term}`) needing a **second, weaker relation**
  (`subtype?(integer, dynamic) = false` but `compatible?(dynamic, integer) = true`), Gleam makes
  it an **opaque library type** entered by a free `identity` cast and exited by a hand-written
  decoder. beam-sharp has neither: external values arrive as `term`, **the clause head is the
  decoder**, and the exhaustiveness residual *is* the boundary case you failed to handle. So
  **one relation, not two** — plain set-theoretic containment, coinductive per ticket 09.
  Patterns over a `term` are **O(1) guard-decidable only** (ticket 09's discriminability rule
  extended verbatim — BEAM guards are the vocabulary); deep validation is an explicit call to a
  generated **`ValidateAs<T>`**, because emitting the traversal inside a clause head would make a
  dispatch construct do unbounded work **whose size a foreign sender chooses**. `ValidateAs<T>`
  **rejects arrow types at compile time**: `erlang:fun_info` yields identity, never types, and
  the top arrow is `none() -> term()` — uncallable, since arrow subtyping is contravariant, so
  "narrow it to `fn(term)->term`" is unsound. Foreign funs are holdable and returnable, never
  callable; the boundary is **MFA**, which is guard-decidable data. Higher-order contract
  wrapping is the literature's correct answer and was rejected on the same hidden-cost grounds,
  **chosen partly for reversibility** — wrapping is purely additive later. The top type is
  spelled **`term`**, a deliberate **override of the borrow heuristic** (TS's `unknown` is tier
  1): the top here is a *set* you take complements of, not an epistemic state, and it matches the
  emitted `-spec`. The guarantee: **"Every case your types admit has a clause — and everything
  from outside is a `term` until you match it."** Deliberately **stable under ticket 18**; the
  rejected candidate pinned it to *who called you*, which ticket 09 §5 says the BEAM cannot
  enforce. **Two cautions**: `ParseAtom<T>` and `ValidateAs<T>` are type-directed **codegen, not
  generics** (→ ticket 27), and my own claim that OTP prefers MFA because funs go stale is true of
  **closures only** — `fun M:F/1` is late-bound and survived a purge that killed a closure.

## Not yet specified

<!-- in-scope fog: real, but not yet sharp enough to phrase as a ticket -->

- **The walking skeleton**: which slice of the spec it implements, and what language the
  compiler itself is written in. Cannot be phrased sharply until the language surface exists.
  One requirement is already known: it should **measure checker cost at the clause counts the
  showcase implies**. Ticket 04 found Etylizer's pathological inputs are `case` expressions
  with 40+ branches — precisely the large multi-clause `handle_info` this language advertises.
- **Module and namespace system**, and function identity — BEAM identifies functions by
  name *and arity*, which multi-clause heads and optional parameters both disturb. **Ticket 10
  §3 adds one requirement**: a module identifier in value position is an atom singleton, so this
  fog owes an answer to *what atom is actually emitted* — a bare snake_cased name, which risks
  colliding with Erlang modules, or something prefixed as Elixir's `Elixir.` is. Ticket 10
  deliberately did not decide it.
- **The language's name.**
- **Imports and cross-module scope** — if a directory is a module, what do files in it share
  automatically, and what must be imported? Slipped into a prototype example unexamined.
- **Where DDD invariants live** — not commands, not types. An `Invariants` module, refinement in
  the type declarations, or nothing.
- **Stdlib shape as a principle** — Erlang-ish flat modules, C#-ish namespaced statics, or
  Gleam-ish. Breadth is out of scope; the shape is not. **The prelude now has known contents**
  from ticket 10 — `type bool = true | false;`, `type option<T> = T | :nothing;`,
  `ParseAtom<T>` and `ToExistingAtom` — which makes "what is in the prelude versus a module you
  import" a live sub-question rather than a hypothetical one. **Ticket 11 adds `ValidateAs<T>`**,
  and with it a sharper version of the question: `ParseAtom<T>` and `ValidateAs<T>` are
  compiler-generated rather than written, so the prelude is not only a set of definitions but a
  set of **codegen obligations** — and where those are documented, and whether a user can extend
  them, is unanswered.
- **Consuming Gleam and Elixir libraries** — possible, and at what ergonomic cost. **Sharper
  after ticket 10 §7**, which measured Gleam's representation rather than reading it: fieldless
  variants are bare atoms, variants with fields are tagged tuples, PascalCase becomes
  snake_case, `Nil` is the atom `nil` and `Result` is `{ok, _} | {error, _}`. So a Gleam type is
  already a structural shape beam-sharp can write directly — the ergonomic cost looks low, and
  the open part is what happens to Gleam's *nominal* intent when beam-sharp has no nominality to
  receive it.

<!--
  GRADUATED 2026-08-12 (ticket 10): "Runtime behaviour against untyped callers — what, if
  anything, the compiler emits to defend a typed function called from raw Erlang." This is
  ticket 18's question verbatim, and ticket 10 §7 supplied its sharpest evidence (the tag /
  payload asymmetry, observed in Gleam). Removed from the fog so it lives only as the ticket.
-->


## Out of scope

<!-- ruled beyond the destination; closed, never graduates -->

- **Tooling and ecosystem** — package manager, build tool, hex/rebar3/mix integration, LSP,
  formatter, docs generation. Every decision here is downstream of the language surface,
  and Gleam's experience suggests it is a multi-year track of its own.
- **Standard library breadth** — module-by-module design. The spec names stdlib *shape* as
  a design principle only.
- **Macros and metaprogramming** — quote/unquote, source generators, compile-time
  evaluation. A large semantic surface that interacts hard with a type system, and nothing
  about the core bet needs it.
- **Alternative backends** — a JavaScript or WASM target of the kind Gleam ships alongside
  its Erlang backend. Doubles the codegen surface and forces semantic compromises that
  would muddy a BEAM-native design.
