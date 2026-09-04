# 11 — Type system shape and the `dynamic()` boundary

Type: grilling
Status: resolved 2026-08-12
Blocked by: 03, 04, 09

## Question

Ticket 00 committed to "static-by-default set-theoretic types". What shape does that take
concretely?

Decide:

- **Generic syntax.** C# angle brackets, or something else? Does the language even need
  parametric polymorphism given set-theoretic unions can express a lot without it?
- **Inference strength.** Full inference, or annotations required at module boundaries?
  Elixir infers without annotations; Gleam infers within a module and encourages
  annotations at the edges. Note that set-theoretic inference has a performance cost that
  Elixir's roadmap is explicitly gated on.
- **Subtyping rules** — what the subtype relation is, and whether variance needs stating.
- **The `dynamic()` boundary**, the critical part:
  - Where is `dynamic()` introduced — only at declared interop points, or anywhere?
  - What operations are permitted on a `dynamic()` value?
  - Do values crossing from Erlang arrive dynamic by default, or must the programmer
    declare a typed boundary?
  - What happens when a dynamic value flows into an exhaustively-checked function — does
    exhaustiveness still mean anything?
- **What is checked at compile time versus what is trusted.** Name the guarantee the
  language actually offers, in one sentence a user would understand.

## Binding constraints from ticket 04

- **Signatures are mandatory on multi-clause functions** — see ticket 08. This settles this
  ticket's "inference strength" sub-question at one end: full inference with no annotations is
  not available if the exhaustiveness guarantee is to mean anything.
- **Redundancy must warn, never error.** Attainability is provably non-compositional: with
  intersection types the body is re-checked once per arrow, so a clause dead under one arrow
  may be live under another. Both CDuce and Elixir accumulate liveness across arrows and warn
  post-hoc. A checker that errors on a locally-dead clause makes overloading unwritable.
- **Good diagnostics come free if you compute the difference rather than asking a boolean.**
  Exhaustiveness is `t \ (Acc(p₁)|…|Acc(pₙ)) ≃ 0`, and the residual *is* the missing case —
  CDuce prints the residual type plus a sampled counter-value. First-match ordering is the
  subtraction itself, baked into the type-level operator rather than bolted on.
- **Do not repeat the complexity folklore.** "Set-theoretic subtyping is EXPTIME-complete" is
  citation drift: that result is for regular tree types *without arrows*, and the 2^O(n) bound
  is for a μ-calculus encoding, not CDuce's algorithm. Frisch says the real algorithm's
  complexity was never studied and expects a *larger* lower bound; no bound for tallying exists.
- **Measured cost**: 2–9% of Elixir compile time on real projects, with an unbounded tail. The
  inner loop is emptiness, and BDD expansion grows exponentially on consecutive unions.
  **Uncomfortable overlap**: Etylizer's pathological inputs are `case` expressions with 40+
  branches — which is exactly the large multi-clause `handle_info` this language showcases.

## Constraints from ticket 06

- **The violation surface is eight channels**, not one: direct calls, mailboxes, `EXIT`/`DOWN`
  signals, timers, ETS reads, decoded external terms, `code_change/3` state written by a
  *previous version of this module's own types*, and ambient config. A `dynamic()` design that
  only considers direct calls is under-specified.
- **Two term-model traps for a naive type system**: a binary *is* a bitstring, and map key
  order is the opposite of term order for integers versus floats.
- **Do not build a `debug_info` backend for dialyzer.** Success typings are strictly weaker
  than the committed type system, and Elixir's v1.20 checker offers foreign languages nothing —
  its roadmap phases Erlang typespecs out rather than adopting them. Emitting `-spec` is cheap
  and worth doing for Erlang callers and docs; that is the whole of it.

The one-sentence statement of the guarantee this ticket must produce is now harder and more
important, because ticket 06 showed the guarantee can be silently false rather than loudly
broken. Ticket 18 decides how it is defended.

## Constraints from ticket 09 — resolved 2026-08-12

[Ticket 09](09-union-representation.md) settled that types are **structural and open**, that
there is **no nominal type in the language at all**, and that naming is aliasing. What that
binds here:

- **`type X = ...` is the single naming construct** — records, tuples, scalars and unions
  alike. There is no separate union declaration form. Any syntax this ticket adds for naming
  types must go through it or explain why not.
- **Recursive types are equirecursive, and definitions must be contractive.** A name is a
  μ-binder; a type and its unfolding are identical, so **subtyping is decided coinductively**
  and the checker carries a memo table of in-progress goals. This is not optional — trees, JSON
  and any user-defined recursive shape need it — and it compounds the cost already recorded
  above. **Recursive *and* parametric together is the combination Elixir's roadmap calls
  unfeasible to get wrong** (→ ticket 20), and ticket 09 has now committed this language to the
  recursive half.
- **The measurement job is sharper.** Coinductive subtyping over regular recursive types is
  standard and CDuce decides it, so this is the paved path rather than an extension — but it is
  where the checker gets slow, and it stacks with the 40+-branch matches this language
  advertises. The walking skeleton should measure recursive-type-heavy input, not just wide
  matches.
- **The permitted set is written at the function signature**, which is where ticket 04 already
  put it. Ticket 07 §5.1(5) warned that exhaustiveness is only cheap if the permitted set is
  declared rather than discovered by scanning; that warning is satisfied by signatures, not by
  named unions, so nothing here needs to change to accommodate it.
- **The one-sentence guarantee this ticket must produce cannot lean on nominal identity.**
  Ticket 09 §5: nominality is unenforceable against a raw Erlang caller, because the BEAM has
  no construction discipline. Whatever the sentence says, it is a claim about the *shape* of a
  term, never about where it came from.

## Constraints from ticket 10 — resolved 2026-08-12

- **Atoms are singletons and `atom` is the cofinite top.** Verified against a shipping
  implementation of the same theory (Elixir 1.19.5 `Module.Types.Descr`): `:ok` is
  `%{atom: {:union, %{ok: []}}}`, `atom()` is `%{atom: {:negation, %{}}}`, and `:ok | atom()`
  normalises to `atom()`. Ticket 09's normalisation rule is therefore verified, not asserted,
  and the cofinite residual is a real representation.
- **`bool` is a prelude alias, not a builtin** — `type bool = true | false;`. Elixir's own
  checker represents `boolean()` as exactly that two-atom union. Do not add a primitive.
- **`if` requires `bool`. There is no truthiness.** Elixir's truthy/falsy split forces two
  operator families (`&&` vs `and`, with `nil and true` raising); ticket 01's `&&`/`||` guard
  operators already committed this language the other way.
- **Typo exposure lands here.** Under an open atom universe, a misspelled atom is caught
  wherever a declared type is in scope, because the signature is the declaration site for the
  permitted set (ticket 04). It is *not* caught in `dynamic` positions — which makes "what
  operations are permitted on a `dynamic` value" a question with a concrete new consequence.
- **Open question inherited**: ticket 10 §5 puts `type option<T> = T | :nothing;` in the
  prelude, which assumes the alias mechanism admits **type parameters**. Ticket 09 already
  writes `list<Json>` and `map<string, Json>`, but a parametric *alias* is a type-level
  function and this ticket owns whether that is in scope.

## Scope split — David, 2026-08-12

This ticket was charted holding at least six decisions. It is the keystone (it blocks seven
tickets), so it was split rather than answered thinly:

- **This ticket keeps**: the `dynamic` boundary, the subtyping relation, and the one-sentence
  guarantee. → unblocks **12, 13, 20, 23, 24**. **Ticket 18 is *not* unblocked** — verified in
  Linear, ENG-184 is blocked by 11, **12 and 22**, and 22 is deferred pending a walking skeleton.
  (The repo file for ticket 18 listed only 11 and 12; **Linear is canonical for blocking** and the
  repo was stale. Corrected below.)
- **Spun out to a new ticket 27 — parametric polymorphism**: whether the language has generics
  at all, generic syntax, and parametric *aliases* (`type option<T> = T | :nothing;`, the debt
  ticket 10 §5 left). That ticket becomes ticket 16's blocker in place of this one, and it —
  not ticket 26 — owns the parametric-alias question.
- **Folded into ticket 20**: integer interval types and guard refinement (ticket 01's `Fib`
  debt).
- **Not reopened**: inference strength. Tickets 04 and 08 already settled it — signatures are
  mandatory on multi-clause functions.

## Answer — resolved 2026-08-12

### 1. There is no `dynamic` in this language

The ticket's own framing — "where is `dynamic()` introduced" — treats it as a *place*. Both
shipping implementations treat it as something else, and beam-sharp takes neither:

| | Elixir 1.19.5 (`local`) | Gleam 1.18.1 (`local`) | **beam-sharp** |
|---|---|---|---|
| In the type system? | yes — `%{dynamic: :term}`, a field on every type | no — `pub type Dynamic`, a library type | **no such type at all** |
| Entry | free | `@external(erlang, "gleam_stdlib", "identity")` — free cast | arrives as `term` |
| Exit | `compatible?`, a second and weaker relation | `decode.run/2`, a hand-written decoder | **a clause head** |
| Who writes the check? | nobody | the user, per shape | the pattern already is one |

External values arrive typed `term`, the set-theoretic top. The only way to use one is to
match it, and the exhaustiveness checker computes `term \ (Acc(p₁)|…|Acc(pₙ))` — so the
residual *is* the boundary case you failed to handle, and it is not empty until you do.

**One relation, not two.** Because nothing is gradual, subtyping stays plain set-theoretic
containment (coinductive over the equirecursive types ticket 09 settled). Elixir needs
`subtype?` *and* `compatible?` precisely because `dynamic` relates to nothing under the sound
relation — observed: `subtype?(integer, dynamic) = false`, `compatible?(dynamic, integer) =
true`. beam-sharp has no such value, so it needs no such second judgement.

**The borrow heuristic does not discriminate here, and that is itself the finding.** Tier 1
supplies a construct for *both* poles — C# has `dynamic` (a real type, runtime-bound) and
TypeScript has `unknown` (narrow-before-use) alongside `any`. Neither audience needs teaching
either shape, so the eight-channel problem decides it, not familiarity.

**Consequence for ticket 08**: its line "`dynamic` narrowing is always written, never inferred"
survives in spirit and loses its keyword. Narrowing is written — as a clause head.

### 2. Patterns over a `term` are O(1) guard-decidable only

Narrowing a `term` compiles to BEAM guards, and guards decide some types and not others:
`is_integer`, `is_atom`, `is_list`, tuple shape and size in O(1); element types and function
signatures never. So a pattern over a `term` may mention **only what a guard decides in O(1)**.
`list<term>` is writable; `list<int>` is a compile error in that position.

This is ticket 09's discriminability rule extended verbatim — **BEAM guards are the vocabulary**
— rather than a new rule.

Deep validation exists, as an explicit call to a **compiler-generated `ValidateAs<T>`**:

```
list<term> xs = ...;                              // O(1), is_list
list<int> | :error ys = ValidateAs<list<int>>(xs); // O(n), at a visible call site
```

Rejected: emitting the traversal *inside* the clause head. The cost is O(n·depth) and **the
sender chooses n** — ticket 06's channels are mailboxes, ETS reads and decoded external terms,
none of them yours. A construct that looks like constant-time dispatch must not become
unbounded work chosen by a foreign process. Also rejected: checking `is_list` and trusting the
elements, which is ticket 06's silent unsoundness reintroduced one decision after `dynamic` was
dropped to avoid exactly that.

**`ValidateAs<T>` is codegen, not generics.** It is the same type-directed codegen obligation
ticket 10 established for `ParseAtom<T>`: `<T>` is a compile-time argument driving generation,
monomorphic at every use. **Ticket 27 must not read either as evidence that the language has
parametric polymorphism** — that question is still open there.

### 3. `ValidateAs<T>` rejects arrow types at compile time

A fun carries no runtime evidence of its signature, and this is not a BEAM wart — a function's
type is absent from its runtime value in every language. It surfaces here only because
validation was made first-class.

Measured (OTP 28, `prototypes/11b_fun_evidence.erl`): `erlang:fun_info` yields
`{module,hotmod},{name,f},{arity,1},{type,external}` for an external fun and `{name,[]}` for a
closure. **Identity, never types.**

The trap that decides it: arrow subtyping is contravariant in the argument, so the top arrow is
`none() -> term()`, whose parameter type is `none` — **there is no value you can legally pass
it**. Verified: `subtype?(fn(int)->int, fn(none)->term) = true` but
`subtype?(fn(int)->int, fn(term)->term) = false`. So "narrow it to `fn(term)->term` and call it"
is unsound; that type claims the fun accepts *every* term.

Therefore `ValidateAs<T>` is **illegal for any T containing an arrow**. A foreign fun can be
held and passed back to Erlang; it cannot be called from beam-sharp. The idiomatic boundary is
**MFA** — `{atom, atom, int}`, three guard-decidable leaves, which validates with no special
case.

Rejected: **higher-order contract wrapping** (validate each argument in, the result out). It is
the literature's correct answer and the only sound way to *call* a foreign fun — rejected on the
same hidden-cost grounds that decided §2, plus its need for blame tracking. **Chosen partly for
reversibility**: wrapping is purely additive later and would invalidate no program written under
this rule, whereas arity-and-trust is not reversible, since programs come to depend on the
unsoundness.

**A claim of my own, corrected by measurement.** I argued OTP prefers MFA because funs go stale
across hot code loading. That is true of **closures only**: after loading v2, a closure still
returned `{v1,closure,1}` and died `badfun` once v1 was purged, while `fun M:F/1` returned
`{v2,1}` and survived the purge — late-bound, exactly like MFA. The argument for MFA is
narrower than I stated.

**Deferred option, with its requirement recorded**: because an external fun *is* recoverable to
an MFA at runtime, and beam-sharp compiles its own modules and already emits `-spec`, a future
check could look up the target's declared signature and compare. **Requirement: a runtime type
registry** keyed by module. Not designed here; it is a whole mechanism, and nothing yet needs it.

### 4. The top type is spelled `term`

Not `unknown`, not `object`, not `any`.

The borrow heuristic points the other way — TypeScript's `unknown` is a tier-1 construct meaning
exactly "narrow before use" — so **this is a deliberate override of the heuristic, recorded as
the heuristic's own tier 3 requires.** The reason:

- In a set-theoretic system the top type is **a set**, and it participates in the algebra. The
  exhaustiveness residual is literally `term \ (Acc(p₁)|…|Acc(pₙ))`. `unknown` names an
  epistemic state; you cannot take the complement of your own ignorance. `term` names a domain.
- **Source and emitted artefact then agree.** Ticket 06 recommends emitting `-spec`, and the
  spec says `term()`. One word, not two, for a reviewer reading both. (Erlang's `term()` and
  `any()` are synonyms — `doc`; an attempt to verify this locally via `erl_types` failed, the
  API is internal.)
- Neither audience has the word, so neither mis-imports a meaning. `object` would drag C#'s
  root-class and boxing connotations into a language with neither; `any` is TypeScript's
  *unsound* top, assignable in both directions, which is the opposite of this.

**Gleam has no answer here, and structurally cannot.** Its only candidate is
`pub type Dynamic` — an opaque library type documented as *"data that we don't know the type of
yet"*. Hindley-Milner has no subtyping, so nothing can be a supertype of everything and the
question never arises. Gleam's epistemic name is honest *for an opaque box*; beam-sharp's is not
a box. This is the same shape as ticket 03's finding: not a fork Gleam considered and rejected,
but one its machinery never put in front of it.

### 5. The guarantee, in one sentence

> **Every case your types admit has a clause — and everything from outside is a `term` until
> you match it.**

With the gloss that follows it in the spec, kept verbatim:

> beam-sharp checks that your clauses cover every value your signatures admit; it does not check
> where a value came from, so anything crossing the boundary is a `term` until proven otherwise.

**The sentence is deliberately stable under ticket 18.** The rejected candidate was the one that
*sounded* most rigorous — "so long as every caller is beam-sharp, no function receives a value
outside its declared type" — and it fails because it pins the guarantee to **who called you**,
which ticket 09 §5 already established the BEAM cannot enforce. Candidates that pin it to
**shape** survive whichever way ticket 18 decides, because guards check shape and never origin.

**This ticket does not decide whether the compiler emits defensive guards.** That is ticket 18,
and the sentence above is true either way.

## Notes

HITL. Waits on ticket 04 for the algorithms, ticket 03 for what has and has not worked
before, and ticket 09 because the union model determines what a type even is here.

**Evidence** (all `local`, OTP 28 / Elixir 1.19.5 / Gleam 1.18.1):
[`prototypes/11a_dynamic_descr.exs`](../prototypes/11a_dynamic_descr.exs) — how Elixir
represents `dynamic`, the two relations, and arrow subtyping including the `none() -> term()`
top. [`prototypes/11b_fun_evidence.erl`](../prototypes/11b_fun_evidence.erl) (+ `_v1`, `_v2`) —
what a fun carries at runtime, and closure staleness versus external-fun late binding across a
code upgrade.

## Amendment from ticket 27 — resolved 2026-08-12

**The open question this ticket inherited and split out is closed, and both of its cautions
survived.**

This ticket's §"Open question inherited" flagged that ticket 10 §5's `type option<T> = T |
:nothing;` assumes an alias may be a **type-level function**, and split the generics half out as
ticket 27. Resolved: **the language has real prenex parametric polymorphism** — parametric aliases
are genuine type-level functions, variables are **declared** and named by C#'s `T` convention,
**opaque in clause heads and guards**, **unbounded**, and **variance is not a concept** (this
ticket's measured arrow contravariance is emergent from set containment, not an annotation anyone
could have written differently).

**This ticket's caution held exactly as written.** `ParseAtom<T>` and `ValidateAs<T>` are still
**not** generics — and now that real generics exist, 27 §8 turns that observation into an enforced
rule: **a codegen obligation requires a ground type argument**, so `ValidateAs<TSource>` inside a
polymorphic function is **rejected at compile time**. This is a second rejection rule alongside
this ticket's existing one for arrow types, and for the same underlying reason — you cannot
generate a runtime structural check for something whose shape is not known at generation time.

**`list<term>` versus `list<int>` is untouched.** §2's rule that a pattern over a `term` may mention
only what a BEAM guard decides in O(1) is orthogonal to type variables; 27 §2's restriction is
about *variables*, this one is about *depth*. A clause head may not test a `TSource`, and may not
test the element type of a `list<term>`, for two different reasons.

**One thing this ticket should know it lost.** 27 §6 measured that an emitted polymorphic `-spec`
is **not enforced by Dialyzer** — the variables read as `any()`. So the guarantee stated here —
*"Every case your types admit has a clause, and everything from outside is a `term` until you match
it"* — is unchanged inside the language, but the *published* evidence for it is weaker for
polymorphic functions than for monomorphic ones. → ticket 18.

## Amendment from ticket 15 — resolved 2026-08-12

**`ValidateAs<T>` returns `result<T, ValidationError>`, not `T | :error`.**

This ticket left the payload question open and ticket 15 settled it, but the reason is not the one
this ticket anticipated. It is not only that a bare `:error` is a thin diagnostic — it is that
**`T | :error` is degenerate for exactly the `T` a deep validator is most likely to be generated
over.** Measured (Elixir 1.19.5, [`prototypes/15a_untagged_failure_collapse.exs`](../prototypes/15a_untagged_failure_collapse.exs)):
`atom | :error` normalises to `atom`, because ticket 09's normalisation rule absorbs a singleton
into a cofinite top before discriminability is ever asked. The failure channel disappears silently.

Giving the reason a payload makes the member a tuple, and `atom | (:error, binary)` does **not**
collapse. So the payload is what makes the channel survive, not merely what makes it informative.

`ValidationError` is a path into the term plus the expected type — Gleam's decoder shape.

## Decisions entry

<!-- The body of this ticket's entry in wayfinder/decisions.md, which is GENERATED
     from blocks like this one. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
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
```
