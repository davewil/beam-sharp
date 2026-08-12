# 11 — Type system shape and the `dynamic()` boundary

Type: grilling
Status: open
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

## Notes

HITL. Waits on ticket 04 for the algorithms, ticket 03 for what has and has not worked
before, and ticket 09 because the union model determines what a type even is here.
