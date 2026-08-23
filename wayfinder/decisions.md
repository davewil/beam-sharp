# Decisions so far — the bodies

> **Split out of [`map.md`](map.md) on 2026-08-15**, which had reached 1,564 lines while its own
> comment promised *"one line per closed ticket"*. The split was verified to reconstruct the
> original byte-for-byte; **nothing here was edited, only moved**. `map.md` carries the index —
> headline, ticket number and topic tags per entry — and this file carries the bodies.
>
> One entry per closed ticket. The ticket itself, in `issues/`, is still where the full reasoning lives; these entries are the cross-ticket view of it.

## Decisions so far

<!-- one line per closed ticket: enough to judge relevance, then open the ticket for detail -->

- [Charting: differentiator, typing stance, scope](issues/00-charting-decisions.md) — the
  language exists for the multi-clause heads Gleam explicitly refuses; typing is
  static-by-default set-theoretic with enforced cross-clause exhaustiveness; tooling,
  stdlib breadth, macros and alternative backends are out of scope. **Audited 2026-08-15 — all
  four are boundaries on *this map*, and none is a refusal: three wait on a use case, and
  alternative runtimes/backends wait on traction and a request. See Out of scope, which now says
  which is which and what a requester inherits.**
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

- [What the language owes an agent that writes it](issues/23-what-the-language-owes-an-agent.md) —
  **the ticket's premise was wrong in the language's favour**: the platform already has three
  diagnostic channels and beam-sharp inherits all of them, measured in
  [`23a`](prototypes/23a_otp_diagnostic_channels.sh) — `compile:file/2`'s
  `{Location, Module, Descriptor}` with prose derived by `format_error/1`, the `abstract_code`
  chunk carrying the emitted forms verbatim, and `error_info` carrying a structured `cause` at
  runtime since OTP 24. **So Elm's port failure was never inevitable.** What *is* attested is the
  failure mode: **`erlc` publishes none of its own structured form** — no flag recovers it — so the
  platform builds the value and destroys it exactly where the consumer stands. **The term is the
  diagnostic and the prose is a pure function of it**, published at the CLI, with JSON as a second
  encoding reusing 16 §4's owed serialisation mapping (`json` ships in stdlib and **refuses
  tuples**, which is what these diagnostics are made of). **The compiler synthesises the clause
  head and never the body** — a head is derived from the residual and cannot be wrong, a body is a
  guess — and **where the residual is not guard-expressible it says so and offers nothing**, which
  is exactly ticket 20's opaque tier. **Only a named subset is contractual** (`inexhaustive`,
  `defended`, `unreachable_clause`), the test being *does it hand the agent something to write*;
  payloads are **maps not tuples** so additive change cannot break a matcher. That is narrower than
  OTP, which documents the envelope and leaves the descriptor opaque — a position that works for
  `{unbound_var,'Y'}` and fails for a residual. **18's boundary question is answered on that same
  channel**, its objection dissolved rather than overruled. **A stub is legal**: its residual is the
  whole declared type, so refusing to compile withholds the most informative diagnostic the language
  has, and `no_clauses` stops being a special case. **The generator smuggles in no crash policy**,
  and emits a *named* stub type rather than `term` because a `term` return decays invisibly.
  **Blast radius is complete within the compilation unit** — free, because 13 made the directory the
  module — and silent beyond it. Two rules did work here rather than decorating: `error_info` is
  attached **only to compiler-generated code**, because that is where a reviewer has no source
  (11's counterweight, answered), and *read cost keeps full weight* **changed an answer** — three
  markers per scaffolded operation became one, with the compiler enumerating the holes, since an
  unwritten clause is a residual it can compute. One line of skeleton prose was cut in the session
  as a worked instance: *"the residual is the clause you must write"* narrated the mechanism where
  the two lines above it stated the fact. **Scope clarification, general (David)**: the map's
  out-of-scope *tooling* entry rules out the **ecosystem track**, not any capability that happens to
  serve tooling — a `bsc --api` query mode is in.

- [The testing story](issues/24-testing-story.md) — **exhaustiveness converts coverage tests into
  value tests; it does not reduce their number**, because 23's clause synthesis adds guessed bodies
  at the same rate it removes coverage questions. Four categories genuinely retire, and 27 §2's is
  the one to notice: opaque type variables make **one ground instantiation evidence about all of
  them**. The unit is the **client API against a running process** — the OTP callback is the most
  compiler-owned function in the language, so testing it directly tests the compiler — and the
  boundary is **published by `bsc --api` with the behaviour contract as discriminator**, needing no
  visibility feature and so not waiting on 22. **Ticket 04's "sampled counter-value" is retracted**:
  measured, every CDuce sample is a *type*, never an inhabitant, so no generator is inherited and
  the language publishes the residual instead — 09's contractivity turns out to be what would make
  one terminate. Measured too: `sys:get_state` buys **no** determinism a client-API call does not,
  and a cross-process cast passes 200/200 on scheduling bias, flipping to 0/200 with a 20 ms head
  start — hence *every async operation owes a synchronous observation in the same client API*.
  §2, §5 and the compiler's published **elisions** consolidate into one **boundary manifest**.
  Tests are ordinary beam-sharp, no exemption. Closes 14's catch-all question with a **no**: cause
  the real event and the boundary test catches a mis-shaped clause.

- [Data modelling: records, and what named types erase to](issues/26-data-modelling.md) — **a record
  erases to a map, and `record` is sugar for a minted tag — but everything stays structural.**
  `type X = { ... }` remains the alias ticket 09 settled; a second form desugars to a `type` whose
  field set carries a discriminating tag minted from the type's *qualified* name. **The name enters
  the term, as data, never the type algebra** — the test that proves it is not nominality is that a
  hand-written `type` with the same tag *is* the same type, which is also why codegen (15's
  `ValidationError`, 18's foreign declarations, `ValidateAs<T>`) needs no privileged constructor.
  **This amends 09's inventory and not its reasoning**: union closure, negation, the boundary and
  exhaustiveness all survive, where real nominality would have cost all four. **David forced it on
  DDD identity** — under 09 as written, `Order` and `Invoice` over identical fields are one type, so
  `Update(Order o)` accepts an `Invoice` and `Order | Invoice` is not a union of two things; a
  hand-written tag fixes that but is *omittable*, and an omitted tag unifies two aggregates in
  silence. **Elixir is measured into this position rather than cited**: `Module.Types.Descr` types a
  struct as an **open map over an atom singleton** with no nominal construct anywhere, identical
  fields with different tags come back disjoint, and struct exactness is a compile-time courtesy the
  term model does not carry (`Map.put` widens one and it still satisfies `is_struct/2`). **The number
  ticket 18 asserted is now measured and lands the good way**: the map discriminator is +29 B against
  the tuple's +13 B, but a *tagged* map is **+14 B and flat in field count**, because `map_get/2`
  fails a guard silently on an absent key — so **the DDD requirement and the cheapest possible
  boundary guard want the same thing**. Guard content follows 18's own rule with no new one: tag test
  always, presence and value tests per 18 §1, exact-set test only where a codegen obligation consumes
  the record. Surface: **`with` alone, spread refused** — spread's defining capability is widening,
  which 27 §7 closed, and a non-widening spread is `with` with a second spelling, so **27 §7's debt
  is paid rather than reopened**; **construction names the type** (`Order { Id = "A-1" }`),
  target-typing refused on read cost; **the separator is `=` where declarations and patterns use
  `:`** — C#'s own split, forced independently because `Status: :placed` puts two colons adjacent;
  **the dot projects**, disambiguated *lexically* by casing rather than by type (`o.Status` vs
  `List.Map`), legal over a union where every member carries the field and **free there only because
  §1 chose maps** — a tuple erasure would have needed real dispatch. **No absent fields**: every
  declared field is always present, optionality is `option<T>`, and `?` is refused because *k*
  optional fields denote **2^k shapes** for a guard 18 emits everywhere — with the modelling
  consequence being the point, since an optional field is usually two record types wearing one name
  and §1 just made that cheap. Sharpest downstream consequence: **ticket 25 is unblocked in
  practice**, four of its six exemplars having waited on exactly these constructs.

- [Angle brackets versus less-than](issues/28-generic-bracket-parsing.md) — **the second bullet
  collapsed the ticket, and its own motivating premise is measured false.** Explicit instantiation
  *is* needed, on **exactly three names** — `ValidateAs`, `ParseAtom`, `ToExistingAtom` — because a
  codegen obligation's type argument appears **only in the return type**, which is the one thing
  matching cannot recover. Everywhere else instantiation is recoverable, so **user code never writes
  a type argument**, and the rule is one line: **`<` opens a bracket after a compiler-known
  codegen-obligation name and is comparison everywhere else** — a *lexer* rule on a closed set, with
  no lookahead, no backtracking and no turbofish. That forces the rule 27 implied and never wrote:
  **every type variable in a user signature must appear in at least one parameter position**, which
  is the condition under which *"matching, not solving"* is a true sentence. **C#'s rule was
  measured, not cited** (dotnet 9.0.306): a follow-token test that is correct in both directions —
  `CS0019` for a bare identifier after `>`, `CS0118` for `(` — and it is **not LALR(1)-expressible**,
  since the decision point sits after an unbounded suffix while `yecc` must commit at the `<`. So
  this is a **tier-3 divergence with a stated reason**, and it is unobservable: the two rules agree
  on the case that occurs and differ only on a form beam-sharp cannot express. **Guards are exempt
  and the exemption falls out rather than being written** — 08 and 11 between them keep every type
  out of a guard, so nothing is there for a bracket to attach to. Two things the platform had
  already given free, neither chosen for this purpose: **`a < b > c` is a syntax error today**
  (`Nonassoc 300`, in the skeleton's operator table for readability), which removes the C++ chained
  case entirely; and **no `>>` operator exists**, so `list<list<int>>` parses — though ticket 20's
  binary grammar needs `>>` as a *delimiter*, so that half is **owed a re-check when binaries land**.
  The loose end is closed: **`[h, ..t]` adopted in both pattern and construction position**, tier-1 C#
  collection expressions, and free against ticket 26's projection dot outright. Against float
  literals it is **earned rather than free**: **`1..5` lexes as `1 .. 5` and not `1.` `.5`** *because*
  the float rule demands digits on both sides of its dot — the skeleton has no float literal at all,
  so this is a **constraint `..` imposes on whoever settles them** (Erlang draws the same line, so it
  is cheap), and `..` staying unclaimed as a range spelling for 20's intervals rides on it.
  Sharpest downstream consequence:
  **27's stratum-2 rule gains a second job** — *"a codegen obligation requires a ground type
  argument"* was a typing rule and is now **the parser's disambiguator**, so the compiler-known set is
  load-bearing in the grammar, and **stratum 2's membership is fixed at lex time**.
  **Built 2026-08-14 as [F6](../compiler/features/F6-angle-brackets.md)** — the *type-position* half
  only, 124 tests up from 109. `result<T, E>`, `option<T>`, nesting, and user-declared
  `type Pair<T>`, all by **substitution**: the variable is gone before the algebra sees it, so the
  bracket added no node to `bs_types` and nothing to the emitted code. **The value-position rule was
  not written and did not need to be** — with `ValidateAs`/`ParseAtom`/`ToExistingAtom` unbuilt the
  closed set is *empty*, so `<` is comparison unconditionally, and F6 pins that against the **real**
  grammar where 28a measured a patched copy. `list<list<int>>` now has a test, which is where the
  owed `>>` re-check will trip. Ticket 27's §(c) — polymorphic function *signatures*, which are
  **matching and not substitution** — was cut on the ticket's own *"the costs are asymmetric and
  they do not chain"*, with three measurements behind it (`Map` needs an arrow type the algebra
  lacks; no exemplar declares one; matching a variable **inside a union** is undecided)
  → [ticket 37](issues/37-instantiation-by-matching.md). **The hazard F6 found was not a rejection,
  it was a hang**: a cyclic alias did not error on master, it spun — invisible to a green suite, and
  reachable for the first time because a parameter is what makes `type Tree<T>` natural to write.
  Guarded, and the control is a stopwatch (0.093s versus no output at all) because a test that never
  returns is not a failing test.

- [The FFI surface](issues/32-ffi-surface.md) — **a foreign function is declared, and the
  declaration carries both spellings.** Settled by David reading the three shapes written out as
  ordinary code ([`32e`](prototypes/32e-ffi-on-the-page.md)) — *"A clearly reads better"* — which is
  **the standing constraint reaching its own conclusion**: declaring up front is write cost, priced
  near-free, and narrowing a `term` at each use is read cost, which carries full weight. Elixir's
  zero-ceremony shape loses on a cost that is **regressive**, nearly free on values you were going to
  validate anyway and most annoying on `system_time`/`byte_size`/`length`. The answer was derivable
  before any measurement and nobody derived it. **The declaration binds the module**
  (`[external: erlang, "ets"] module Ets { list<term> Lookup(atom, term); }` → `Ets.Lookup(t, k)`),
  which is *not* per-module import — each function keeps its own signature and its single arity;
  only the name binding is per module, and that is the part with no arity to select. **Fork 1
  dissolved rather than being decided**: this shares its grammar with 23 §7's stub and nothing else,
  because the markers mean opposites — a stub is *unfinished* and **must** trip a release-gate text
  search, a foreign declaration is *finished elsewhere* and must not — so **32 decides no part of
  deferred ticket 22**. **There is no snake_case⇄PascalCase rule anywhere in the language**, and
  [`32b`](prototypes/32b_name_census.md) stands as the evidence for why not rather than the input to
  one: a mapping reaches 1,920 of 1,924 stdlib+kernel names but cannot spell `'PKCS-1'`,
  `'OTP-PKIX'` or a quarter of Elixir's function names (`fetch!`, `valid?`, `&&&`) under any rule.
  **Exactly one arity per declaration** — measured, 45 of 756 multi-arity stdlib pairs have **gaps**
  (`inet_udp:send/2,4` with no `/3`), so a foreign arity family is not 08's contiguous generated
  ladder and cannot be described as it. **A third shape died on contact with the page, not with a
  measurement**: C#'s identity-by-default needs a lowercase name, which 26's casing rule lexes as a
  field projection. **The lowering is decided too, because §2 made the declaration a named thing with
  a signature** — a real emitted function carrying 15's `try` and 18's guard, measured at **~60 bytes
  once, flat, against ~65 bytes per call site if inlined** ([`32d`](prototypes/32d_where_boundary_code_lives.md),
  43× apart at 40 call sites). **Gleam emits a wrapper where the *module's API* needs one and never
  where the boundary does** — a public external never called still gets a function and a `-spec`; a
  private one that *is* called is erased ([`32a`](prototypes/32a_gleam_external.md)) — affordable only
  because it checks nothing. So: **borrow Gleam's syntax, refuse its semantics (18), refuse its
  lowering (here).** **A correction the ticket owes the spec**: it framed unchecked FFI as Gleam's
  flaw against a clean C# borrow, and measured, **`extern` is unchecked too** — two C# names over one
  symbol with different declared return types both ran ([`32c`](prototypes/32c_csharp_foreign_declaration.md))
  — so 18's guard diverges from **both** audiences, compensated by the fact that beam-sharp emits the
  `-spec` Gleam emits and **unlike Gleam's it is not a lie**. Sharpest downstream consequence:
  **bootstrapping axis (b) is closed and (c) is unblocked** — but `use GenServer` can never cross,
  because Elixir exports macros as `MACRO-`-prefixed functions that are not callable from another
  language.

- **AMENDMENT 2026-08-14 to [ticket 16](issues/16-ad-hoc-polymorphism.md) — one of its two reasons
  for refusing protocols was invalidated by ticket 26 and nobody went back.** David, stating 26's
  intent: *"Exactly records, that's why they were introduced alongside `type` — for protocol
  dispatch."* 16 refused protocols because **dispatch cannot key on a name that is not in the term**
  (09 §5) *and* because open extension needs whole-program consolidation (13). **26 §1 put the name
  in the term** — a minted tag, as data — so the first reason is gone and only the second stands.
  **The refusal narrows from "no protocols" to "no *open* protocols".** What 16 wrote up as "bucket 2
  with ceremony" — a union parameter with a clause each — **is** protocol dispatch once the tag is in
  the term, checked exhaustive at the definition, and needs no construct because the language's
  headline feature already is the dispatch construct. What remains refused is a second aggregate
  adding a case without editing the first, which is **13's constraint, so 13 is the ticket that would
  have to give**. 16's headline survives and reads stronger: the capability arrives *without* an
  ad-hoc polymorphism construct. Note for the record — **26 was not a data-modelling decision that
  happened to help here; records were introduced for this**, and 26's own entry does not say so.

- [Local bindings](issues/34-local-bindings.md) — **the language has them, and their absence was an
  accident rather than a position.** Raised and resolved 2026-08-14 by David typing
  `o = Order{Id = 1, Total = 500}` at the REPL one minute after records shipped. Twenty-four tickets
  had settled the type system, the error model, dispatch, pipelines and records **without anyone
  writing down whether you can name a value** — a grep for it across every ticket, this map and
  `CONTEXT.md` returned nothing. A body is now **zero or more bindings followed by one expression**,
  so a body is still an expression with names in front of it; **bindings do not shadow**, since
  there is no mutation to assign with and 08's *narrowing is always written* extends to names.
  **The methodological lesson is the part worth keeping**: this ticket's headline evidence was
  *"zero binding-shaped lines across 25a and 25c"*, which measures **nobody trying, not nobody
  wanting** — those exemplars were written by agents inside a language that had no bindings. *A
  measurement taken inside a constraint cannot test the constraint*, and the map should treat
  exemplar silence as weak evidence wherever the exemplars were written by the same process that
  set the constraint. Two smaller corrections, both recorded on the ticket: the lowering was
  claimed to need a `case`/`begin` block and needs **neither** — an Erlang clause body is already a
  sequence and `{match, …}` an ordinary form, so the body stays a flat list and the last expression
  stays in **tail position**. **Destructuring binds are deferred to
  [ticket 33](issues/33-body-check-site.md), not refused** — `(a, b) = pair` can fail, which is a
  branch exhaustiveness never sees, and the map already has the machinery to make it *provably
  irrefutable* (`subtract(TypeOfExpr, TypeOfPattern)` empty) as soon as a body is typed. **That is
  the second capability 33 gates**, after F3's three. Sharpest downstream consequence: a scope pass
  now **walks a body**, and the line against 33 must stay sharp — **33 is about whether a body is
  *typed***, and rebinding, shadowing and unbound-name checks ask no type question at all.

- [The body check site](issues/33-body-check-site.md) — **a body is typed; synthesis is total and
  there was never a cheaper option; checking is containment at five sites; and the residual
  survives at four of them.** Resolved 2026-08-14, three hours after being raised, and **two of its
  own premises had already gone stale in that time** — F4's scope pass made *"`bs_check` never
  visits a function body"* false at 16:12, and the Question's expression inventory was short by
  eight forms. **That is the map's third stale premise**, after the walking skeleton's *"cannot be
  phrased sharply"* and the boundary manifest's *"no exemplars exist"*, and all three were **raised
  before a build and read after one**; the rule extracted is that re-measuring a feature-raised
  ticket's Question is the *first* step of resolving it. **The ticket's cheap/general fork
  dissolves**: checking a call argument requires typing an arbitrary expression, because the
  argument position is not a smaller grammar — so the "cheap" option is eleven-twelfths of the
  general one with a different name. What the fork was really hiding is a split the ticket never
  made: **synthesis** (every expression gets a type — total, twelve clauses, every non-structural
  one reading a type another file *declared*, which is 04's mandatory signature paying for a second
  thing) versus **obligation** (where containment is checked). The obligation sites are the
  enumeration of the places this language writes a type down: **call argument, construction,
  projection, clause return, destructuring bind** — five, with no sixth because `e_op`, `e_tuple`,
  `e_list` and `e_block` declare nothing. Two of those were not in the ticket's table: **the return
  check is forced by 18's own criticism of Gleam** (13 emits a `-spec` for every function, and
  without it beam-sharp publishes an unverified claim from its own bodies exactly as Gleam does
  from its FFI), and **site 5 is 34's deferred destructuring bind**. **Sub-question 3 was settled by
  running the algebra rather than by argument, and its assumption was wrong**: `subtract/2` +
  `to_pattern/1` — the two functions that already print 04's residual — return
  `{ Kind: :'Shop.Invoice' }` at a call site and `{ Kind: :'Shop.Note' }` at a projection, so **the
  call-site residual is the clause the caller must write** and **the projection residual is
  literally the member lacking the field**, which is F3.8's deferred sentence needing no machinery.
  So 23's cost never falls due and the language gains no empty-handed diagnostic. **Construction is
  the one exception and is recorded as one**: two closed maps over different key sets are disjoint,
  so the residual names the type you were building rather than the field you forgot — containment
  still catches it in both directions (measured: neither a short record nor a wide one is a
  subtype), and the diagnostic takes a **field-name difference** instead. **The finding a builder
  must not get backwards**: a body variable's type is read off the clause's refined domain at the
  path `pattern_type/3` already records, *not* off its pattern — a bare `p_var` is `term`, so
  without the intersection every argument fails every call site — and it must intersect
  **`Possible`, never `Certain`**, since an untranslatable guard makes `Certain` `none` and would
  type a running body's variable as a value that cannot exist. `walk/5` already computes that
  domain (running residual ∩ `Possible`) and discards it, so **the body check is not a second pass
  and an earlier clause narrows a later body for free** — 08's *narrowing is always written* falling
  out with nothing written. **Measured, because the two halves of that intersection do the work in
  different clauses**: over `F(0) -> …` / `F(n) -> …`, clause 1's body gets `(0)` from the *pattern*
  and clause 2's gets `(int <= -1 | int >= 1)` from the *residual*, where intersecting the declared
  type with the pattern alone leaves clause 2 a bare `(int)`. **Ticket 32 dissolved sub-question 2 exactly as predicted** (a foreign
  callee has a declared signature; how far it is trusted was decided by 18 §2), leaving one
  mechanical delta: `collect/1` excludes foreign declarations by design, and a callee environment
  needs both kinds. **Sub-question 4 answers *nothing changes in the emitted code*** — 18's guards
  sit at entries, the analysis is function-local (18 §4), and 21 rules out ruling out a foreign
  caller, so no proof about a body discharges an obligation about a caller; 18's *elision is
  exported-vs-local* closes the last route. **This is therefore the first checking capability in
  the language that is purely a frontend concern**, where every previous one arrived as a codegen
  obligation. Nothing new is needed in `bs_types`. **BUILT the same day as
  [F5](../compiler/features/F5-body-check-site.md)** — all five sites, 106 tests up from 79, and
  F3's three reserved scenarios now asserted rather than reserved. The delta held and the site
  enumeration was complete; **what the ticket could not have found is that a list element has no
  address**, so reading a body variable off the domain answers `term` for it and rejects
  `examples/fib.bs` — reverting that fix turns 7 of 106 tests red. Measuring *where a check runs*
  cannot surface a question about *whether the checker can address the value it is checking*, which
  is a different axis from the one this ticket was framed on. Both of §5's traps were confirmed by
  **mutating the source rather than by a green suite**: built with `Certain`, the compiler goes
  quieter rather than broken (1 test red), which is why the scenario has to assert an error a wrong
  build **omits**. F5 shipped one hole named rather than discovered — a field's assigned **value**
  is unchecked at construction and at `with` alike, because §2's relation is the field *set* and §1's
  principle says otherwise → [ticket 36](issues/36-field-value-obligations.md).

  **[Ticket 36](issues/36-field-value-obligations.md) closed that hole on 2026-08-21, and closed it
  without a sixth site.** The answer is **yes to both**, and the reason there is no asymmetry to
  weigh is that **site 2 is not "construction" — it is *field assignment***, of which `Order{ … }`
  and `o with { … }` are two spellings meeting **one** declaration. §2's closing sentence was never
  about `with`: its own justification clause enumerates the forms that declare nothing — `e_op`,
  `e_tuple`, `e_list`, `e_block` — and `e_with` is not among them, because `Total: int` is written
  in the record declaration and governs both spellings alike. The ticket's case for a sixth site
  rested on §1's `e_with` row (*"the base's type, unchanged"*), which is a **synthesis** row; using
  it to settle an obligation is precisely the conflation §1 was written to break. **So §2's closing
  sentence stands unamended and §2's site-2 *relation* widens**: supplied field set = declared field
  set, **and** each supplied value is contained in that field's declared type. **What the ticket got
  wrong is its own scope fence.** It forbade re-deriving the name half — *"F5 enforces it"* — and F5
  enforces it **at construction only**: `o with { Nope = 1 }` compiled clean, emitted Erlang's `:=`,
  and raised `{badkey,'Nope'}` at **run time**, so 26 §2's width-preservation was being delivered by
  the BEAM rather than by the compiler. Three defects, not two. **The strongest evidence was already
  in the emitted code**: `bsc` writes a `-spec` declaring the field type and a body violating it in
  the same file, and **Dialyzer names both halves with one verdict** — *"the return types do not
  overlap"* — which is 18's criticism of Gleam turned inward, the very argument §2 used to add site
  4. Gleam 1.18.1, measured rather than cited, rejects construction and update with two identical
  errors and draws no line between them. **One verdict this corrects rather than extends**: §3
  marked construction's residual *useless*, and that was the **name** residual; the **value**
  residual is `type_of(:oops) \ int` = `:oops`, precise beside a known field name — so the one site
  §3 recorded as unable to hand an agent anything writable can do so on its value arm, which
  strengthens 23. The delta grew in scope but not in kind — containment against `declared_fields/1`,
  **nothing new in `bs_types`** — and the name arm needs no new diagnostic, since
  `field_set_mismatch` already carries an `Extra` list whose prose reads *"not declared by Order"*;
  only its headline verb was wrong, because `with` updates rather than builds. Built as
  [F21](../compiler/features/F21-field-value-obligations.md).


- **Module and namespace system, and function identity** — [ticket 40](issues/40-module-and-namespace-system.md),
  resolved 2026-08-15. Three sections, and they were answered by three different kinds of argument,
  which is the reason this entry is worth reading rather than the ticket's headline.

  **§1 — the emitted atom was FORCED, not chosen.** A module's atom is its full dotted path
  (`module Shop.Orders` → `'Shop.Orders'`), because ticket 26 §1's tag mints from the qualified name
  and delivers aggregate identity *only if* `Mod` is itself unique — with a leaf name,
  `Shop.Orders.Order` and `Billing.Invoices.Order` both mint `'Orders.Order'` and two bounded
  contexts unify invisibly. **The compiler already implements it**: `bs_check:qualified/2` and the
  `bsc.erl` emit path need no change, because both were written against the module *atom* rather
  than a single segment, so §1 costs one grammar rule. Re-measured on OTP 28; `13a` had measured it
  already. **One correction is on the record**: the first reason given for needing no
  `Elixir.`-style prefix — *"PascalCase sits outside Erlang's snake_case namespace"* — is **false**,
  and `32b_name_census.md:30–35` had already measured it false (265 of 1,315 loadable Erlang modules
  are not plain lowercase). The surviving reason is narrower and is the one to quote: **none of them
  contains a dot.**

  **§2 — arity overloading is PERMITTED**, the BEAM's own rule unmodified (David: *"one arity per
  name seems a complete dead end"*). The argument for restricting it — ticket 34's *"a name means
  one thing in a clause"*, lifted to the module — is an **analogy, not a mechanism**, and was left
  unmade. `examples/fib.bs` writing `Fib`/`Series`/`Reverse` is idiom, not constraint.
  **The hazard cited against it had been mis-read, and correcting it moved it out of this ticket**:
  `01b:587–591` says `Fib/1`, `Fib/2` and `Fib/2` *again* — same name **and** same arity, which is a
  duplicate declaration under either answer and never an argument for one. Measured while
  correcting it: the checker **merges** two same-signature declarations into a single four-clause
  function and reports *"clause 3 is unreachable"*; the only thing that stops the build is `erlc`
  saying `function 'Combine'/2 already defined` against `Silent.abstr:0`, with no line and no `.bs`
  name. **The defect is the diagnosis, not the outcome** — the identical costume to F7's
  `true`/`false` bug, and the second appearance of that shape.

  **§3 — `public`/`private` on the signature**: Elixir's placement, C#'s words (David: *"Follow the
  beam convention for exports, elixir uses def/defp right?"*). Both BEAM languages make export an
  explicit per-function decision and differ only in *where* it is written; taking Elixir's site
  rather than Erlang's `-export` list avoids a second place that must agree with the definition,
  which is the drift `bs_emit`'s single `name/2` funnel exists to prevent. Taking C#'s words is the
  amended heuristic working as intended — survey all three tiers, take the most accurate word — and
  it is the same shape as ticket 35's `behaviour`: mechanism from the BEAM, spelling from wherever
  it reads best. **AMENDED 2026-08-17 — an unmarked signature is PRIVATE**, and `public` deliberately
  exposes. The resolution had taken Elixir's *no unmarked case* and recorded it as a stated
  assumption with a one-line reversal named in advance; this is that reversal, and the reason is
  that **the original framing had already measured the case and the resolution went the other way**.
  C# defaults members to private, the BEAM defaults to unexported, TypeScript defaults to
  module-private — every tier-1 and tier-2 source defaults *closed*, so on this question all three
  tiers agree, which is as strong as the borrow heuristic ever gets. *No unmarked case* was the one
  convention with no second vote behind it. `private` stays legal and means what its absence already
  means, so no `.bs` file needed editing; the whole compiler cost was **deleting** the
  `missing_visibility` check, there being nothing left to miss.

  **Two checks are specified and unbuilt**, both belonging to the feature that implements §1:
  `{name_redeclared, Name, Arity, Line}` for §2, and — because ticket 06 measured that `-behaviour`
  has no runtime effect and **only exports matter** — an error when a `private` function is a
  callback of a declared behaviour, which F10's contract-scoped table already makes cheap. Without
  the second, a `private` callback breaks the behaviour at run time, silently.
  **Both are built** — `name_redeclared` by F11, `private_callback` by F12 (2026-08-17).

  **THIS ENTRY GAINED THE `syntax` TAG ON 2026-08-17, AND THE REASON OUTLIVES THE TICKET.** It was
  tagged `modules` `codegen`, and `check-surface.sh` selects on `syntax` or `patterns` — so the one
  decision that puts a keyword on **every signature in the language** was never asked for a
  `LANGUAGE.md` paragraph, and F12 could have rewritten all 32 `.bs` files with the reference silent
  and every gate green. That is precisely the class of drift the gate was written for, arriving
  through the tag rather than through the prose. **A gate that selects on tags is only as good as
  the tagging**, and a tag is applied when a decision is *made* — when nobody has yet built the
  thing that would show which surfaces it touches. Worth re-reading whenever a decision is tagged:
  the question is not *what is this decision about* but *would a reader of `LANGUAGE.md` see a
  difference*. Three sections here and only §3 changes the surface, which is exactly how a
  multi-section ticket comes to be tagged by its majority.

  **Not decided here**: where tests live (24), and everything about *naming another* module →
  [ticket 41](issues/41-imports-and-cross-module-scope.md).

  <details><summary>The patch as it stood before the ticket, preserved</summary>

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
  works unchanged. **Ticket 23 §10 adds a third consumer of the naming question, and it is the
  first that is not a build concern**: the directory listing is a legitimate way for an agent to
  discover what operations exist, so **file names are part of the API surface** rather than only of
  the build layout. That strengthens 23's own warning that colliding short names
  (`Order.Server.Apply` beside `Order.Apply`) are defects, and it means whatever this patch decides
  about emitted atoms has to be legible to a reader with nothing but `ls`.
  **Ticket 24 adds a fourth consumer, and it is the one that stresses the rule hardest**: where a
  *test* lives under one function per file. 23 §10 made the directory listing part of the API
  surface, so tests either sit in it — and an `ls` no longer shows only operations — or somewhere
  this patch has not defined. 24 declined to answer it as a tooling detail precisely because 23 §10
  says it is not one.
  **Ticket 26 adds a fifth consumer, and it is the first that is a correctness requirement rather
  than a discovery or build one.** 26 §1 mints a record's discriminating tag from its type name, and
  that tag *is* aggregate identity — so if the mint uses the **short** name, `Shop.Orders.Order` and
  `Billing.Invoices.Order` both produce `:order` and two bounded contexts silently unify, which is
  the exact failure the minting exists to prevent, at a different scale and invisible. **So the tag
  must mint from the qualified name**, and whatever atom this patch settles on must be unique enough
  to carry aggregate identity, not merely to avoid colliding with Erlang modules. This raises the
  stakes on the emitted-atom question rather than adding a new one: 13 already made it a
  build-layout question and 23 §10 an API-surface question; 26 makes it a *type* question.

  </details>

- **A span in a clause head is a relational pattern** — [ticket 42](issues/42-interval-pattern-spelling.md),
  resolved 2026-08-15. Raised by F2, which could not ship interval refinements without a way to name
  a span: once `type Octet = int where value >= 0 && value <= 255` lands, ticket 12 §2 turns every
  wire dispatch's residual from open to **closed**, and the `_` that used to discharge it becomes an
  error. So this was forced, not cosmetic.

  **The ticket asked the wrong question and measuring dissolved it.** It asked whether `4..7` should
  be inclusive (Elixir) or half-open (C#). Probed on dotnet 9.0.306
  ([`42a`](prototypes/42a_csharp_range_probe/Program.cs)): `a[4..7]` is `[4, 5, 6]`, the `Range`
  reports `.End = 7` with length 3, and `foreach (var v in 4..7)` **does not compile** —
  `CS1579: 'Range' does not contain a public definition for 'GetEnumerator'`. A `System.Range` is a
  slice specification over *indices*; `GetOffsetAndLength` needs a collection length before it means
  anything. It contains no integers, so "does it include 7" is a question the construct cannot
  answer. **C#'s numeric-span construct is the relational pattern**, inclusive at both ends — and in
  *pattern* position C#'s `..` already means "the rest" (`[var first, .. var rest]`), which is what
  28 §5 took and `fib.bs` runs today as `Reverse([x, ..rest], acc)`.

  **So `4..7` was never a tier-1 borrow — it was tier 3 wearing tier 1's clothes**, and taking it
  would have put one token on two unrelated jobs in the same position.

  **The heuristic gains a line, and this is the part that outlives the ticket:**

  > **Borrow the construct, or don't borrow the glyph.** Where C# has the symbol but not the
  > construct, taking the symbol buys no familiarity and costs a false friend.

  The condition is *not* "C# lacks this construct" — `|>` and `->` are absent from C# and confuse
  nobody — but **"C# has this glyph, meaning something adjacent"**. `as` (map Notes) was the first
  instance and was handled ad hoc; `..` is the second, which is enough of a pattern to make it a
  check before adopting a spelling rather than a discovery after. It also sharpens the map's own
  test: *reads on sight versus must be taught* cannot see this case, because `4..7` reads on sight
  and reads **wrong**. A glyph borrowed without its semantics converts "I must be taught this",
  paid once, into "I read this fluently and wrongly", never paid at all.

  **Compiler delta:** two keyword rules (`and` and `or` are *not* reserved today — measured in
  `src/bs_lexer.xrl`, where `&&`/`||` are tokens at lines 112–113 — so reserving them is a real
  lexer change that also removes both from the variable namespace); a relational pattern form; each
  relational lowers to an interval the algebra already carries, with `and` as intersection and `or`
  as union; the emitter is unchanged (`when N >= 4, N =< 7`). It **pays a debt** — F7 recorded
  `{ Total: > 100 }` as *"a C# relational pattern, which this grammar does not have"* — and it
  **improves ticket 23 §2**, whose measured complaint was the skeleton rendering `Classify(int <= -1)`
  where the real head was `Classify(n) when n <= -1`. An interval residual now synthesises as
  `Classify(<= -1)`: a pattern, with no binder and no guard, shorter than 23 anticipated.

  **28 §5's float-literal obligation is retained but is now unreachable.** `..` stays in the grammar
  for list rest, where it is always preceded by a comma, so no valid program juxtaposes an integer
  literal with it. Keep the both-sides-digits rule anyway — it matches Erlang and costs nothing.

  **What it opened.** The pattern combinator is `and`/`or`, taken with the construct; whether
  *guards* follow is [ticket 44](issues/44-conjunction-spelling.md), amending ticket 08 —
  David: *"For ticket 8, I think with more info, and/or would probably sit better"*. F2 loses one
  blocker and remains blocked on [ticket 43](issues/43-residual-summarised-form.md).

- **One conjunction: `and` / `or`** — [ticket 44](issues/44-conjunction-spelling.md), resolved
  2026-08-15, amending [ticket 08](issues/08-head-and-guard-syntax.md). Raised by ticket 42, which
  put relational patterns in the parameter position and took C#'s `and`/`or` combinators with them,
  leaving the language spelling conjunction two ways. David: *"For ticket 8, I think with more info,
  and/or would probably sit better."* **One spelling now, in every position — pattern, guard and
  refinement predicate — and `&&`/`||` are removed rather than kept as synonyms.**

  **Safe because measured, not argued.** The only thing that could have made `and` a false friend
  here is Erlang's own `and`, which does not short-circuit where `andalso` does. On OTP 28
  ([`44a`](prototypes/44a_guard_operator_probe.escript)), using `10 div X` with `X = 0` so the
  second operand genuinely raises: in **guard** context `,`, `and` and `andalso` all fell through
  identically, because a guard that raises simply fails — **non-short-circuit evaluation is
  unobservable there**. In expression context the difference is real (`and` raises `badarith`,
  `andalso` returns false). beam-sharp's guards are a restricted predicate set, so the only context
  it uses is the one where the question has no answer to get wrong.

  **This is ticket 42's new rule applied in the opposite direction, and that is why the entry is
  worth reading.** 42 minted *"borrow the construct, or don't borrow the glyph"* while **refusing**
  `4..7`. A rule that only ever forbids is a rule nobody can apply, so its second use being a
  **permission** matters more than its first being a refusal. The test is whether the glyph's
  meanings diverge: `..` diverged (a half-open slice over *indices* against a span of *values* — a
  reader who reads fluently reads wrong), and `and` does not (conjunction in C#, in Elixir, and
  observably in Erlang guards). That C# spells its expression conjunction `&&` and its pattern
  conjunction `and` is a fact about C#'s grammar, not about what `and` means. **The rule is about
  meaning, not position** — recorded because 42 alone could be misread as *"only use a C# symbol
  exactly where C# uses it"*, which would have forbidden this and been wrong.

  **And the reason to unify is beam-sharp's own.** C#'s split costs nothing there because patterns
  and expressions rarely touch. This language's defining move puts patterns in the *parameter*
  position, so a pattern and a guard sit on the **same line**, in the central construct, in every
  non-trivial function. The condition that makes C#'s split free is exactly the one beam-sharp does
  not satisfy.

  **Ticket 08's `as` answer survives, and was checked rather than assumed.** 08 made
  `(d as int) > 0` the answer to `dynamic` in a guard, reasoning that *"`&&` never changes
  meaning"*. The lifting that yields false on failure is on the **comparison** — it produces `false`
  before any conjunction sees it — so 08's sentence is a claim about the *absence* of special
  conjunction behaviour, and an absence survives a rename. 08's table row is amended; the row
  beneath it stands.

  **`&&`/`||` are removed rather than aliased**, on the standing constraint: write cost carries
  little weight, read cost carries full weight, and a reader meeting both spellings must ask whether
  the difference is meaningful — a question they should never have been made to ask. **Flagged in
  the ticket as the piece most worth overruling**, being the only part not forced by the reasoning.

  **No source changed, and it could not have.** `LANGUAGE.md` is gated bidirectionally and the
  compiler does not lex `and` today (`src/bs_lexer.xrl` carries `&&`/`||` at lines 112–113 and no
  `and`/`or` rule), so editing the doc before the lexer turns the gate red. Lexer first, then doc and
  example, in one change — F2's job, since 42 already obliges it to reserve the keywords. **44's own
  marginal lexer cost is therefore zero**, and it *removes* two rules, which is a rare direction of
  travel for a language decision.

- **A match against a bound value is `== name`** — [ticket 45](issues/45-match-token.md), resolved
  2026-08-16. Raised by F8, which makes `var` bind and a bare `=` match, and which therefore needs a
  spelling for the third case: a pattern that must match **the value a name already holds**. David
  settled the shape on 2026-08-15 — *mark the match, one token, and not `^`* — on frequency, since
  binding is the common case and you mark the rare one, and because `^` has been C#'s index-from-end
  operator since C# 8. **This ticket settled only the token, and settled it by measurement.**

  **The control is the part worth copying.** Eight grammar variants were generated and every one
  came back clean first time — which is precisely what a broken harness reports. So yecc was fed a
  grammar already known to be bad: F8 records `binding -> pattern '=' expr` at fifteen reduce/reduce
  with yecc refusing to generate, and [`45a`](prototypes/45a_match_token_probe.escript) reproduces
  **15**, to the number. Only after that does a clean result carry information. This is F6.9's rule
  pushed one step further back — that rule says assert by *parse* rather than by conflict count,
  because yecc resolves shift/reduce silently through the precedence table; the control adds *and do
  not believe the count is being reported until you have watched it report one.*

  **The cost is one grammar line and no lexer change at all**, which is the whole mechanism argument
  against the other five candidates. `==` has lexed since the walking skeleton and ticket 16 already
  fixed its meaning as `=:=`, so the glyph carries into pattern position with exactly the meaning it
  has everywhere else in the language. `$acc`, `~acc` and `&acc` each need a lexer rule for a
  character `bs_lexer.xrl` has none for; `same acc` needs a reserved word.

  **The space is not significant, and that owed item dissolved rather than resolving.** `==acc` and
  `== acc` are the same token stream, because `==` is a maximal-munch rule and an identifier cannot
  begin with it. Both parse; they are one program. House style is `== acc`, matching `>= 4` — a
  statement about how the corpus is written, not about what the grammar accepts, and enforceable
  only by a formatter that does not exist.

  **It parses in every position a pattern goes** — clause head, `switch` arm, list element, record
  field, tuple element — **and nested at arbitrary depth**, which strikes an item off F8's *Out of
  scope*: that file called `({ Kind: ==k }, x)` unmeasured. Depth was never a separate question,
  because `== name` is a `pattern` and `pattern` is already recursive through every compound form;
  it only looked like one while nobody had run it.

  **It does not parse to the left of a bare `=`, and that is right rather than a gap.** The left of
  a bind is an expression narrowed by `to_pattern/1`, and no expression starts with `==`. Nothing is
  lost: under F8 a bare `=` against a name in scope already *is* a match, so `acc = x` already means
  what `== acc` would. **A marker is owed only where the ambiguity is**, and `var` has removed it
  there.

  **What did NOT come free is the half of this entry most likely to be rediscovered as a bug.**
  Admitting `== name` does not admit `>= acc` (a span bounded by a **runtime** value), and does not
  make `== 4` a second spelling for the literal pattern `4`. Both were measured as refused by the
  proposed grammar — and both were then measured as **yecc-clean if deliberately added**. So each is
  *available and deliberately not taken*, which is a different claim from impossible. `>= acc` is a
  capability no ticket has decided and is not this one's to grant as a side effect of choosing a
  token; that would be exactly the silent surface drift `bin/check-surface.sh` exists to catch, and
  if wanted it is a ticket. `== 4` is refused on one-meaning-one-spelling. The family therefore
  reads: **relational operators take a literal, `==` takes a name.**

  **And the token buys back something the target never lost.** A bound variable in an Erlang pattern
  *is* a match, so `p_eqvar` lowers to the variable itself and emits no guard. beam-sharp needs a
  spelling only because it forbids rebinding and so cannot use Erlang's own rule — which is the same
  position Elixir is in, and the reason `^` exists there.

  **And the finding the ticket did not go looking for.** `src/bs_repl.erl:193–197` implements
  **pin-by-default** — a bare bound name in a pattern matches — under a comment stating *"the
  language needs no `^`: there is nothing to disambiguate."* Shipped 2026-08-15, the same day David
  settled the opposite shape. F8.8 already records that the prompt and the compiler disagree, but it
  does not say which side moves, and that comment says with confidence the question is moot. **45
  settles the direction: the marked rule wins and `bs_repl` is what changes**, by this ticket's own
  argument turned on itself — a bare name cannot *also* mean match, or `== name` is a second
  spelling for something already spelled, which is the exact ground `== 4` was refused on. What the
  unmarked form *does* mean in a head (a fresh bind, or an error) stays F8's and ticket 34's; 45
  asserts only that it is not a match. Worth recording because the misleading artefact is a
  confident comment in shipped source, and its next reader is whoever implements F8.

- **An inexhaustive residual truncates at three cases** — [ticket 43](issues/43-residual-summarised-form.md),
  resolved 2026-08-16. F2.4 asked what the compiler emits when 40 singleton clauses leave a residual
  of 41 disjoint intervals. The answer is that **the prose prints the exact residual with a stop in
  it** — three cases, then `... (K more)` — **and nothing else summarises**: not the term, not the
  synthesised head, and no complement is computed. Measured throughout by
  [`43a`](prototypes/43a_residual_at_width.escript), which drives the real `bsc` for what is printed
  and works in `bs_types` for the shapes that are functions of the residual term.

  **Two of the ticket's own premises were wrong, and the corrections are the whole answer.** Hole 1
  asserted that 41 intervals *"lower to 41 heads"*; measured, `bsc` prints **one** head of **453
  characters**, because `heads/2` in `compiler/src/bsc.erl` splits on the tuple part — one product
  per *argument position* — and a union of intervals lives inside a single argument. The 41-head
  claim describes [ticket 23](issues/23-what-the-language-owes-an-agent.md) §2's lowering, which is
  unbuilt. So Hole 1's *"there are two artefacts and F2.4 asked about one"* is a conditional, not a
  fact, and §3 of the answer gives both one rule anyway: **truncate at three of whatever the printer
  is enumerating** — intervals inside the one head today, head lines once §2 lowers.

  **Naming the unit per stage is the part that had to be got right, and the first draft got it
  wrong** — it said "three heads", which would truncate *nothing* today, because §0 had just
  established that today there is only one head. The correction is recorded rather than quietly
  fixed because it is the same failure in miniature that the ticket exists to correct: the rule was
  stated in the units of the premise that had already been measured false. After §2 the unit *must*
  become heads, since a residual over two arguments is a product and an interval rule would then
  print an unbounded number of lines.

  **The complement was refused on measurement, not on the finiteness argument the ticket expected.**
  Its aside — *"for an unbounded `int` the complement is not finite"* — is wrong: the complement of
  the residual is the **covered** set, finite whenever the clauses cover finitely much, which is
  25c's case exactly. It loses on size instead, and never wins: 22 chars against `exact`'s 20 when
  the singletons are contiguous, 245 against 432 when they are scattered, 25 against 11 and 237
  against 404 over a closed octet. **The residual and the covered set are long together** — a covered
  set dense enough to state as a short exclusion is one that made the residual coalesce, and a
  residual that sprawled did so because the covered set was scattered, which its own rendering then
  is. Hole 2's intuition that *"40 named singletons out of a bounded octet is small to state as an
  exclusion"* is measurably false in the case that raised the ticket.

  **The shape was chosen because it is not a second format.** At or under three cases it prints
  byte-identically to what the compiler prints today, so the *"why did the format change"* confusion
  Hole 3 raises cannot arise — there is nothing to switch into. Every rival candidate must switch,
  because each *replaces* the residual with a description of it and none can render a two-interval
  residual without being worse than the enumeration (49, 22 and 24 characters against 20, and none
  of them says what the missing case is). The decisive measurement is that **cardinality degenerates
  on the open residual**: over `int` the count is unbounded, so `bounds and count` reads
  `41 intervals spanning -inf..+inf, unbounded values` and cardinality-only reads
  `unbounded unnamed values`. A shape that says nothing on the open case cannot be the general one,
  and until F2 lands *every* residual is open.

  **The threshold's unit was measured rather than argued, and turned out not to matter.** Hole 3
  claimed the units disagree — *"three intervals over `int` render longer than twenty over
  `0..255`"*. They do not: 3 over `int` is 30 characters (60 with 19-digit bounds, built adversarially),
  20 over `0..255` is 100, and interval count and character length order every case identically. So
  character length is not load-bearing and the testable unit wins. **There is also no threshold in
  the tunable sense**: this takes Hole 3's *"no threshold at all"* option, and the truncated-exact
  shape is what makes it free, since always-on costs a small residual nothing. No flag, no switch.

  **One thing is defaulted rather than settled, and it is flagged as David's.** Ticket 12 §2 makes a
  catch-all an *error* over a **closed** residual, so after F2 an octet with 40 scattered clauses has
  41 clauses to write and no `_` available — the enumeration *is* the checklist, and truncating hides
  work. Default taken: **truncate anyway**, because the term keeps all 41, `bsc --api` (23 §10) is
  the full-fidelity channel, and printing in full for closed residuals reintroduces exactly the
  format switch this shape was chosen to avoid, keyed on something the reader cannot see. The delta
  if the other answer is wanted is one argument to `heads/2` — the checker already knows whether the
  residual is closed, because 12 §2 already tests it — and it changes nothing F2 builds, so **F2 is
  unblocked either way** and this flips later without a breaking change.

  **The compiler gains one truncation and nothing else.** `bs_types` gains nothing: every shape
  considered is a function of the residual it already produces, and the chosen one is the printer it
  already has. 23 §4's descriptor gains nothing, so this ticket freezes nothing new into the
  published contract.

- **Imports and cross-module scope** — [ticket 41](issues/41-imports-and-cross-module-scope.md),
  resolved 2026-08-16 across two sessions; §1, §2 and §5 on 08-15, §3 and §4 on 08-16. Raised
  alongside 40. **§1 is answered on mechanism**: `using` generalises rather than needing a second
  keyword, because the native and foreign forms differ in the *token class* of the left side
  (`uident` path vs `atom_lit`) — the same discriminator `LANGUAGE.md` §11 already uses for the
  three dot-forms — and because the FFI `using` **already introduces no B# name**, so a native one
  that also introduces none is the same construct rather than an overloaded one. It also answers
  23 §11 directly: a file's `using` lines are its dependency list.

  **§2: `using` brings names into scope UNQUALIFIED** (David: *"I think B would be expected"*). The
  audience test decided it — an import that leaves every call site qualified makes the `using` line
  look inert. The one mechanism objection — diagnostics emit pasteable source, so the printer must
  pick a spelling — **dissolves**: print fully qualified always, which is legal in any scope.
  Requires ambiguity and local-shadowing to be **errors printing qualified candidates**, and
  resolution by name *and* arity.

  **§5: a namespace is a directory holding no `.bs` files**; one holding `.bs` files is a module.
  Decidable by `ls`, no marker, no keyword. The earlier claim that B# *"has no room"* for C#'s middle
  tier was overstated — B# lacked a **name** for the case, not the case, since ticket 13 had already
  made a directory inside a module a source-only sub-module. It restores all three C# tiers with §2
  as the middle one and **costs nothing at runtime**: a namespace emits no atom, no beam, no
  attribute. One new check, with a precedent: a file's `module` declaration must match its directory
  path — 13's measured `erlc` atom/filename rule lifted from the artefact to the source tree.

  **§3 was the prerequisite, not a neighbour**, so §2 and §5 were answered-but-unverifiable for a
  day: neither unqualified names nor namespace resolution can be checked without knowing where the
  checker gets another module's types. **It is answered by re-checking the dependency's source, and
  the compiler owns the dependency graph** — and the section's own opening premise turned out to be
  **false**, which is what changed the price. *"The compiler is single-file"* is wrong: measured in
  [`41a`](prototypes/41a_multifile_probe.sh), `bsc Alpha.bs Beta.bs` exits 0 and emits **both**
  beams, because `compile_only/2` is already a map over a file list. What is single-file is the
  **environment**, not the invocation — so fork A needs the loop that already exists to carry an
  accumulator, not a new CLI, entry point or artefact. The isolation is also **clean and
  order-independent**: a file calling a function defined in another file of the same invocation is
  rejected identically in both argument orders, so there is no undocumented leakage to undo.

  **The build-tool option collapses rather than losing on preference.** An externally computed
  compile order buys nothing on its own, because a later invocation still starts with an empty
  environment and the `.beam` carries no B# types; to make an order useful the signatures must
  persist between invocations, and a persisted signature artefact **is fork B** — already disposed
  of twice (no source-less consumer exists; blocked on ticket 16 §4's serialisation mapping). So
  *"the build tool owns the graph"* is not a third option, it **reduces to B and inherits B's
  blocker**. Same shape as F10's collapse of ticket 35: check whether the alternative can be
  *completed* before weighing it. What is left for a build tool is stated so it is not the next
  unraised blocker — **the source root and the file set, never the order** — and it is recorded
  rather than ticketed, because nothing needs building that a file list cannot express yet.

  **§4: `index.bs` holds everything except functions**, and one-function-per-file has no exception.
  **The three exemplars had already answered it and nobody had looked** — all three `index.bs` files
  hold *zero* functions, only `using`, `type`, `record` and `behaviour`. The mechanism is
  `write_scope`: the standing constraint makes one function per file a bounded blast radius, and
  `index.bs` is the module's **contended** file by construction, since every new type, record and
  `using` line lands there. Permitting functions would merge the most-contended file with the one
  thing file-per-function exists to isolate, so two agents adding unrelated functions collide in a
  file *neither function is in*. The write-cost objection does not survive the standing constraint —
  ceremony is near-free, agents author these files — and read cost points the same way, since an
  exception gives every search for `Total/1` a second place to look. It also **strengthens §5**:
  `index.bs` is unambiguously the declaration file and its presence is the module marker, where the
  alternative leaves it meaning "declarations, and also maybe some functions". A private helper gets
  its own file with 40 §2's `private`; ticket 13's aggregate rule and `13b`'s measured per-file
  attribution make that cost one file and zero runtime. **An error, not a convention** —
  `{function_in_index, Name, Line}`, because an ungated convention decays exactly as the exemplars'
  dead dialect and `LANGUAGE.md`'s `true` claim did.

  **Four checks are specified and unbuilt**, belonging to the feature that implements the module
  system: `{module_path_mismatch, …}` (§5), `{function_in_index, …}` (§4), §2's ambiguity rule, and
  §3's environment-threading. **Two things §3 added rather than decided**: a cycle rule for mutually
  importing modules (F6's cyclic-alias guard is the precedent — refuse by name rather than expand),
  and re-checking cost, which is compile-time only and whose fix is a cache, which is fork B again.
  **One item spun out rather than absorbed**: the import alias is now
  [ticket 47](issues/47-import-alias.md), because 41 recorded that §2 *inverted* the argument
  against it and said it *"should be re-asked rather than inherited"* — and re-asking is a decision.
  **Ticket 16 §4 is discharged as a prerequisite here**: §3 landed on A, so nothing is serialised.

  **ALL FOUR CHECKS ARE BUILT — F15, 2026-08-17**, and §3's source root is now `bsc --src-root`,
  defaulting to the module directory's own parent. **Two wordings in this ticket disagree with
  themselves, F15 built one side of each, and neither is settled** — they are recorded here so the
  choice is the map's rather than a feature's:

  1. **Is `index.bs` mandatory?** §5's operative rule is the classification test — *"a directory
     containing `.bs` files is a module"* — while §4, arguing for keeping it function-free, says
     *"`index.bs` is unambiguously the declaration file and **its presence is the module marker**"*.
     F15 built §5's, because it is the one written as a test.
  2. **What is a "sub-module"?** §5 glosses ticket 13 as having *"made a directory inside a module a
     source-only sub-module"*, which read literally makes a module directory holding another module
     directory a single aggregate — contradicting §5's own rule. **13's measurement settles it and
     the gloss is the imprecise half**: 13 §3's observed output is two *files* in one beam, and its
     `Order/` is the module directory. 13's sub-module is a **file**, so "one `.beam` per aggregate"
     and "one `.beam` per directory" are the same sentence. F15 therefore applies §5 per directory
     and totally, and `examples/Shop/` exercises all three tiers in one path: a module holding a
     namespace holding a module.

- **Binaries as a parsing grammar** — [ticket 30](issues/30-binaries-as-a-parsing-grammar.md),
  resolved 2026-08-20. Raised by the first exemplar to parse a real wire format, and answered
  against a survey of four languages, all compiled and run:
  [`research/30-binary-grammar-prior-art.md`](research/30-binary-grammar-prior-art.md).
  **A binary gets no structure in the type language. A segment's *width* becomes an interval
  refinement on the value it binds** — `t:8` is an `Octet` by inference — and that inference is the
  whole of what the ticket adds. Three refusals sit around it. Sizes stay **erased**: `payload:size`
  runs and `payload` is a `binary`, because relating two fields of one pattern is refused by every
  language measured, three of them with a dedicated diagnostic. **§3's sized-binary spelling never
  arises**, which retires F9's fear of a pattern and a type in disagreeing notations — C# is the
  positive evidence, being the one language with both a sized sequence type and a sequence pattern
  and unable to use them together. **String literals in pattern position are admitted**, with a
  catch-all always required because a `string`'s residual is always open.
  **The binary pattern does shape; a function head does value.** A `_` over a binary is always legal
  (it can always be truncated), so it also absorbs unhandled wire values — the compiler is not asked
  to see through that, which makes an idiom of the shape 25b filed as a smell. Writing the tag
  dispatch inline silently loses the checking, and F13 owes that warning in its docs.
  **The real cost is two general gaps, not binary work**: interval patterns in nested position, and
  a residual renderer that keeps sub-position facts. The coverage engine already decomposes into
  sub-positions and tracks field-level coverage — measured over records, two-of-three atom cases red
  and three-of-three green — but the renderer discards every field fact and prints only the record's
  name. 25c's coupling binds: interval patterns and interval refinements land in the same increment.
  **Flagged as a reversal risk.** Nobody proves coverage over a *sub-byte* field: C# does coverage
  properly but has no sub-byte concept, Erlang has no exhaustiveness checking at all, Elixir's
  machinery provably does not reach binaries, Gleam has subsumption and refuses coverage even for a
  1-bit tag with both values named. Both exemplars are bit-packed in their first eight bits, so for
  the case that matters the survey is unanimous against this answer. Defensible because none of the
  four failed by *trying and finding it unsound* — and cheap to reverse, since nothing entered the
  type lattice.

- [A route table needs a closed list pattern, and ticket 08 refused one](issues/53-a-route-table-needs-a-closed-list-pattern.md) —
  **resolved against its own premise, hours after it was raised, and the correction is the answer.**
  The ticket said there is no spelling for *"a path of exactly two segments"*. There is:
  **`["orders", id, ..[]]`**. The rest of a prefix-plus-rest pattern is itself a pattern and `[]` is
  a pattern, so the form closes itself — ticket 08's own grammar used twice, no language change, and
  available the whole time. Measured in [`53a`](prototypes/53a-closed-list-patterns.md):
  `/orders/42/lines` reaches the catch-all instead of being swallowed by the `Fetch` clause, which
  is the property the ticket said could not be expressed. **The exemplar was written wrong, not
  refused** — the diagnostic *"a list pattern needs a rest"* refuses a **missing** rest, and reads
  like a refusal of closed lists only to someone who has not run it. `route.bs` is fixed.
  Of the four candidates: 1 was already true, 2 and 4 are moot, and *routes are not lists* survives
  as a smaller question to reopen only if an exemplar demands it.
  **What survives is the read cost** — `..[]` says "exactly two" in punctuation neither audience
  recognises, since C# and TypeScript both spell it `["orders", id]` — **and it is now second in
  line behind [`#54`](issues/54-list-length-in-the-algebra.md)**, because measuring the premise found
  that a closed-length clause is invisible to the exhaustiveness checker. The route table above is
  exhaustive only by virtue of its catch-all; sugar over a form the checker cannot see would make
  the surface read more like C# while the guarantee behind it stayed absent.
  The reusable part is the shape: **a ticket whose premise can be compiled should be compiled before
  it is argued.** This one was raised from a grammar file and a diagnostic, and three probe files
  took twenty minutes to disprove it.

- [A record pattern may name its type, and any pattern may take a trailing binder](issues/55-destructure-and-bind.md) —
  **`Frame { Type: :method } f`, and `Frame f` when only the type matters.** The front wall of
  exemplar 25c, and **unasked for nine days** while two files recorded it independently — the
  exemplar README under `unasked`, and `LANGUAGE.md` as *"a grammar-opinion question that is still
  open"*. Neither raised it, which is the map's oldest recurring failure wearing a third set of
  clothes. **The mechanism was already built**: `p_alias` is live in `bs_emit.erl` and every
  tag-dispatching clause emits one, with no surface that reaches it. **The survey is unanimous on
  the type prefix** — C#, Erlang, Elixir and Gleam all name the type in a record pattern and
  beam-sharp alone could not, with Elixir's bare-map escape hatch (`%{__struct__: Frame, …}`)
  costing exactly what beam-sharp's `{ Kind: :'Shop.Frame' }` costs: hand-writing a **minted tag**
  to say *"this is a Frame"*. That is the real argument, not 25c — it is the one place the surface
  makes an erasure detail load-bearing. **It splits 2–2 on the binder and both sides are spent
  here**: `=` was deliberately kept out of pattern position by ticket 45 and spent on bindings by
  F8, and `as` is committed to C#'s checked conversion — free in the lexer, reserved on the map.
  So the binder is C#'s **bare trailing designation**, which is also the shape a signature already
  has (`param -> type_prim lident`, so `Order o`). **Four grammar variants measured at zero yecc
  conflicts** ([`55f`](prototypes/55f_yecc_conflicts.sh)), which **refutes the ticket's own named
  risk** that the pattern/construction disambiguator sits two tokens past yecc's one of lookahead.
  **One zero is not to be trusted and the self-test is why that is known**: variant (c)'s `=`
  carries `Nonassoc 50`, and yecc resolves a conflict on a token with a precedence *silently*. That
  trap had already produced a wrong answer — the first control was `pattern 'and' pattern`, which
  the grammar predicts conflicts and which measured clean because `and` carries `Left 200`;
  rebuilt as a reduce/reduce conflict, which no precedence can mask, the harness reported 7 while
  the untouched grammar reported 0 in the same run. **Decided, not built**, and the coupling to
  respect is that the type prefix and the binder must land together — `bsc` stops at the first
  error and that error is `Frame`, so answering the binder alone leaves 25c's wall exactly where
  it is
- [Composable middleware, and what the valve reaches](issues/31-composable-middleware.md) —
  **`|?>` expresses it, and the gap is one stage-shape rather than a mechanism.** The chain
  `Auth(req) |?> Quota() |?> Dispatch()` compiles and runs; a halting stage stops the pipeline and
  its response reaches the caller **unchanged through two intervening stages**, so routing really is
  one stage near the end. Measured rather than argued
  ([`31d-middleware-measured`](prototypes/31d-middleware-measured/Middleware/middleware.bs)), which is what the
  2026-08-18 note on the ticket asked for once F14 made the valve real. **The cost is one word, not a
  shape**: a terminal stage never passes through, so it is declared `(:error, Response)` and the
  pipeline has **one** member — the unwrap is one clause the compiler proves is enough, which
  neither Plug nor ASP.NET Core can state, since in both a halted and a live value have the same
  type. What is wrong is the atom: a `200 OK` is spelled `(:error, _)` and that reaches the `-spec`
  and the crash report. **The two-clause unwrap this entry first reported was an artefact** of a
  probe that declared the router over `Response`; 31c had already written the better shape and this
  session nearly missed it. **Ticket 15 §1's collapse does not fire** — on the algebra, not on the
  measurement first claimed: `validate_collapses/2` has one caller, the `ValidateAs<T>` site, so a
  user declaration never reaches it. Chasing that found **half of 15 §1 unbuilt**:
  `type Absorbed = atom | :nothing`, its own worked degenerate case, compiles.
  **The one thing it cannot say is in-the-chain-and-still-runs** — a stage observing both outcomes is
  piped with `|>` and wraps the chain from outside, where Plug's logging plug sits *mid-list* and
  still sees halted conns. That is also where the ticket's own premise was wrong: `halt/1` sets a
  flag checked *between* stages and `before_send` still fires, where the valve returns and nothing
  downstream runs at all. **The `Plug.Builder` worry restated**: a runtime list of stages has no
  spelling for want of an arrow type, but that is deferred to ticket 37 rather than refused, and
  Builder assembles at compile time too — alignment, not a gap. Two smaller findings owed onward:
  stage-local state is `list<(atom, term)>` because `with` is width-preserving and there is no map
  type (→ ticket 48), and a stage dispatching on a **field projection** needs a catch-all, since
  guards discharge the residual on a bare parameter and **not** on a projection (controlled for).
  **25a is now rewritable as a pipeline**, which its own notes call the largest thing wrong with it.

- [A build and dependency tool, or riding on rebar3 and mix](issues/51-a-build-and-dependency-tool.md) —
  **beam-sharp builds none of it, and the code-path problem turned out not to exist.** The ticket
  asked whether a mix-equivalent was owed and the question dissolved under measurement: `ERL_LIBS` is
  honoured by the BEAM code server, an escript inherits it, and both neighbours already emit one
  directory per application with an `ebin` inside — the exact shape `ERL_LIBS` means. Candidate 1 was
  written as *"one flag"*; the answer is **none**, and `bsc` reached Req 0.7.3 and its nine-package
  tree unmodified. **rebar3 is the neighbour to prefer** and that is the only choice here rather than
  a measurement: `bsc` is itself a rebar3 escript, so with `rebar_mix` a beam-sharp application
  declares Elixir dependencies in `rebar.config` and stays in one toolchain, no `mix.exs` anywhere.
  **Elixir is a per-project dependency, not a per-language one** — installed on whatever *builds* a
  program that uses Req, because something must compile `.ex` and only Elixir does (`rebar_mix`
  *drives* it rather than replacing it, measured); present only as `.beam` files to *run* one, which
  an OTP release bundles like anything else. A program calling no Elixir library needs Erlang alone,
  and Erlang was never a dependency — it is the target. **The scope boundary held without bending**:
  nothing here resolves, locks, fetches or publishes, so the refusal of a package manager was never
  in tension with the finding. **What it deliberately leaves open is provenance** — nothing in a
  `.bs` file records what it needs, so a program cannot be handed over on its source alone, and the
  captured candidate is that the **FFI declaration is already the place a foreign thing is named**
  (→ ticket 52). Practical consequence logged not solved: an exemplar binding Req makes CI fetch nine
  packages and need Elixir on the runner, the first gate here to depend on the network.

- [List length in the algebra: a proved-exhaustive program that crashes](issues/54-list-length-in-the-algebra.md) —
  **the algebra models none of it, because it decomposes the cons cell instead of measuring it.**
  That is a fifth candidate the ticket did not list, and it is what the one surveyed language that
  gets this right actually does. Four languages were run rather than recalled: **Erlang does not
  catch it** (`erlc` silent, **Dialyzer passes**), **Elixir 1.19.5 does not catch it** — which is
  the finding that should sting, since it ships Castagna's set-theoretic types, *the same theory
  `bs_types` rests on*, and has the identical hole for the identical reason — **C# catches it and
  names `{ Length: 1 }`**, **Gleam catches it and names `[_]`**. The two that work disagree only on
  vocabulary, and the disagreement follows the data structure: a C# array has an O(1) `Length` to
  talk about, a cons chain has none. **beam-sharp has no `Length` either** — there is no `length`
  anywhere in the language, no guard, no refinement, no type spelling — so candidate 2 would put a
  quantity in the algebra that nothing in the source can name. **And candidate 2 is dominated**:
  Gleam's residual for `[] / [_] / [True, _, ..]` is `[False, _, ..]`, a length and an element value
  in one pattern, which no interval can express and which is exactly the shape a route table needs.
  Candidate 2 buys the machinery and leaves ticket 53's table unchecked. **The mechanism was already
  in the tree**: `product_minus/2` is the exact n-way product-difference rule, already recursive
  through `subtract/2`, applied to tuples and maps and simply never to the cons cell — so the new
  work is termination, not an algorithm. **The rest position becomes a marker and `[a, b]` means
  exactly-two**, reversing ticket 08 on that point and retiring `..[]`. This was never a
  borrow-from-C# question: **`[a, b]` is exactly-two in Erlang, Elixir, C# and Gleam alike** — the
  one place the two families agree — and B# alone refused it. **The refusal was worse than a
  divergence, because it recommended a meaning change**: *"write `[h, ..t]`"* turns an exactly-two
  pattern into a two-or-more one, and that is precisely the form the checker gets wrong — **the
  four-line repro is reachable by following the compiler's own advice.** Marker-rest also makes the
  decomposition terminate by construction, which is what `bs_types.erl`'s warning against a
  recursive list part was guarding: unfold depth is `lists:max/1` over the prefix lengths written.
  **Measured free**: `yecc:file/2` reports 0 conflicts on the current grammar, 0 on marker-rest, 0
  with fix-it error productions added, against a control that reports 1 reduce/reduce — and **`[a,
  b]` needs no grammar change at all**, since `plist_items -> pattern` already yields `Rest = nil`
  and the refusal is one `erlang:error` in `bs_check`. **Ticket 12 §2 reaches lists with no
  exemption**: a `list<bool>` residual of exactly-one-bool is closed and inhabited, so a catch-all
  over it becomes an error naming `[true]` and `[false]` — the residual decides, never the type
  constructor. It bites only on closed element types, and it makes ticket 43's cap do real work.
  **Five symptoms, not two**, and the new fifth is the worst: `[] / [a, b, ..t] / [a, ..t]` has
  clause 3 reported **unreachable** while `erlc` stays silent and `Shape([7])` returns `:one` —
  *the clause the compiler called dead is the clause that runs*, which for the clean-room handoff is
  more damaging than a crash, since a fleet deletes it. **One of this ticket's own premises was
  false**: *"449 tests pass today with the wrong behaviour, some may encode it"* — **none do**; the
  suite has no multi-element prefix cons and no `..[]` at all. What it has is a hole, since
  **nothing tests the diagnostic this deletes**, and `check-diagnostics.sh` only checks that every
  tag has a message, so an orphaned message stays green forever. Blast radius in live source is
  **four lines** (`25a/route.bs`), plus one confirmed red gate — LANGUAGE.md's `Dispatch` block is
  untagged and must compile.

- [Division and modulo](issues/38-division-and-modulo.md) — **`/` on two `int`s is truncated
  integer division and `%` is the remainder it leaves, signed by the dividend** (`-7 / 2` is `-3`,
  `-7 % 2` is `-1`). Phrased over the operand types on purpose, so a later `float / float` stays
  open. **`/` carries no precondition**: a divisor needs no proof it is non-zero, and only a
  divisor the compiler proves *is* zero is refused — `Mean(total, count) -> total / count` compiles,
  `Bad(n) -> n / 0` does not. A possibly-zero divisor crashes at run time, which is ticket 12's
  stance and not a gap. §2(b) — every divisor's type must exclude zero — was refused on cost to the
  caller, not on feasibility. The check is `is_subtype(Divisor, range(0,0))` over a type the
  checker already computes, and it strictly beats both agreeing sources: `erlc` constant-folds only
  when *both* operands are literals, so `variable(X) -> X div 0` warns nowhere today.
  **Two of the ticket's own premises were false on re-measurement.** The sources do not split on
  divide-by-zero: JavaScript's `Infinity` is *float* division, and the comparable integer operation
  is BigInt, which truncates and throws `RangeError` — so all three agree twice over. And C# does
  not merely throw at run time; `7 / 0` is compile error CS0020, so a compiler refusing a provable
  divide-by-zero is not novel. Also stale: *"nothing in the surface says `int` without zero except
  a guard"* — F2 landed the day after the ticket was raised, and `int where value != 0` compiles.
  Emission maps `/` to Erlang's **`div`**, never its `/`, which is float division. Raised by an
  outside workload (AoC 2019 Day 1), which is the better class of evidence.
- [A refined parameter gets a boundary guard](issues/46-refined-parameter-at-the-boundary.md) —
  **yes, and the guard is the part of the refinement the clause does not already prove.**
  `Classify(>= 9)` emits `andalso Bs@r1 =< 255` and nothing else; `Classify(1)` and
  `Classify(>= 4 and <= 7)` emit nothing, because a literal and a two-sided span already prove
  themselves inside `0..255`. **Emitted always, on exported functions only** (18 §4 scopes rule C to
  *"the exported function's own clause heads"*), **and there is no second tier** — a record's shape
  has two forgeable parts and a refinement has one, so 26 §1's tag/exact-set split has no analogue.
  **The generalisation is the result worth keeping**: `constrains_kind/1` is a boolean because a tag
  either is or is not constrained, but a bound can be *half* proved, so the emitter **subtracts**
  (`bs_types:subtract(Accepts, Declared)`) rather than testing a flag. Measured over `wire.bs`:
  6 of 11 clauses need nothing, the other 5 carry **6 comparisons** against 22 for naive
  two-per-clause emission — so the ticket's *"a range test is two comparisons"* is the worst case,
  not the cost. `Band(n) when n <= 64` emits the **lower** bound and is what catches `Band(-5)`,
  which returns `:low` today: the ticket framed the question entirely around values above the
  domain, and half the escapes are below it. Failure is `function_clause`, matching the record tag
  test — **inspectability is ticket 23's**, which 18 §7 already handed it. Guarded wherever a
  **fixed number of projections** reaches the value (whole parameter, tuple element, record field —
  26 §7 already puts a field's value test inside 18's scope), never through a collection, since a
  `list<Octet>` is O(n) in a length the foreign caller chooses — ticket 11's refusal at a third
  site. **Three of the ticket's own premises were corrected.** 18 did not call the exported check
  optional — *its intake did*: the quoted line is at `18:107`, inside a section gathering ticket
  09's material, and 18 resolved the day after with §1's rule C and a §5 titled *"No opt-out"*. The
  admissible-vocabulary claim holds but not on the cited authority: `18:99–102` is ticket 09's
  *union-discriminability* set and contains no comparison at all, so the citation that works is
  **20 §5** — a guard-decidable refinement is *"legal in a clause head, legal at an FFI
  declaration"*. And `boundary_guards/4` is **not** scoped to exported functions despite a comment
  saying it is; measured, a private `Inner(Order o)` receives the tag test. **Hands ticket 18 a
  correction to its census**, which counts a parameter defended if every clause *"constrains it
  structurally or mentions it in a guard"* — `Classify(>= 9)` does the latter and admits `300`
  anyway, so the heuristic and rule C diverge exactly on F2's construct. Raised
  [ticket 58](issues/58-refined-int-admits-a-float.md) beside it: `Classify(100.5)` is `:reserved`,
  which 18 §1(b) decided and the emitter never built, and on which this guard's soundness rests.

- **How opinionated is the language** — [ticket 22](issues/22-how-opinionated.md), resolved
  2026-08-23, overturning [ticket 23](issues/23-what-the-language-owes-an-agent.md) §7. Deferred on
  2026-08-12 to be decided against code rather than precedent, and the code answered it. **There is
  no incomplete marker: a signature with no clauses stays a hard error, and no keyword is spent.**
  David, once the cost had been measured rather than argued: *"no, I don't think a half-written
  module is worth running, the compiler error is enough."* The spelling question 23 §7 handed over —
  attribute, keyword or convention — is never asked, because the construct does not exist. **The
  survey that preceded the decision is kept, because two of its findings outlive it.** No surveyed
  language spells an unfinished marker as an attribute: Gleam uses the keyword `todo` and C# a
  library exception, both in **body** position, and a bodiless *declaration* is a hard error in C#
  (CS8795), Erlang and beam-sharp alike — so beam-sharp was in the majority all along, not being
  unusually strict. And §7's promised diagnostic already exists: `--api` answers for a half-written
  module at exit 0 and prints `int Priority(:body | :header | :heartbeat | :method)`, which is the
  residual §7 wanted, on a channel that works. What §7 additionally asked for was a `.beam` emitted
  from a module with a hole in it; measured, that costs one error per unwritten function and zero
  `.beam` files, while suppressing no other diagnostic. That was the part refused. **The domain arm
  is dead on mechanism**: no attribute grammar has ever existed, `[Port]` lost its enforcement job
  to F18 and F24, and the one non-vacuous DDD invariant — aggregate boundary — is already bought by
  26 §1's record tag minted from the qualified module path (F3). The guardrail argument survives but
  supports the half already built: every drift the exemplars actually produced was caught by an
  architecture-neutral structural rule (F3, F11, F15), and none would have been caught by
  `[Aggregate]` or `[Command]`. Visibility split out and shipped without this ticket as F12; *which
  modules may name this one* is split out again as its own question. Probes:
  [`prototypes/22a_incomplete_marker_probe/`](prototypes/22a_incomplete_marker_probe/).
