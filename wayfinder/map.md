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

  **Amendment — the bar for tier 3 is lower than "invent last" suggests** (David, 2026-08-12,
  ticket 27). *"It drifts from C#/TS, but it's 'like' those languages, not a perfect recreation on
  BEAM."* The goal is **resemblance, not reproduction**. A divergence needs a stated reason; it
  does not need an apology, and it does not need the borrowed construct to be unavailable. Ticket
  27 §2 is the worked case: C# permits `if (x is int i)` on a `T` and TypeScript narrows a generic
  with `typeof`, so the permissive rule was fully available as a tier-1 borrow — and was refused
  anyway, because beam-sharp checks clauses at the *definition* and the borrow would have made
  reachability unanswerable there. **Read tier 3 as "diverge deliberately", not "diverge only as a
  last resort".**

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
  **always written**, never inferred: neither audience expects implicit cast insertion —
  **amended by ticket 11**, where the rule holds and loses its keyword, since narrowing is
  written *as a clause head* and no `dynamic` exists.
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

- [Totality versus let-it-crash](issues/12-totality-vs-let-it-crash.md) — **the two were never
  opposed; let-it-crash is how you spell partiality.** Exhaustiveness is a **hard error with no
  opt-out** — two of the ticket's four candidates were already dead, since both presupposed a
  dynamic region ticket 11 removed. PureScript's `Partial` lost twice over: ticket 19 found it
  **erased before codegen**, and a propagating constraint is a second effect system beside an
  algorithm ticket 04 found has no complexity bound. A **catch-all is legal only over an *open*
  residual** — permitted where an unbounded top remains (and ticket 11 already forces it), an error
  where the residual is closed and the compiler knows the case names; a tier-3 invention, accepted
  because a uniform `_` puts the headline guarantee one character from being switched off
  invisibly. The boundary stance is **signature-directed**: write the honest value your return type
  admits, `raise` only where it admits none — so "crash in a call, ignore in a loop" is only the
  shadow cast by two return types, and **`ValidateAs<T>`'s `T | :error` is not an exception but a
  declared failure channel**. This is ticket 21's discriminator again: the decision *became a type*.
  The bottom is **`none`, first-class** (verified: `never()` is undefined on OTP 28, `erl_types`
  prints `none()`), mirroring ticket 11's `term` override — one heritage names the whole lattice;
  its false friend is the prelude's `:nothing`. A deliberate crash is **`raise`**, tier-2 from
  Elixir, verified to produce the **error** class, so C#'s `throw` is out on semantics — the BEAM's
  `throw` is the *catchable* class. **Both neighbours chose a keyword**, Gleam's bottom-typed
  `panic` decisively so, having had the function option and declined it — and the `Partial` benefit
  returns anyway, since a user-declared `none Reject(Reason);` *is* a greppable typed crash site.
  Finally, **this ticket reverses its own prior note**: the failure arm is **always emitted**.
  Omitting it saves **40 bytes (4.8%)** and destroys the crash report — `error:if_clause` (the
  wrong class) with an arity in place of the offending argument. `erlc`'s omission proves coverage
  over *all terms*; beam-sharp's is over the *declared type*, and ticket 21 says no foreign caller
  can be ruled out. So **yes, the process still dies cleanly**, deliberately paid for. Emitted
  guards (→ 18) are the only sound route to the saving, and it is only *available* on the Core
  Erlang path at all (→ 13).

- [Compilation target decision](issues/13-compilation-target-decision.md) — **the Erlang Abstract
  Format**, and the decisive reason is none of the five the ticket had stacked: the choice is a
  **one-way door, not a rung on a ladder**. `.abstr → Core` is `erlc +from_abstr +to_core`, free,
  OTP doing the translation; `.core → abstract forms` is `{raw_abstract_v1,[]}`, unrecoverable.
  Core's one live advantage — a `when` wider than Erlang's — was already spent by tickets 08 and 09
  fixing the guard vocabulary to the BEAM guard set. The emission contract is **a sequence of
  abstract-format forms**, with a standing obligation that the frontend **never depend on
  in-process compiler state**, so `erlc +from_abstr` always works (verified: builds with no `.erl`
  on disk) — which **frees the compiler's host language** and costs `erl_syntax`/`merl` as a churn
  abstraction, permanently; §4's pinned OTP range (current + previous two majors) proved by a CI
  corpus is the replacement. **Sub-modules are source-only**, one `.beam` per aggregate, and 01d's
  sharpest objection is **largely false on this target**: repeated `{attribute, ANNO, file, …}`
  forms re-point everything after them, so two functions in one BEAM module report crashes against
  two different `.bs` files — per-function hot swap is rejected, not deferred. **A `-spec` is
  emitted for every function whose type is known**, widening to the nearest expressible supertype
  where set-theoretic types have no Erlang spelling (silent: `-Wunderspecs`/`-Wspecdiffs` turn
  warnings *on*). **This discharges the 13/18 coupling** rather than deferring it — it was
  conditional on the Core branch — so ticket 06's recommendation stands. Sharpest downstream
  consequence: **ticket 18 loses an argument.** Ticket 12's 40-byte saving is unavailable on this
  target at all (`erlc` inserts the `match_fail` arm and it cannot be suppressed), so emitted
  guards are no longer the route to a saving that exists — **18's remaining motivation is silent
  unsoundness alone**. Ticket 14 inherits no facade to design.

- [Concurrency and the OTP model](issues/14-concurrency-and-otp-model.md) — **the concurrency
  vocabulary is OTP's, and nothing in it is parameterised by a message type.** Ticket 03's
  `Pid[τ]` is **declined**: it is inexpressible (ticket 09 has no nominality, so `pid<A>` and
  `pid<B>` are the same set — Gleam's phantom parameter works only because Gleam is nominal),
  unnecessary (the message type belongs on the **client API function's signature**, where it was
  going to be written anyway), and unsound-proof-free (ticket 21 rules out ruling out foreign
  senders). Measured: **four of the five wrong-pid failures are exits**, so the type system can
  decline to model process identity and lose almost nothing; only a *shape collision* returns a
  wrong value, and that is ticket 18's. **No `async`/`await`/`Task`** — `async` colours functions,
  which is the second effect system ticket 12 already refused. **Pinto's closures-as-messages is
  inadmissible** under ticket 11's arrow rule, so callbacks are per-module multi-clause functions.
  **`[module: GenServer]` names a contract the compiler knows as a type**; the user writes a
  narrower signature and the compiler checks containment — **Dialyzer already does exactly this**
  for the return direction and silently misses the *argument* direction, which beam-sharp gets
  free from contravariance. That choice is the reversible one: the wide contract is reachable as a
  signature a user writes, or a generator default (→ 23). **`receive` is syntax and a *filter*,
  exempt from exhaustiveness** — unmatched messages stay in the mailbox, which is what
  `gen_server:call`'s own reply correlation runs on. **The prelude is stratified** à la Elixir's
  `Kernel.SpecialForms`, with OTP's message shapes in the compiler-known stratum. That last one
  closes a hole the ticket found and nothing else catches: a **mis-shaped `handle_info` clause
  never fires and the mandatory catch-all absorbs it in silence** — invisible to exhaustiveness
  (open residual) and to redundancy (every clause reachable against `term`). **Ticket 03's Gleam
  gap is closed by measurement**: `Subject` types the send side only, receive is a runtime
  `{tag, arity}` map lookup, unmatched messages are logged and dropped, and **named subjects are
  forgeable from raw Erlang** via `registered()/0`. Corrects prototype 01e. Sharpest downstream
  consequence: **ticket 27 loses a motivating case** — `Pid[τ]` was the clearest demand for a real
  type parameter in the map.

- [Parametric polymorphism](issues/27-parametric-polymorphism.md) — **the language has real
  parametric polymorphism, and it is the smallest version of it that works.** The ticket's question
  was three questions wearing one coat, and only one was live: parameterised *constructors*
  (`list<int>`) were already forced by 09/11 and are not polymorphism at all, parametric *aliases*
  (`option<T>`) arrived near-settled from 10, and only **polymorphic function signatures** were
  open. Yes — on a cost argument the map must now protect: the frightening results attach to
  *inference* and to *intersection-typed* functions, and **beam-sharp had already refused both for
  unrelated reasons** (04 made signatures mandatory; 08 settled one arrow per arity with union
  parameters, so a function type is `(A|B) -> (C|D)`, never `(A->C) & (B->D)`). Instantiation is
  therefore matching, not solving — and **§3 unbounded and §7 no-row-polymorphism are what keep
  that true**, not independent preferences. Four rules: variables are **opaque in clause heads and
  guards** (a bare variable admits exactly one clause — bind it; structure *around* it matches
  freely, so `Map`'s `[]`/`[h, ..t]` are exhaustive at the definition for every instantiation);
  **unbounded**, with capability constraints deferred to ticket 16 because a bound is *ad-hoc*
  polymorphism wearing a bracket; **declared, C# `T`-convention** — forced, because beam-sharp's
  builtins are lowercase, so lowercase-implicit is ambiguous where Gleam's is not; and **variance
  is not a concept**, since 09's abolition of nominality leaves nothing to annotate or infer.
  *Rejected: monomorphise per call site* — it fights ticket 13's aggregate-granularity hot loading
  and separate compilation, working *inside* an aggregate and failing exactly where a shared
  `List.Map` lives. Two measurements: **an emitted polymorphic `-spec` is documentation, not
  enforcement** (Dialyzer reads the variables as `any()`; the monomorphic control fires), so
  **choosing generics made the boundary strictly weaker → ticket 18**; and **syntax recovers an
  element-type relation with zero polymorphism** (`roundtrip` preserves `[integer()] -> [binary()]`
  where the same computation through an opaque fun collapses to `[any()]`), which is why row
  polymorphism was declined — `with`/spread already covers the case that would demand a row
  variable. Forced consequences: **codegen obligations require a ground type argument**, so
  `ValidateAs<TSource>` is rejected inside a polymorphic function; and **polymorphic recursion is
  permitted** because 04 already paid for mandatory signatures — the undecidability is about
  inference. **Ticket 16 is unblocked**, and inherits the rule that names its own boundary: *a type
  variable is a slot for values you carry; a union is a slot for values you examine.*

- [Error model](issues/15-error-model.md) — **the headline question was already closed and the
  ticket did not know it**: ticket 12 §3's signature-directed stance means there is no global
  error-model preference to pick. What was open was the *shape* of failure, and it had a defect in
  it. **The untagged failure channel collapses** — measured on Elixir 1.19.5, `option<atom>`,
  `ValidateAs<atom>` and `option<option<int>>` all normalise to their success type, because ticket
  09's own normalisation rule absorbs a singleton into a cofinite top before discriminability is
  ever asked. **Ticket 10 §5 had already written a degenerate line** (`ToExistingAtom // atom |
  :nothing` *is* `atom`). The shape stays untagged and **the collapse is an error at the
  declaration** — 09's rule turned on the prelude, diagnostic landing where the fix is; tagging both
  channels was refused because the cost falls on `as T`, the showcase narrowing. The rule for the
  two spellings is **absence carries nothing, failure carries a reason**: `option<T> = T |
  :nothing` bare, `result<T, E> = T | (:error, E)` tagged — **and the tag is a consequence of the
  payload, not a separate choice**, since `atom | (:error, binary)` does *not* collapse where `atom
  | :error` does. So the payload is what makes the channel survive, not merely what makes it
  informative. **Amends ticket 11**: `ValidateAs<T>` returns `result<T, ValidationError>`. `raise`
  takes **any term** (exactly `:erlang.error/1`) sharing its vocabulary with `E`, which makes
  escalation an ordinary three-line function rather than a `?` operator. **There is no `try` in the
  surface**: measured, `monitor`+`receive` replaces it for *remote* failure using only ticket 14's
  `receive`, and yields a **better** reason than `try` does — leaving foreign in-process throws as
  the only gap, closed by a compiler-emitted wrapper from the declared return type, the fourth
  codegen obligation. **Gleam was measured into this position, not the stricter one** — no surface
  `rescue`, nine `try`/`catch` in its FFI — so the question was never whether the `try` exists but
  whether it is *checked* or a human's unverified assertion. `throw` and `exit` get **no spelling to
  produce** (clause heads and `(:stop, …)` already do their jobs) and the wrapper catches all three
  classes into `foreign_error`, **safe because exit *signals* are uncatchable** — a locally-raised
  `exit/1` and a signal are different mechanisms sharing a keyword, so no supervision decision can
  be swallowed. Sequencing is **required and handed to ticket 17**: `with` is spoken for by ticket
  26's record update. *A methodological note kept in the file: the first run of 15c reported every
  case surviving, because the harness wrapped each in `catch` — supplying the protection the probe
  existed to measure.*

- [Ad-hoc polymorphism](issues/16-ad-hoc-polymorphism.md) — **the language gets no ad-hoc
  polymorphism construct, and the hole ticket 05 flagged was half imaginary.** The three
  motivating capabilities were *measured* before being designed for and land in three different
  buckets, none of which is dispatch: a capability the type determines becomes a **codegen
  obligation**; a capability over a set known at the definition is a **union parameter** with a
  clause each; a capability over an unknown set is **passed as an argument**. Protocols died on
  ticket 13, not on taste — open extension needs whole-program consolidation, which fights
  aggregate granularity and hot loading, *the same argument 27 used against monomorphisation* —
  and the static-closed variant is bucket 2 with ceremony, which **corrects this ticket's earlier
  "consolidation by construction"** line. Measured: the BEAM's term order is **total across every
  type** (`1 < :ok` is `true`), so "anything comparable" needs no mechanism — but `<` is
  restricted to **same-type operands** with the universal order kept as a *named* prelude escape
  (`ordered_set`, mixed-key sorting). **`==` means `=:=`**, decided on internal agreement rather
  than familiarity: Erlang's `==` coerces through tuples, lists and map *values* then **stops at
  map keys**, while the clause head and `maps:get` do not coerce at all — so the exact spelling
  agrees with two constructs and disagrees with none. The generation rule is **the type determines
  the result, inherently or by published decree**; serialisation qualifies by decree because
  `json:encode/1` **fails on tuples at any depth, at runtime**, and tuples are this language's
  workhorse (09's newtype remedy, 15's `(:error, E)`) — generation moves that to compile time, and
  **only the encode direction is new** since decode is `ValidateAs<T>` after a parse. `<` and `==`
  work on **bare type variables** (total, non-dispatching, cannot fail), so `Sort<T>` and `Max<T>`
  are free — and **bounds are refused outright**, not deferred: both routes to discharging one are
  closed by 09 and 27, which **retires 27's cost measurement**. Finally, **ticket 05 miscategorised
  extension methods** (David) — one debt, not two; the call-syntax half was always 17's and the
  overloading half was always 08's, leaving *static abstract interface members* as the whole real
  hole, and **a codegen obligation is exactly that with the compiler writing the implementation**.
  Sharpest downstream consequence: **ticket 18 gains a consumer** — a generated encoder trusts a
  declared type the boundary does not enforce, and crashes inside code no one reviewed.

- [Pipeline and comprehension idiom](issues/17-pipeline-and-comprehension.md) — **four constructs
  removed, one added.** The chaining form is `|>` with **qualified** names, and the dot fell to a
  *mechanism* rather than to taste: `xs.Filter(f)` needs type-directed resolution of an unqualified
  name, which 08 (no overloading) and 16 (one dispatch mechanism) both closed and 16 §6 had already
  parked in the fog. **LINQ dies to the identical argument** — ECMA-334's translation emits
  unqualified names — so **this ticket's stated conditional was answered by rejecting its premise**:
  the cost was never in the type system, and LINQ pays exactly what the dot pays. The dot is not
  abolished but *narrowed to never being a call* (→ 26). **There is no comprehension syntax, because
  precision is a lowering decision, measured**: emitting an inlined comprehension recovers 27a's
  exact `[integer()] -> [binary()]`, where emitting a call to the generic prelude loses **both**
  sides — worse than `lists:map/2` loses, since beam-sharp's own declared spec overrides its body's
  success typing. Fusion is free and lossless. So one rule: **the compiler-known prelude is inlined,
  user code is called, and precision follows the inlining** — which creates a **two-tier emitted
  boundary** the spec must state (→ 18). **27a's fold limit is corrected**: inlined monomorphic
  recursion keeps both sides for fold too, so the mechanism was never "comprehension" but *a
  monomorphic body the analyser sees through*, and one rule covers map, filter and fold. Fallible
  sequencing is **the valve, `|?>`** — chosen over a generated `[Propagates]` clause because that
  would have been the **sixth codegen obligation**, and over `Result.Then` because only the
  combinator forces a function-as-value spelling; the fully implicit rule was closed by 08's
  *narrowing is always written, never inferred*. `?` is free (10 dropped the ternary) and is a
  **tier-1 borrow for both audiences at once** — C#'s `?.` and TS's optional chaining are the same
  semantics, and 15's untagged `result` makes `(:error, E)` the exact analogue of `null`. **There is
  no `if`**: `switch` is the only branching construct, *the way Go has one loop* (David), with a
  **tuple subject** for the subject-less ladder — tier-1 C#, Gleam's multi-subject `case`, and the
  clause head's own shape, converging. Measured, not cited: **Gleam has no `if` at all** and its
  error text hands you `case`; **`else` is an `if`-only keyword** — Elixir's `case` and `cond` reject
  it outright, and `cond`'s catch-all is a *clause*. The structural reading is what decided it —
  `else` is what a binary unnamed conditional needs, and keeping it would have added the only
  construct whose fall-through is not expressible as a pattern. Two questions die with `if`: the
  one-armed case 10 routed here, and 15's `option<atom>` collapse landmine. Strict only; **lazy
  deferred, not refused** (David), and cheap to add *because* names are qualified. Bonus finding:
  **Gleam's inexhaustive-`case` error prints the missing pattern**, which is 04's residual observed
  live (→ 23).

- [Boundary defence](issues/18-boundary-defence.md) — **the eight channels were never eight
  questions.** Ticket 11 had already defended every `term → typed` transition *inside* the language
  by making narrowing syntactic, so five channels were closed on arrival and what remained was every
  point where a **type is declared at an entry**. The guarantee is **"a foreign term that breaks your
  types will crash — not always where it entered, but never silently"**: outcome 1-or-2, never
  outcome 3, with a guard emitted **only where the function's own body would not object** and
  **always** where generated code consumes the value (16's encoder, 17's inlined operations),
  **never** on type variables. **The census is why it is that and not more**: measured across all of
  stdlib and kernel, **83.3% of exported parameter positions are bare variables** — Erlang buys
  outcome 2 for free from its BIFs and pays nothing at the boundary, so C tops up only where the free
  check is absent, which after 16 and 17 is exactly where *generated code replaced a body you could
  read*. **Foreign declarations may promise only what one BEAM guard decides in O(1)**; `list<Order>`
  is an error at the declaration and crosses as `list<term>` + `ValidateAs<T>`, whose `result` forces
  the failure arm — **ticket 11 §2's rule at a second site, closing channels 5/6/8/10 together and
  dissolving the FFI `-spec` sub-question** (a checked claim needs no exception). This is **Ecto's
  idiom made uniform**: measured in a local app, 9 changeset pipelines beside 5 ETS reads that all
  bind the payload bare — *the same shape the Gleam probe produced*, because "you filled that table
  yourself" is what 21 says you cannot prove. **Gleam trusts its `@external` and publishes the false
  claim as a `-spec`** (measured: `-> Int` returned `41.5`), and **Erlang and Elixir are not
  precedents at all** — no construct declares a foreign type, so they cannot break a claim they never
  made. **The state channel is wider than charted and 14 left it open**: `sys:replace_state/2` let any
  process substitute a state whose declared-`int` field returned a binary, so defence sits at the
  *entrances* — `ValidateAs<State>` in `code_change/3`, `init` trusted, nothing per-message — with
  `sys:replace_state` a **named limit**, a point 21's mechanism cannot reach because OTP applies the
  fun inside a loop beam-sharp does not compile. The analysis is **function-local**, decided by the
  standing constraint: whole-aggregate would let an edit to one file silently move another file's
  boundary, reintroducing the blast radius one-function-per-file removed. **No opt-out.** Cost
  measured and small (+3–5 bytes per `is_integer`, call time below the ±0.09 ns/call resolution), and
  one structural finding kills a design option: **elision is exported-vs-local, not local-call vs
  remote-call**, since a BEAM function has one entry label — so a guarded-public/unguarded-internal
  pair is impossible, and interior functions already pay nothing. **Elm is the one language that
  genuinely defends its boundary and it does not transplant** — it synthesises a decoder per incoming
  value, but owns *the one door*; **this partially retracts ticket 21**, whose "no language defends by
  checking data" is false, sharpened to *checking data is what you do at a door you own*. Two
  corroborations worth keeping: Elm's admissible port set is **exactly ticket 09 §4's rule reached
  independently**, and **outcome 3 survives inside Elm's checking boundary** (`1e300` through an `Int`
  port) — a leak beam-sharp does not inherit, since `is_integer` is exact. The tag/payload asymmetry
  was sighted **three times in one session** — Gleam's FFI, a real Elixir ETS read, an OTP callback
  head — which is the ticket's strongest evidence that a pattern match is not a check.

- [Untheorised term shapes](issues/20-untheorised-term-shapes.md) — **the five sightings of
  "binaries are where precision dies" have one cause, and it is not binaries.** Every one traces to a
  *join* that over-approximates on the way in, never to a subtraction failing on the way out:
  `erl_types` collapses `<<_:32>> | <<_:64>>` into `<<_:32,_:_*32>>`, which admits a 96-bit value
  nobody declared, and 04's residual then subtracts correctly and walks forever. The same failure
  appears in a **second domain** — integer ranges are quantised onto a fixed ladder, `5..20` snapping
  to `1..255` — so the finding generalises: **beam-sharp inherits this platform's type *grammar* and
  cannot inherit its *algebra*, in any domain**, because Dialyzer is a success-typing tool that may
  only ever be optimistic. **The surface admits the full `<<_:M, _:_*N>>` grammar with an exact
  union**; a fixed size is closed and provable, a repeating unit is open and takes 12's catch-all,
  and exact negation is never needed since only emptiness and openness must be decided. **Ticket 18's
  boundary question answers "anything the grammar can spell"** — `byte_size` and `bit_size rem N` are
  guard BIFs, measured O(1) at 8 B and 8 MiB alike — which lands opposite to expectation: **binaries
  need no `ValidateAs` where 26's records do**. **17 §3's fixpoint widening was never a codegen
  artefact** (its probe declared no spec; a declared one lands in the abstract chunk verbatim).
  **`json:encode/1` crashes on non-UTF-8 binaries and on all bitstrings**, a fifth sighting 16 §4
  assumed away — so **`string` is `binary` refined by valid UTF-8**, a bare `binary` encodes as
  base64, a non-byte-aligned bitstring is a compile-time error, and **a literal is a `string` by
  construction**. That forces **refinements, in two tiers cut on the map's recurring line**: guard
  refinements are reasoned about, legal in clause heads and at FFI, and **user-declarable**; opaque
  O(n) refinements are **compiler-known only** (11's *"size a foreign sender chooses"* at a second
  site), which **answers the fog's question about adding to the prelude's second stratum — no**.
  **Integer intervals join the algebra**, buying guarded partitions without a catch-all and `-spec`
  precision — *not* `Fib`. **Improper lists are a named limit**: `is_list` admits `[1,2|3]` so
  `list<T>` is not O(1)-decidable, but the adopted lowering gives `function_clause`, so 18's
  guarantee holds. **Taint refused**, per 21. Two corrections: **11 overstated its own debt in both
  halves** (exhaustiveness never needed intervals; termination was never promised), and **refinements
  do not settle 09's newtype gap** — a refinement is a set, so `Meters` and `Feet` as
  `float where value >= 0` are still one type and **09's tuple tag stands**.
  **AMENDED 2026-08-13 by [ticket 29](issues/29-refinement-type-prior-art.md), which checked this
  ticket against the prior art it was resolved without. Nothing decided is wrong; four things
  change and one is reopened.** **The two-tier cut is a tier-3 divergence, not the O(1) line
  applied again** — *no shipping language cuts refinements on the cost of deciding the predicate*,
  Ada included, and Ada 2012 divides on the predicate's **syntactic form** instead (measured on
  GNAT 12.2: `Odd mod 2 = 1` is rejected as not predicate-static while `Positive_Ish > 0` is
  accepted — identical runtime cost, opposite tiers). The relation is **containment**: every Ada
  static predicate is one BEAM guard and the converse fails, so beam-sharp's cut liberalises a line
  Ada drew syntactically for want of a platform-given decidable predicate language. **Ada
  corroborates the structure independently**, having barred its dynamic tier since 2012 from every
  construct where the compiler must enumerate or bound the subtype. **CDuce is measured at last**
  — `doc` → `local`, pinned at **0.6.0 (2017-03-17)**, installed via `archive.debian.org`: its
  interval algebra is exact at every operation *including complement*, and **no SMT library is
  linked**, so 20's affordability argument is demonstrated rather than asserted; 29 also publishes
  the cost nobody had, below the measurement floor at 40 clauses and quadratic past ~200. **The
  `string`/`binary` split is a tier-1 borrow 20 did not claim** — but both audiences silently
  substitute U+FFFD on invalid UTF-8, which is 06's outcome 3 in the two languages beam-sharp
  borrows from, so the *behaviour* is a deliberate divergence; .NET's serialiser independently
  reaches 20 §4's base64 while node does not. **A third `erl_types` lossiness** (verified here:
  `t_bitstr(8,72)` → `<<_:64,_:_*8>>`) and its motive is worse than the other two — a
  **finite-height lattice, exactness traded for termination** by the platform's own designers, in
  the domain 20 commits to exactness in. **beam-sharp escapes it, and the skeleton is the
  evidence**: 04 made signatures mandatory, so nothing iterates to a fixpoint and the residual only
  shrinks — the skeleton's unbounded interval lattice terminates at every clause count measured.
  **Reopened for David**: whether users may declare *opaque* refinements at all. Ada permits them
  and contains them with the same placement rule beam-sharp already applies, so the ban on
  *declaring* one may do no safety work the placement rule is not already doing — against which
  beam-sharp's checks have **no opt-out** where Ada's switch off with `-gnata`.
  **RESOLVED same day — the refusal is narrowed to a placement rule (David).** ~~Gap [g3]:
  GNATprove was never run.~~ **[g3] closed**: GNATprove 12.1.0 **discharges a `Dynamic_Predicate`
  statically whenever the caller's contract entails it — including an O(n) content predicate**, the
  direct analogue of `binary where valid_utf8`, induction carried by an ordinary loop invariant. So
  Ada's permissiveness is *not* "permit and check later". Also measured: **SPARK's line is not
  Ada's** — `Odd mod 2 = 1` is refused Ada's static tier on form while `Pos > 0` is admitted, and
  SPARK treats them identically, so Ada's split is front-end *legality* where SPARK's is
  *entailment*. **The evidence and the rule are the same shape**: SPARK proves it where the caller
  is inside the verified subset, and at beam-sharp's boundary the caller never is (21 rules out
  ruling out a foreign sender). So **user-declared opaque refinements are barred from clause heads
  and foreign declarations, and permitted elsewhere** — interior, caller known, the predicate is a
  dischargeable obligation; boundary, caller unknown, it is unbounded cost with nothing to discharge
  it against. Accepted with the cost open-eyed: **beam-sharp pays for every check, always**, where
  Ada's switch off with `-gnata`. Three things this owes are recorded on the ticket (may the
  compiler call user code at a boundary; a spelling for the check site; what happens when the
  predicate raises → 15's `result<T, E>`, Ada's `Predicate_Failure` the precedent). Residual limit:
  `alt-ergo` would not run, so a *negative* proof result must not be read as unprovable.

- [Refinement types in shipping languages: what did ticket 20 reinvent?](issues/29-refinement-type-prior-art.md)
  — the prior-art pass ticket 20 was resolved without. **Nothing it decided is wrong**, and the
  amendments are folded into 20's entry above; what belongs to *this* ticket is the verdict.
  **Ada corroborates the two-tier structure and contradicts the cut** — it divides on the
  predicate's *syntactic form*, not its cost, so beam-sharp's O(1) line is **attested nowhere in the
  prior art surveyed** (Ada, Liquid Haskell, F\*, Nim, Whiley, Dafny) and is a tier-3 divergence
  rather than the map's recurring rule applied again. The relation is **containment**: every Ada
  static predicate is one BEAM guard, so beam-sharp liberalises a line Ada drew for want of a
  platform-given decidable predicate language. **Solver-free interval refinement does ship** — CDuce
  0.6.0 measured at last, exact including complement, no SMT linked, free at 40 clauses and quadratic
  past ~200 — which is what turns 20's affordability argument from asserted into demonstrated. And
  **GNATprove discharges an O(n) content predicate statically when the caller's contract entails
  it**, the measurement that narrowed 20's blanket refusal to a placement rule. Method note worth
  keeping: the borrow heuristic ran *correctly* and still missed this, because it has no rung for a
  language neither audience uses which solved exactly this problem — the reason to raise a prior-art
  ticket is the mechanism being invented, not the heuristic misfiring.
- [The walking skeleton, first slice](../compiler/README.md) — **built 2026-08-13, and the premise
  that delayed it was stale.** The fog said the slice "cannot be phrased sharply until the language
  surface exists"; that was written at charting, before any of the twenty-three resolutions, and it
  is true only of the *whole* surface. A slice touching **only closed decisions** existed and was
  invisible because nobody re-tested the claim. `.bs` in, callable `.beam` out: lex → parse →
  exhaustiveness check → abstract format → `erlc +from_abstr`. **Host is Erlang** — `leex` and
  `yecc` ship with OTP, and `merl`'s `?Q` quasi-quoting rides on a parse transform Elixir cannot
  use, so ticket 13's freeing of the host language was exercised rather than merely enjoyed.
  In: 01/04/08's multi-clause heads under a mandatory signature, 09/10's atoms and structural
  unions, **20's exact-union algebra and real integer intervals**, 08's guards-as-type-operations,
  12's failure arm, 13's Abstract Format with an emitted `-spec`. Out on purpose: records, generic
  syntax, modules, imports, FFI, OTP behaviours, refinements, binaries. **Ticket 01's hand-verified
  finding is now produced by a compiler** — four beam-sharp clauses, four native Erlang clause
  heads, guard firing, and a *precise* spec (`{ok, integer()} | {error, atom()}`), not a widened
  one. **Two of the eleven skeleton debts are discharged** (see the two struck-through entries
  below), and **two bugs were found by tests, one of them a soundness bug**: an uncreditable guard
  was subtracting its whole pattern, so `F(n) when Weird(n)` reported exhaustive — ticket 08's
  "credits nothing" must mean the clause contributes *nothing*, and `Certain`/`Possible` are now
  separate bounds. The other grew a lower bound from nothing on disjoint range subtraction
  (`{64,64} \ {32,32}` gave `{33,64}`), which breaks the one property ticket 20 exists to
  guarantee. **Names are emitted losslessly and quoted** (`'Readings':'Classify'`) — provisional,
  and deliberately the option that pre-empts the modules fog least.

## Not yet specified

<!-- in-scope fog: real, but not yet sharp enough to phrase as a ticket -->

- **The walking skeleton**: which slice of the spec it implements, and what language the
  compiler itself is written in. Cannot be phrased sharply until the language surface exists.
  **The first slice is BUILT (2026-08-13) — see Decisions-so-far. Two debts below are struck
  through as paid; the rest stand, and now have somewhere to be measured.**
  ~~One requirement is already known: it should **measure checker cost at the clause counts the
  showcase implies**. Ticket 04 found Etylizer's pathological inputs are `case` expressions
  with 40+ branches — precisely the large multi-clause `handle_info` this language advertises.~~
  **PAID 2026-08-13** (`compiler/bench/bs_bench.erl`, OTP 28.5, JIT warmed, 20 reps): the
  exhaustiveness check is **linear through the advertised shape and costs 59 µs at 40 clauses** —
  8.5 µs at 5, 29 µs at 20, 59 µs at 40, 151 µs at 80, all at 1.3–1.9 µs/clause. **There is no
  cliff where ticket 04 feared one.** It does begin to bend at **160 clauses (656 µs, 4.1
  µs/clause)**, which is the first observed sign of the complexity bound ticket 04 said does not
  exist — worth re-measuring when the algebra gains records and binaries, since both widen the
  product decomposition.
  **Ticket 11 adds a second requirement**: the skeleton must **generate at least one
  `ValidateAs<T>`**, over a recursive type. It is the first codegen obligation whose cost is
  entirely unmeasured — a synthesised O(n) structural traversal — and it stacks with the
  recursive-type measurement ticket 09 already asked for. ~~**Ticket 12 adds a third**: measure the
  retained failure arm at showcase clause counts. It was measured at 40 bytes (4.8%) on a
  two-clause function; the decision to keep it everywhere was taken without knowing the cost on a
  40-clause `handle_info`, which is the shape this language advertises.~~
  **PAID 2026-08-13, and it lands the reassuring way**: the arm is **constant-size, not
  proportional** — ~15 bytes of the `Code` chunk regardless of clause count, so its share *falls*
  as clauses grow: **10.6% at 2 clauses, 4.95% at 20, 2.76% at 40**. Ticket 12 kept it everywhere
  while worrying what forty clauses would cost; forty clauses cost proportionally less than two.
  Two honesty notes. The absolute two-clause figure here (11 bytes) does **not** reproduce ticket
  12's (40 bytes) — different harnesses measuring different things, and neither has been reconciled
  against the other, so treat the *shape* of this result as the finding and not the constant. And
  the first run of this benchmark was an **artefact**: with every clause returning the same atom
  the optimiser folded them all into the catch-all, pinning the baseline at 70 bytes for 2 clauses
  and 40 alike and reporting the arm as 66% of the chunk. Distinct return values fixed it. Recorded
  because the artefact was plausible and would have been believed. **Ticket 13 removes one
  constraint and adds two requirements.** Removed: **the compiler's host language is no longer
  constrained** — the emission contract is abstract-format forms, and `erlc +from_abstr` builds
  from serialised text with no `.erl` present, so the skeleton need not be a BEAM program. Added:
  it owes the **CI corpus** proving the pinned OTP range (current and previous two majors), and it
  owes **confirmation that `+from_abstr` exists on the oldest supported release** — only OTP 28.5
  is installed here, so the range is provisional until measured. Note the third measurement
  requirement above is now moot in one direction: ticket 12's failure arm cannot be suppressed on
  this target, so what remains to measure is its cost at showcase clause counts, not whether to
  keep it. **Ticket 14 adds two things to the CI corpus**, because the language now ships a *model
  of OTP* rather than only emitting for it: the **behaviour contracts** it checks callback
  signatures against (§4) and the **system-message shapes** in the compiler-known prelude stratum
  (§6). Whether either differs across the pinned range is **unmeasured** — only OTP 28.5 was
  installed when 14 was resolved. **Ticket 27 adds a fifth measurement and removes a worry.**
  ~~Added: if ticket 16 later wants **bounded type variables**, bounds are the feature that turns
  instantiation from matching into constraint solving, so their cost must be measured at showcase
  clause counts before they are accepted.~~ **RETIRED 2026-08-12 by ticket 16 §5** — bounds are
  refused outright, not deferred: a bound is undischargeable here because monomorphisation is
  closed by 13 and dictionary passing by 09, so the skeleton never owes that number and
  instantiation stays matching, not solving. Removed: the ticket's own fear that
  *recursive plus parametric* would be the combination that breaks the budget is now bounded by
  the four things 27 refused — no inference, no intersection arrows, no bounds, no row variables —
  so what the skeleton measures is a matching problem, not tallying in its general form.
  **Ticket 15 adds a sixth measurement and a new obligation.** The **compiler-emitted foreign
  wrapper** is the fourth codegen obligation, and the first whose cost is per *call site* rather
  than per type — it stacks with `ValidateAs<T>`'s traversal, and a program calling Erlang in a
  loop pays it repeatedly where the traversal is paid once. Also owed: confirmation that the
  emitted `try` survives the abstract-format path unchanged across the pinned OTP range, since
  ticket 13's `-spec` widening was already found to be silent about what it loses.
  **Ticket 16 adds a seventh measurement and retires the fifth.** Added: the generated
  **serialisation encoder** (§4) is the fifth codegen obligation and the second whose cost is a
  synthesised structural traversal — it stacks with `ValidateAs<T>` over the *same* recursive type,
  so the skeleton should measure them together rather than separately. Retired: 27's
  bounded-type-variable measurement, above — bounds are refused, not deferred.
  **Ticket 17 adds an eighth, and it is the first that is a cost rather than a capability.**
  17 §2 buys emitted *precision* by **inlining** every compiler-known prelude collection operation at
  every call site, and it priced only the benefit. The skeleton owes the **code-size** number at the
  pipeline lengths the showcase implies — this is a straight trade of emitted size for emitted type
  information, and no codegen obligation so far has had to be weighed that way. It also owes a check
  on the assumption 17 §8 records rather than establishes: **inlining a prelude function into a
  caller means a change to the prelude does not reach that caller without recompiling it**, which
  runs against ticket 13's aggregate-granularity hot loading. Probably benign because the prelude is
  compiler-known, but unverified.
  **Ticket 18 adds a ninth, and it is the first argued from *frequency* rather than from cost.**
  `ValidateAs<State>` inside the compiler-emitted `code_change/3` (18 §3) is an O(n) traversal
  affordable *because hot upgrades are rare*, not because it is cheap — so the skeleton owes the
  upgrade's cost at a realistic state size, which is the number that would falsify the reasoning
  rather than confirm it. Two smaller debts from the same ticket, both from
  [`prototypes/18a`](prototypes/18a_guard_cost.md): the **JIT-emitted native size** of a guard is
  unmeasured (§1b tried and failed — `erlang:memory(code)` varies by tens of kilobytes with load
  order alone), and every timing there is a **tight monomorphic loop with a warm cache**, so nothing
  says what a boundary guard costs at a cold or megamorphic call site. Note also that 18 §4's
  function-local rule makes the guard count predictable per function, so the corpus can *count* the
  emitted guards rather than estimate them.
  **Ticket 20 adds a tenth and an eleventh, and the eleventh is the first that is a cost in the
  *checker* rather than in emitted code.** Added: **`string`'s UTF-8 entry check is the sixth codegen
  obligation**, and the third whose cost is a synthesised O(n) traversal — it stacks with
  `ValidateAs<T>` and with 16's encoder, and unlike either it lands on the language's most-passed
  value, so the skeleton should measure it on a realistic string-handling path rather than in
  isolation. Note 20 §4 removes the obvious worst case by making a **literal a `string` by
  construction**, so what is owed is the runtime-built and foreign-received cost only. Added: **the
  exact binary union and the interval domain are two new algebra components the platform does not
  supply** — 20 measured that `erl_types` collapses same-constructor binary unions and quantises
  integer ranges, so beam-sharp implements both itself. Neither is expensive in principle (finite
  unions of intervals have a decision procedure; binary unions are pairs of integers), but both feed
  the exhaustiveness algorithm ticket 04 found has **no complexity bound**, and the skeleton owes the
  residual-computation cost at showcase clause counts over a *binary* subject — which is exactly the
  40-clause `handle_info` shape, now with a second domain in the algebra.
- **The typed model of OTP itself** — new with ticket 14, and distinct from the corpus that proves
  it. The language knows behaviour contracts and system-message shapes as types. Open: which
  behaviours ship built in (gen_server, supervisor, application, gen_statem, gen_event), how a
  **user-declared** contract is spelled — ticket 21 named Roc's `requires` as the stealable
  mechanism and 14 left generalising it as purely additive — and what happens to a *library*
  behaviour defined in Elixir. Not yet sharp enough to ticket, because it hangs on the prelude
  question below. **Ticket 18 §3 adds a second axis to this patch, and it is not the one the patch
  currently asks about.** Beyond *which* behaviours ship built in and how a user declares one, the
  compiler now **emits code inside the callbacks it knows**: `code_change/3` carries a generated
  `ValidateAs<State>`, decided because that entrance is rare where the per-message path is not. So a
  behaviour contract is not only a signature the compiler checks against — it is a set of callbacks
  the compiler may *write into*. Open with it: which other known callbacks earn emitted code, and
  what a **user-declared** contract can ask the compiler to emit, given ticket 21 named Roc's
  `requires` as the stealable mechanism and 14 left generalising it as purely additive.
- **Module and namespace system**, and function identity — BEAM identifies functions by
  name *and arity*, which multi-clause heads and optional parameters both disturb. **Ticket 10
  §3 adds one requirement**: a module identifier in value position is an atom singleton, so this
  fog owes an answer to *what atom is actually emitted* — a bare snake_cased name, which risks
  colliding with Erlang modules, or something prefixed as Elixir's `Elixir.` is. Ticket 10
  deliberately did not decide it. **Ticket 13 sharpens this with two measured facts and settles one
  half of it.** Settled: **sub-modules are source-only**, so the *aggregate* is the BEAM module and
  a sub-module is not a module at all — while still being named in crash reports, via repeated
  `file` attributes. Sharpened: `erlc` **enforces module-name/filename matching on the
  `from_abstr` path**, so whatever atom a module identifier lowers to, the emitted `.abstr`
  filename must equal it — which makes the emitted-atom question a *build-layout* question too, not
  only a collision-avoidance one. A dotted atom (`'Shop.Orders.Order'`, Elixir's convention)
  works unchanged.
- **The language's name.**
- **Imports and cross-module scope** — if a directory is a module, what do files in it share
  automatically, and what must be imported? Slipped into a prototype example unexamined.
  **Ticket 16 §6 adds one concrete leftover**: C# lets you put a function in *another* namespace so
  it appears on that type without an import — the half of extension methods that is neither call
  syntax (17's) nor overloading (08's). It is **name resolution, not polymorphism**, it has no
  beam-sharp answer, and it is the only part of C#'s extension-method feature this map has not
  placed.
- **Where DDD invariants live** — not commands, not types. An `Invariants` module, refinement in
  the type declarations, or nothing. **Ticket 20 §5 settles half of it and splits the rest by a
  sharp line**: refinement in the type declarations *is* available, but only where the predicate is
  a BEAM guard. So *"this order has at least one line"* is `when length(lines) > 0` and lives in the
  type; *"this email address is well-formed"* is O(n), is not user-declarable, and still has
  nowhere to live. What remains is therefore narrower than the patch was written for — it is only
  about the **non-guard-expressible** invariants, and ticket 22 inherits that narrowing.
  **Amended 2026-08-13 by ticket 29's amendment B**: the non-guard-expressible invariant *is* now
  user-declarable as an opaque refinement — just not in a clause head or a foreign declaration. So
  this patch narrows again: what still has nowhere to live is only the invariant a user wants
  enforced **at the boundary**, which is exactly where the placement rule bars it.
- **How a user-declared opaque refinement is actually checked** — new with
  [ticket 29](issues/29-refinement-type-prior-art.md)'s amendment B, recorded in full on
  [ticket 20 §5](issues/20-untheorised-term-shapes.md). Three owed items: **whether the compiler may
  emit a call to arbitrary user code at a boundary** (Ada does, invisibly, at parameter passing —
  and it interacts with ticket 18's rule that generated code is exactly where a guard is emitted
  unconditionally); **a spelling for the check site**, since beam-sharp has no subtype-conversion
  site to hang one on, and SPARK puts the obligation at the *conversion in the caller* rather than
  on the callee, so whatever site is chosen governs the proof obligation and not merely the runtime
  check; and **what happens when the predicate raises** — ticket 15's `result<T, E>` the obvious
  answer, Ada's `Predicate_Failure` the worked precedent. The first is sharp enough to ticket on its
  own. It is left as fog because the *site* has no answer until
  [ticket 26](issues/26-data-modelling.md) settles how a named type carrying a `where` clause is
  spelled and what it erases to — an inference, not an established dependency — and deciding item 1
  alone would fix the visible half of a rule whose invisible half is still open.
- **Stdlib shape as a principle** — Erlang-ish flat modules, C#-ish namespaced statics, or
  Gleam-ish. Breadth is out of scope; the shape is not. **The prelude now has known contents**
  from ticket 10 — `type bool = true | false;`, `type option<T> = T | :nothing;`,
  `ParseAtom<T>` and `ToExistingAtom` — which makes "what is in the prelude versus a module you
  import" a live sub-question rather than a hypothetical one. **Ticket 11 adds `ValidateAs<T>`**,
  and with it a sharper version of the question: `ParseAtom<T>` and `ValidateAs<T>` are
  compiler-generated rather than written, so the prelude is not only a set of definitions but a
  set of **codegen obligations** — and where those are documented, and whether a user can extend
  them, is unanswered. **Ticket 14 §6 answers half of this and sharpens the rest.** Answered: the
  prelude has **two strata**, modelled on Elixir's `Kernel.SpecialForms` — ordinary aliases a user
  could have written (`bool`, `option<T>`) versus a **compiler-known** stratum they could not
  (`ParseAtom<T>`, `ToExistingAtom`, `ValidateAs<T>`, and now OTP's `Down`/`Exit`/`Timeout`), which
  wins resolution and which the compiler draws inferences from. ~~Still open: **whether a user can
  add to the second stratum**~~ — ~~**ANSWERED 2026-08-13 by ticket 20 §5: no.** A user may declare a
  refinement whose predicate is a BEAM guard, and may not declare one that is O(n); the second
  stratum is compiler-known, and 11's refusal of unbounded work *"whose size a foreign sender
  chooses"* is the reason, applied at a second site.~~ **REOPENED the same day**, and sharper than
  before: ticket 20 §5's amendment permits users to declare **opaque** refinements after all
  (barred only from clause heads and foreign declarations), so the justification for the "no" is
  gone. A user-declared opaque refinement is something the compiler **generates a check for** —
  which is the property ticket 15's surviving criterion for stratum 2 turns on — while plainly not
  being in the prelude. **So the question is no longer "may a user add to stratum 2" but whether
  *prelude membership* and *compiler-generated* are the same thing at all**, given they have just
  been shown to come apart. Still open too: how the two strata are documented
  differently, and what "in the prelude versus in a module you import" means once the answer is a
  compiler guarantee rather than a definition. **Ticket 20 also adds `string` to stratum 2** and with
  it a fourth candidate criterion, since `string` is a *type* whose membership is established by
  *generated code* — it satisfies 15's "the compiler draws inferences from it" and 16's ground-type
  test alike, so it does not discriminate between the surviving candidates, but any criterion
  proposed from here must admit it. **Ticket 27 moves the boundary.** With real type variables, `List.Map` and friends
  are now definitions **a user could have written**, which is stratum 1's own test — so the
  collection library drops out of the compiler-known stratum and the question becomes narrower and
  sharper: stratum 2 now holds only the *codegen obligations* (`ParseAtom<T>`, `ToExistingAtom`,
  `ValidateAs<T>`) and OTP's system-message shapes. 27 also gives stratum 2 its first hard rule —
  **a codegen obligation requires a ground type argument** — which is a property no stratum-1
  definition has, and is therefore a candidate for what actually distinguishes the two strata,
  rather than "could a user have written it". **One concrete obligation is owed here, not just a
  question**: ticket 15 §1 rejects `atom | :nothing`, so **`ToExistingAtom` must be respelled** —
  a tagged failure member, or a success type narrower than the atom top. Left as a spec-drafting
  detail rather than a ticket because it is one prelude signature with two known-good answers, but
  it is *owed*, and it lives here rather than only as a correction on closed ticket 10.
  **Ticket 15 populates both strata further and adds a wrinkle**: `result<T, E>` joins stratum 1 (an ordinary parametric alias), `foreign_error` joins
  stratum 2 — but `foreign_error` is *not* a codegen obligation and takes no type argument, so it
  fails 27's candidate criterion while still belonging to the compiler-known stratum. **So the
  distinguishing property is neither "could a user have written it" nor "requires a ground type
  argument"**; the open question is sharper than either. A third candidate: stratum 2 is what the
  compiler *draws inferences from*, whether or not it generates it. **Ticket 16 narrows this by
  one.** Its §4 adds a *fifth* codegen obligation — a serialisation encoder generated against a
  language-published mapping — which satisfies **both** 27's candidate (it requires a ground type
  argument) **and** 15's third (the compiler draws inferences from it). Since `foreign_error`
  satisfies only the third, **15's candidate survives a second test and 27's does not**. Still not
  a settled criterion, but the field is down to one live answer. 16 also leaves one *named* debt
  here beyond `ToExistingAtom`'s respelling: what the published serialisation mapping says about
  the shapes ticket 20 calls untheorised — binaries and bitstrings above all, since 25 puts three
  of six ordinary workloads there. **Ticket 17 adds a third candidate criterion, and it is the
  first that is observable in the output**: stratum 2 is **what the compiler inlines**. 17 §2
  established that emitted precision is a privilege of inlining — a compiler-known `List.Map`
  recovers `[integer()] -> [binary()]` where an identical user-written generic emits `[any()]` — so
  the two strata are not merely documented differently, they **produce measurably different emitted
  types**. Unlike 27's criterion (which `foreign_error` fails) and 15's (a claim about the
  compiler's inferences), this one can be checked by reading the `.beam`. Whether it *coincides*
  with 15's surviving criterion or cuts across it is unexamined: `foreign_error` is a type, not an
  operation, so it has nothing to inline and the test may simply not apply to it — which would mean
  the criterion is well-formed only for the stratum's *operations*, and the stratum's *types* need a
  separate one.
- **Consuming Gleam and Elixir libraries** — possible, and at what ergonomic cost. **Sharper
  after ticket 10 §7**, which measured Gleam's representation rather than reading it: fieldless
  variants are bare atoms, variants with fields are tagged tuples, PascalCase becomes
  snake_case, `Nil` is the atom `nil` and `Result` is `{ok, _} | {error, _}`. So a Gleam type is
  already a structural shape beam-sharp can write directly — the ergonomic cost looks low, and
  the open part is what happens to Gleam's *nominal* intent when beam-sharp has no nominality to
  receive it.
- **Laziness and `stream<T>`** — new with ticket 17 §5, and **deferred rather than refused**
  (David: *"defer lazy, we will want it"*). Nothing is lazy today: 17's fusion measurement showed
  the intermediate-list argument is already answered by the lowering, at no cost in precision. What
  the deferred option needs, recorded so it is not rediscovered: **compiler-known status in the
  prelude's second stratum with a fused lowering of its own** — without it, `xs |> Stream.Map(f)` is
  an ordinary user-level generic and degrades to `[any()]` under §2's two-tier rule, which is the
  worst outcome (it works, and is opaque); **an answer to how a lazy source meets ticket 14's
  process model**, since a stream over a mailbox or a socket is a process rather than a data
  structure, with different failure semantics; and **a position on early termination**, the one case
  fusion does not cover — `|> List.First()` after a map over a million rows still traverses a
  million rows. Cheap to add *because* 17 §1 chose qualified names: `Stream.Map` is a new module and
  nothing existing changes.
- **`cond`, or whatever serves a long ladder of unrelated conditions** — new with ticket 17 §6,
  which made `switch` the only branching construct and takes a **tuple subject** for compound
  conditions. That is clean at two or three conditions and clumsy at five, where
  `(a, b, c, d, e) switch` is hard to read even with `_` absorbing the tail. Deliberately not paid
  for with a keyword until the shape is shown to occur: **ticket 25 owes a report on whether the six
  exemplars produce it.** Adding `cond` later is purely additive, and its catch-all would be a
  clause (`_ =>`), never an `else` — 17c measured that `else` is an `if`-only keyword on this
  platform and both Elixir pattern constructs reject it.

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
