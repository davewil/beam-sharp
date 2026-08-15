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
  **THE ARITHMETIC BROKE ON 2026-08-14, exactly as its own caveat warned.** ENG-199 was created for
  the **F3 feature PRD** — a compiler feature, not a wayfinder ticket — so ticket 33 is **ENG-200**
  and everything after it is offset by one. Read the rule as *"00–32 is ENG-(166+NN), from 33 it is
  ENG-(167+NN)"*, and keep **verifying rather than computing**: the compiler's features now raise
  issues in the same team, so the gap will widen again.
- **Execution override**: wayfinder is plan-only by default. This map sanctions execution
  for the **walking skeleton only**. Every other ticket produces a decision.
  **Widened in practice since 2026-08-13**: the skeleton is built and now grows through
  **feature files** in [`compiler/features/`](../compiler/features/README.md) — numbered
  capabilities, each citing the tickets it implements and deciding none, in the feature-driven
  style of [magic-lisp](https://github.com/andrealaforgia/magic-lisp/tree/main/features) (David:
  *"I'm not saying adopt gherkin btw, but a feature driven style"*). **A feature that needs a
  decision raises a ticket rather than making one** — F3 raised ticket 33 that way, which is the
  seam between the two working consistently.
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

  **Amendment — the tiers rank *sources*, not *precedence*** (David, 2026-08-14, ticket 32 follow-on).
  *"I'm not dogmatic about sticking to C# style, if there's a better word I'll use it, if behaviour
  is BEAM native I'll use it."* The worked case is the OTP behaviour declaration: C# offers
  `interface`, a tier-1 borrow that was available and was refused because it carries OOP vocabulary
  the construct does not belong to; `implements` (Roc), `instance` (Haskell) and `use` (Elixir) were
  each refused for a *specific* false friend — `use` in Elixir injects default callback bodies B#
  will never generate, and ticket 23 already settled that the compiler synthesises heads and never
  bodies. The winner is **`behaviour`**, tier 2, chosen because it is the thing's actual name on this
  platform and literally what is emitted. **Read the heuristic as "survey all three tiers, then take
  the most accurate word", not "take the highest tier that fits"** — the ordering exists to stop
  gratuitous invention, not to make C# win ties it should lose.

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


---

## How to read the rest of this map

**Split 2026-08-15**, on David's *"map.md is getting pretty large, any way to shrink it to
headlines, tags, easily searchable sub-entries?"* It was 1,564 lines and 139KB, and `CLAUDE.md`
tells every session to read it before starting work — so the size was a cost paid on every
session, human and agent alike.

The cause was a contract the file states and had stopped keeping. Its own comment said **"one line
per closed ticket: enough to judge relevance, then open the ticket for detail"**, and entries had
reached 127 lines. Nothing gated it, which is the same failure as the exemplars' dead dialect and
`LANGUAGE.md`'s prose claiming `true` was shipped.

**Nothing was deleted.** The three archive sections moved out whole, verified to reconstruct the
original byte-for-byte, and what remains here is the index they always should have had:

| File | What it holds | Lines |
|---|---|---|
| [`decisions.md`](decisions.md) | the body of every closed ticket's entry | ~800 |
| [`fog.md`](fog.md) | the body of every open patch | ~450 |
| [`scope.md`](scope.md) | the four boundaries, audited | ~176 |

**How to find a thing.** Every entry below carries its ticket number and topic tags, so
`grep -n 'records' wayfinder/map.md` narrows to a handful, and the title then greps straight into
the body file: `grep -n 'Data modelling' wayfinder/decisions.md`. Tags are a small vocabulary on
purpose — `types syntax patterns records generics otp ffi codegen modules binaries errors agent
tooling` — and a tag is not a claim, only a way in.

---

## Decisions so far — index

Bodies in [`decisions.md`](decisions.md). Ticket text in `issues/`.

- **Charting: differentiator, typing stance, scope** `#00` `agent`
  the differentiator is multi-clause heads; typing is set-theoretic with enforced exhaustiveness
- **Prior art: static types plus multi-clause heads** `#03` `types`
  Gleam never rejected them, it never considered them; projects stall on commercial dependency
- **Audit of `purescript-backend-erl`** `#19` `codegen`
  retracts a headline claim of ticket 02 — read before trusting 02 on Core Erlang
- **A page of idiomatic beam-sharp** `#01` `syntax`
  Variant A: equations under a signature, name repeated on every clause
- **Escape-hatch precedents** `#21` `types` `agent`
  the mechanism that works is the one the tool that already builds the code runs
- **Head and guard syntax** `#08` `syntax` `patterns`
  `&&`/`||` over Erlang's `,`/`;`; prefix-plus-rest is the only list pattern
- **Compilation targets** `#02` `codegen`
  superseded in part by `#19` — see the audit before citing it
- **Cross-clause exhaustiveness** `#04` `types` `patterns`
  the residual IS the missing case; a signature is mandatory or the question is ill-posed
- **Erlang/Elixir interop surface** `#06` `ffi` `otp`
  a behaviour needs no `-behaviour` attribute to work
- **C# 15 `union` and TypeScript discriminated unions** `#07` `types`
  C#'s non-exhaustive switch only warns; this language makes it an error
- **Union representation** `#09` `types`
  `type X = ...` is the single naming construct; the name never enters the algebra
- **C# functional feature inventory** `#05` `syntax`
  what is portable from C#, what is subsumed by moving patterns into the parameter position
- **Atoms in a C# skin** `#10` `types` `syntax`
  `:name`, the universe is open, nothing declares an atom
- **Type system shape and the `dynamic` boundary** `#11` `types`
  static by default; a foreign value must be matched rather than assumed
- **Totality versus let-it-crash** `#12` `types` `patterns`
  exhaustiveness is a hard error; a catch-all is legal only over an *open* residual
- **Compilation target decision** `#13` `codegen`
  Erlang Abstract Format, emitted as serialised text; the frontend holds no compiler state
- **Concurrency and the OTP model** `#14` `otp`
  behaviour contracts and system-message shapes are types the compiler knows
- **Parametric polymorphism** `#27` `generics` `types` `built:F6`
  substitution with ground arguments — the variable is gone before the algebra sees it
- **Error model** `#15` `errors`
  `option<T>` collapse is an error at the declaration, not at the use
- **Ad-hoc polymorphism** `#16` `types`
  `==` means `=:=`; open protocols refused once records landed
- **Pipeline and comprehension idiom** `#17` `syntax` `built:F7`
  `|>` and `|?>`; `switch` is the only branching construct, and there is no `if`
- **Boundary defence** `#18` `codegen` `ffi`
  a two-tier emitted boundary; precision is a privilege of what the compiler inlines
- **Untheorised term shapes** `#20` `types` `binaries` `part-built:F9`
  the union is exact and integer intervals are in the algebra; nothing widens.
  §§2–5 built as **values** — `string` is `binary` refined by UTF-8, a literal is one by
  construction, the boundary takes the base type only. Binaries as a *parsing grammar* wait on `#30`
- **Refinement types in shipping languages** `#29` `types`
  what ticket 20 reinvented, and what it did not
- **The walking skeleton, first slice** `compiler/` `codegen` `built:F1`
  built 2026-08-13 — see [`compiler/README.md`](../compiler/README.md)
- **What the language owes an agent that writes it** `#23` `agent` `tooling`
  the compiler as interlocutor rather than only a gate; `bsc --api` is decided and unbuilt
- **The testing story** `#24` `agent`
  what a test is for in a language that proves exhaustiveness
- **Data modelling: records** `#26` `records` `types` `built:F3`
  a record erases to a map carrying a tag minted from its **qualified** name
- **Angle brackets versus less-than** `#28` `syntax` `generics` `built:F6`
  in type position the bracket is unambiguous; value position stays comparison
- **The FFI surface** `#32` `ffi` `built:F1`
  a module IS an atom, so `using :ets { … }` and the call site is `:ets.lookup(t, k)`
- **Local bindings** `#34` `syntax` `built:F4`
  a body is bindings then one expression; rebinding is an error
- **The body check site** `#33` `types` `built:F5`
  a body is typed; checking is containment at five sites, and the residual survives at four
- **Behaviour callback names** `#35` `otp` `codegen` `built:F10`
  a compiler-known table, contract-scoped and keyed by name *and* arity; the name changes, no
  wrapper, and a behaviour without its mandatory callbacks is an error at the declaration

---

## Not yet specified — index

Bodies in [`fog.md`](fog.md). These are open: read the body before assuming a direction.

- **The boundary manifest's concrete format** `#24` `agent` `tooling`
  one artefact, not three — the classification, the advisory and the elision list
- **The walking skeleton** `codegen`
  which slice, and what language the compiler is written in. First slice built; two debts struck
- **The typed model of OTP itself** `#14` `otp` `types`
  which behaviours ship built in, and how a user declares one
- **Module and namespace system**, and function identity `modules` `codegen`
  BEAM identifies by name *and* arity, which multi-clause heads disturb. **Four other patches wait on this one**
- **The language's name** `naming`
  unresolved. `beam-sharp` is a working title
- **Imports and cross-module scope** `modules`
  if a directory is a module, what do files in it share automatically?
- **Where DDD invariants live** `types` `errors`
  ticket 20 §5 settles half; refinement in type declarations is available where the predicate is decidable
- **How a user-declared opaque refinement is checked** `#29` `types`
  three owed items, recorded in full on ticket 20 §5
- **Stdlib shape as a principle** `modules` `prelude`
  breadth is out of scope, the shape is not — and the prelude already has known contents
- **Consuming Gleam and Elixir libraries** `ffi` `modules`
  possible, and at what ergonomic cost; Gleam's representation was measured rather than read
- **Laziness and `stream<T>`** `#17` `types`
  **deferred rather than refused** — David: *"defer lazy, we will want it"*
- **Bootstrapping — how much of beam-sharp is written in beam-sharp** `codegen` `agent`
  three axes, and the map has nothing on any of them
- **Division and modulo** `#38` `syntax` `types`
  no `/` in the lexer at all — absent by oversight; truncation converges, divide-by-zero does not
- **`cond`, or whatever serves a long ladder of unrelated conditions** `#17` `syntax`
  no case for it yet; the width-five evidence was retracted and 25a's ladder is now a valve chain

---

## Out of scope — index

Bodies in [`scope.md`](scope.md), **audited 2026-08-15**. The headline result: none of the four is
a refusal. They are boundaries on *this effort*, three waiting on a use case and one on demand.

- **BOUNDARY — Tooling and ecosystem** `tooling`
  the multi-year *track* is out; a capability the language owes its author is not
- **BOUNDARY — Standard library breadth** `modules` `prelude`
  a library designed module-by-module is out; the prelude is in, and always was
- **BOUNDARY — Macros and metaprogramming** `codegen`
  a *maybe*, not a refusal — open if a use case arrives that nothing else serves
- **BOUNDARY (demand) — Alternative runtimes and backends** `codegen`
  out unless the project gains traction and is asked; what a requester inherits is recorded there
