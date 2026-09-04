# Decisions so far — one line each

> **One line per closed ticket: the headline and the first sentence of its entry.** Enough to
> answer *"was X decided, and where"*; the whole entry — the cross-ticket synthesis, retractions
> and amendments — is read in the ticket's `## Decisions entry` block. `map.md` carries the
> index: headline, ticket number and topic tags.
>
> **THIS FILE IS GENERATED.** `bin/gen-decisions.py --write` assembles it from the
> `decisions-entry` block in each ticket, in the order [`decisions.order`](decisions.order)
> records. **Edit the entry in its ticket, not here** — an edit made here is reverted by the next
> regeneration, and `bin/check-decisions-derived.sh` reds the build before that can happen.
> `bin/check-decisions-size.sh` keeps it under 300 lines, and since nothing can be omitted from
> a generated file, the only way to satisfy that is to shorten an entry's first sentence.
>
> *History.* Split out of `map.md` on 2026-08-15 at 1,564 lines, whole entries hand-kept here
> until 2026-09-04 (`1a86b0b`, ENG-310 stage 2) when each moved verbatim into its ticket, and
> reduced to one line each on 2026-09-05 — the acceptance test ENG-310 wrote on the day it was
> filed, built last.

## Decisions so far

<!-- one line per closed ticket: enough to judge relevance, then open the ticket for detail -->
<!-- BEGIN GENERATED — bin/gen-decisions.py; edit the ticket, not this file -->
- [Charting: differentiator, typing stance, scope](issues/00-charting-decisions.md) — the language exists for the multi-clause heads Gleam explicitly refuses; typing is static-by-default set-theoretic with enforced cross-clause exhaustiveness; tooling, stdlib breadth, macros and alternative backends are out of scope.
- [Prior art: static types plus multi-clause heads](issues/03-prior-art-static-multiclause.md) — **Gleam never rejected multi-clause heads; it never considered them.**
- [Audit of `purescript-backend-erl`](issues/19-purescript-backend-erl-audit.md) — **retracts a ticket 03 claim**: it emits **exactly one clause per function, always, with no guard**, not native clause heads.
- [A page of idiomatic beam-sharp](issues/01-sample-code.md) — **Variant A settled**: equations under a signature.
- [Escape-hatch precedents](issues/21-escape-hatch-precedents.md) — **neither Roc's nor Unison's mechanism transplants, and they fail for the same reason in opposite directions: both control what a program may *reach*, where ticket 06's problem is what may reach the *program*.**
- [Head and guard syntax](issues/08-head-and-guard-syntax.md) — **the surface is settled.**
- [Compilation targets](issues/02-compilation-targets.md) — **three tiers, not a binary.**
- [Cross-clause exhaustiveness](issues/04-crossclause-exhaustiveness.md) — **the mechanism is not a research risk; it has been solved and shipped since 2003.**
- [Erlang/Elixir interop surface](issues/06-interop-surface.md) — the surface is **smaller than expected** (`-behaviour` has no runtime effect; Elixir needs no special machinery), but the violation surface is **eight channels**, not one.
- [C# 15 `union` and TypeScript discriminated unions](issues/07-csharp15-and-ts-unions.md) — C# unions are **preview, not shipped**, and the design is still moving (champion issue is #9662, not #8928; no primary source for "GA Nov 2026").
- [Union representation](issues/09-union-representation.md) — **structural and open; there is no nominal type in the language and no union declaration form.**
- [C# functional feature inventory](issues/05-csharp-functional-inventory.md) — LINQ query comprehension is portable (ECMA-334 makes it a pure syntactic rewrite, bound before type binding, with no `IEnumerable<T>` dependency); extension-method chaining *is* already a pipeline rewrite; `with` becomes more central than in C#.
- [Atoms in a C# skin](issues/10-atoms-in-a-csharp-skin.md) — **the atom universe is open**: `:ok` is a singleton type, `atom` the cofinite top, and nothing declares an atom.
- [Type system shape and the `dynamic` boundary](issues/11-type-system-shape.md) — **there is no `dynamic` in this language.**
- [Totality versus let-it-crash](issues/12-totality-vs-let-it-crash.md) — **the two were never opposed; let-it-crash is how you spell partiality.**
- [Compilation target decision](issues/13-compilation-target-decision.md) — **the Erlang Abstract Format**, and the decisive reason is none of the five the ticket had stacked: the choice is a **one-way door, not a rung on a ladder**.
- [Concurrency and the OTP model](issues/14-concurrency-and-otp-model.md) — **the concurrency vocabulary is OTP's, and nothing in it is parameterised by a message type.**
- [Parametric polymorphism](issues/27-parametric-polymorphism.md) — **the language has real parametric polymorphism, and it is the smallest version of it that works.**
- [Error model](issues/15-error-model.md) — **the headline question was already closed and the ticket did not know it**: ticket 12 §3's signature-directed stance means there is no global error-model preference to pick.
- [Ad-hoc polymorphism](issues/16-ad-hoc-polymorphism.md) — **the language gets no ad-hoc polymorphism construct, and the hole ticket 05 flagged was half imaginary.**
- [Pipeline and comprehension idiom](issues/17-pipeline-and-comprehension.md) — **four constructs removed, one added.**
- [Boundary defence](issues/18-boundary-defence.md) — **the eight channels were never eight questions.**
- [Untheorised term shapes](issues/20-untheorised-term-shapes.md) — **the five sightings of "binaries are where precision dies" have one cause, and it is not binaries.**
- [Refinement types in shipping languages: what did ticket 20 reinvent?](issues/29-refinement-type-prior-art.md) — the prior-art pass ticket 20 was resolved without.
- [The walking skeleton, first slice](../compiler/README.md) — **built 2026-08-13, and the premise that delayed it was stale.**
- [What the language owes an agent that writes it](issues/23-what-the-language-owes-an-agent.md) — **the ticket's premise was wrong in the language's favour**: the platform already has three diagnostic channels and beam-sharp inherits all of them, measured in [`23a`](prototypes/23a_otp_diagnostic_channels.sh) — `compile:file/2`'s `{Location, Module, Descriptor}` with prose derived by `format_error/1`, the `abstract_code` chunk carrying the emitted forms verbatim, and `error_info` carrying a structured `cause` at runtime since OTP 24.
- [The testing story](issues/24-testing-story.md) — **exhaustiveness converts coverage tests into value tests; it does not reduce their number**, because 23's clause synthesis adds guessed bodies at the same rate it removes coverage questions.
- [Data modelling: records, and what named types erase to](issues/26-data-modelling.md) — **a record erases to a map, and `record` is sugar for a minted tag — but everything stays structural.**
- [Angle brackets versus less-than](issues/28-generic-bracket-parsing.md) — **the second bullet collapsed the ticket, and its own motivating premise is measured false.**
- [The FFI surface](issues/32-ffi-surface.md) — **a foreign function is declared, and the declaration carries both spellings.**
- **AMENDMENT 2026-08-14 to [ticket 16](issues/16-ad-hoc-polymorphism.md)** — one of its two reasons for refusing protocols was invalidated by ticket 26 and nobody went back.
- **AMENDMENT 2026-08-27 to [16](issues/16-ad-hoc-polymorphism.md) and [27](issues/27-parametric-polymorphism.md)** — both cite a constraint ticket 13 does not contain.
- [Local bindings](issues/34-local-bindings.md) — **the language has them, and their absence was an accident rather than a position.**
- [The body check site](issues/33-body-check-site.md) — **a body is typed; synthesis is total and there was never a cheaper option; checking is containment at five sites; and the residual survives at four of them.**
- **Module and namespace system, and function identity** — [ticket 40](issues/40-module-and-namespace-system.md), resolved 2026-08-15.
- **A span in a clause head is a relational pattern** — [ticket 42](issues/42-interval-pattern-spelling.md), resolved 2026-08-15.
- **One conjunction: `and` / `or`** — [ticket 44](issues/44-conjunction-spelling.md), resolved 2026-08-15, amending [ticket 08](issues/08-head-and-guard-syntax.md).
- [Negation has no spelling](issues/63-negation-has-no-spelling.md) — **there is no `not` and no `!`**, resolved 2026-08-26, completing the territory ticket 44 opened. 44 settled conjunction and disjunction and said nothing about negation, which made this a hole rather than a recorded omission.
- **A match against a bound value is `== name`** — [ticket 45](issues/45-match-token.md), resolved 2026-08-16.
- **An inexhaustive residual truncates at three cases** — [ticket 43](issues/43-residual-summarised-form.md), resolved 2026-08-16.
- **Imports and cross-module scope** — [ticket 41](issues/41-imports-and-cross-module-scope.md), resolved 2026-08-16 across two sessions; §1, §2 and §5 on 08-15, §3 and §4 on 08-16.
- **Binaries as a parsing grammar** — [ticket 30](issues/30-binaries-as-a-parsing-grammar.md), resolved 2026-08-20.
- [A route table needs a closed list pattern, and ticket 08 refused one](issues/53-a-route-table-needs-a-closed-list-pattern.md) — **resolved against its own premise, hours after it was raised, and the correction is the answer.**
- [A record pattern may name its type, and any pattern may take a trailing binder](issues/55-destructure-and-bind.md) — **`Frame { Type: :method } f`, and `Frame f` when only the type matters.**
- [Composable middleware, and what the valve reaches](issues/31-composable-middleware.md) — **`|?>` expresses it, and the gap is one stage-shape rather than a mechanism.**
- [A build and dependency tool, or riding on rebar3 and mix](issues/51-a-build-and-dependency-tool.md) — **beam-sharp builds none of it, and the code-path problem turned out not to exist.**
- [List length in the algebra: a proved-exhaustive program that crashes](issues/54-list-length-in-the-algebra.md) — **the algebra models none of it, because it decomposes the cons cell instead of measuring it.**
- [Division and modulo](issues/38-division-and-modulo.md) — **`/` on two `int`s is truncated integer division and `%` is the remainder it leaves, signed by the dividend** (`-7 / 2` is `-3`, `-7 % 2` is `-1`).
- [A refined parameter gets a boundary guard](issues/46-refined-parameter-at-the-boundary.md) — **yes, and the guard is the part of the refinement the clause does not already prove.**
- **How opinionated is the language** — [ticket 22](issues/22-how-opinionated.md), resolved 2026-08-23, overturning [ticket 23](issues/23-what-the-language-owes-an-agent.md) §7.
- **`ValidateAs`'s pathed error stops at the row** — [ticket 61](issues/61-validateas-path-stops-at-the-row.md), raised by exemplar 25d on 2026-08-24 and resolved the same day; the series' first compiler-defect ticket.
- **"Instantiation is matching, not solving": what is the algorithm?** — [ticket 37](issues/37-instantiation-by-matching.md), the algorithm half resolved 2026-08-28 and the **ordering half left with David**.
- **What the valve keys on: the atom, or the declared type?** — [ticket 49](issues/49-what-the-valve-keys-on.md), raised 2026-08-21 out of 31, resolved 2026-08-28.
- **Does `using` get an alias?** — [ticket 47](issues/47-import-alias.md), resolved 2026-08-31.
- **Stdlib shape as a principle** — [ticket 67](issues/67-stdlib-shape-as-a-principle.md), raised 2026-08-31 by the §19-as-queue rule, resolved 2026-09-03.
- [What name does a behaviour callback emit?](issues/35-behaviour-callback-names.md) — **a fixed table in `bs_otp`, and a module declaring a behaviour it does not satisfy is refused at the declaration.**
- [Is the value assigned to a field checked, and is `with` a sixth site?](issues/36-field-value-obligations.md) — **yes to both, and neither is a sixth site.**
- [A map type in the prelude](issues/48-a-map-type-in-the-prelude.md) — **`map<K, V>` enters the prelude as a second map member kind, declarable but not yet destructurable, with `Map.Get` a compiler-known operation under a reserved qualifier.**
- [Consuming an Elixir library: how is a foreign struct named?](issues/50-naming-a-foreign-struct.md) — **a foreign aggregate gets no name of its own: it is a `map<atom, term>`, and that works with no new surface.**
- [A foreign function returning `(:ok, V) | (:error, R)` as values](issues/56-foreign-value-returned-error.md) — **it is declared as an ordinary union naming its own error payload, and nothing else changes.**
- [A refined `int` parameter admits a float](issues/58-refined-int-admits-a-float.md) — **nothing here needed deciding: ticket 18 §1 rule C decided it on 2026-08-13 and §5 refused an opt-out, so this is one resolved rule missing from `bs_emit`.**
<!-- END GENERATED -->
