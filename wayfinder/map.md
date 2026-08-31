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
  research files, prototypes. Map is [ENG-165](https://linear.app/davewil/issue/ENG-165).
  Resolving a ticket means updating *both*: the answer here, the state there.
  **THERE IS NO TICKET-NUMBER FORMULA — query Linear for the id every time.** *(This bullet asserted
  `ENG-(166+NN)` two lines above the sentence denying it until 2026-08-26.)* It broke on 2026-08-14
  because the compiler's **features** raise issues in the same team, and has drifted at every check
  since — `+166` at the start, `+190` by ticket 65. Also **not every ticket is a child of ENG-165**:
  36 onwards hang off the *project*, so that query under-counts.
  **The two rules the drift produced, which are the part worth keeping:**
  - **Raising a ticket means writing the repo file AND creating the issue** — the same both-not-one
    rule as resolving. Tickets 38 and 39 once existed as repo files with no issue at all, which the
    contract says cannot happen: Linear owns state, so a ticket with no issue has nowhere to hold
    any. Backfilled as ENG-210 and ENG-211 after auditing all 42 repo tickets.
  - **A feature file naming a decision it needs IS raising a ticket**, and it is not raised until
    both exist. Tickets 42 and 43 sat *named as owed* inside `F2` for a day, so the compiler's queue
    held two blockers no query could see — and `F2` itself had no issue, so two markdown files could
    disagree about whether it was takeable with nothing to arbitrate. **This recurred on 2026-08-22**:
    ticket 55 had been owed by the exemplar README *and* by `LANGUAGE.md` for nine days, each
    recording it independently, neither raising it.
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
  - **Enforced conventions are guardrails on the agent** — but 22 resolved that the guardrails
    which actually catch agent drift are architecture-neutral and structural (F3, F11, F15).
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
headlines, tags, easily searchable sub-entries?"* The bodies moved out whole and verified
byte-for-byte to [`decisions.md`](decisions.md) (closed tickets), [`fog.md`](fog.md) (open
patches) and [`scope.md`](scope.md) (the four boundaries); `bin/check-map.sh` gates the rest.

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
- **Pipeline and comprehension idiom** `#17` `syntax` `built:F7,F14`
  `|>` and `|?>`; `switch` is the only branching construct, and there is no `if`.
  The prelude the pipe is usually shown with is ticket 18's and is NOT built
- **Boundary defence** `#18` `codegen` `ffi`
  a two-tier emitted boundary; precision is a privilege of what the compiler inlines
- **Untheorised term shapes** `#20` `types` `binaries` `part-built:F9`
  union exact, integer intervals in the algebra, nothing widens; §§2–5 built as **values**, and §2's size grammar was never built — `#30` left it with no consumer
- **Refinement types in shipping languages** `#29` `types`
  what ticket 20 reinvented, and what it did not
- **The walking skeleton, first slice** `compiler/` `codegen` `built:F1`
  built 2026-08-13 — see [`compiler/README.md`](../compiler/README.md)
- **What the language owes an agent that writes it** `#23` `agent` `tooling` `built:F17`
  the compiler as interlocutor; `bsc --api` is built (**F17**). §7's legal stub is **overturned** by 22
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
- **The body check site** `#33` `#36` `types` `records` `built:F5,F21`
  a body is typed; containment at five sites, residual survives at four, still no sixth. Site 2 is *field assignment*: `Order{ Id = :oops }` and `o with { … }` both check
- **Module and namespace system, and function identity** `#40` `modules` `codegen` `syntax` `built:F11,F15,F12`
  the atom is **forced** by 26's tag mint — full dotted path. Arity overloading is real, the directory half is built, and `public`/`private` (**F12**) closes §3
- **Imports and cross-module scope** `#41` `modules` `codegen` `built:F11,F15`
  `using` imports **unqualified**; a namespace is a directory holding no `.bs` files. The compiler
  owns the dependency graph — *"single-file"* was false, and §1's own grammar delta was too. §4/§5's
  checks are built and §3's source root is `--src-root`; **two wordings drifted, F15 settled neither**
- **Behaviour callback names** `#35` `otp` `codegen` `built:F10`
  a compiler-known table, contract-scoped and keyed by name *and* arity; the name changes, no
  wrapper, and a behaviour without its mandatory callbacks is an error at the declaration
- **A span in a clause head is a relational pattern** `#42` `syntax` `patterns` `types`
  `4..7` refused — C#'s `..` is a half-open *index* slice that already means "the rest" in pattern
  position. Spans are `>= 4 and <= 7`; borrow the construct, or don't borrow the glyph
- **One conjunction: `and` / `or`** `#44` `syntax` `patterns` `agent`
  amends 08; `&&`/`||` **removed**, not aliased. Erlang's `and`/`andalso` difference is
  unobservable in a guard — so 42's rule is shown permitting, not only forbidding
- **A match against a bound value is `== name`** `#45` `syntax` `patterns`
  the equality member of 42's relational family; one grammar rule, **no lexer change**. `>= acc` and
  `== 4` are clean-but-refused, so neither arrives as a side effect
- **An inexhaustive residual truncates at three cases** `#43` `errors` `agent` `tooling`
  the prose is the exact form with a stop in it, not a second shape — so no format switch and no
  tunable. The term keeps all of it. Complement and cardinality measured and refused
- **Binaries as a parsing grammar** `#30` `binaries` `types` `patterns` `built:F13`
  no type-language structure; a segment's **width** refines what it binds — `t:8` is an `Octet`.
  **Beyond all four languages surveyed** and it did not bite; F13 corrected two of its costs
- **A build and dependency tool, or riding on rebar3 and mix** `#51` `ffi` `tooling`
  **none is built** — `ERL_LIBS` already reaches Req with a zero compiler delta, and rebar3 is the
  neighbour to prefer since `bsc` is one. Elixir is a per-*project* dependency; provenance → `#52`
- **A route table needs a closed list pattern, and ticket 08 refused one** `#53` `syntax` `patterns`
  resolved **against itself**: a rest is a pattern, so `["orders", id, ..[]]` was always legal — and
  measuring that found `#54`, which is worse than the question was
- **A record pattern may name its type, and any pattern may take a trailing binder** `#55` `syntax`
  `patterns` — `Frame { Type: :method } f`, and `Frame f` for the whole value. Survey **unanimous**:
  all four neighbours name the type, beam-sharp alone could not. `as` and `=` are both already
  spent, so the binder is C#'s bare designation. Four grammar variants, **zero yecc conflicts**
- **Composable middleware, and what the valve reaches** `#31` `syntax` `patterns` `errors`
  yes — a terminal stage that always halts makes the unwrap **one clause**, which neither neighbour
  can state. The cost is the atom: a `200 OK` spelled `(:error, _)`; `|?>` refuses `option<T>` (→ 49)
- **Division and modulo** `#38` `syntax` `types`
  `/` on two `int`s truncates, `%` is the remainder; **no precondition** — only a provably zero divisor is refused
- **A map type in the prelude** `#48` `types` `prelude`
  **`map<K, V>` ships**, `Kind` absent only, type before pattern form, operations qualified under a reserved `Map`
- **A refined parameter gets a boundary guard** `#46` `codegen` `types`
  yes, exported only — and it is **subtraction, not a flag**: 6 of `wire.bs`'s 11 clauses get nothing
- **How opinionated is the language** `#22` `agent` `errors`
  **no incomplete marker**, so a clause-less signature stays a hard error and no keyword is spent; the domain arm is dead and 23 §7 is **overturned**
- **`ValidateAs`'s pathed error stops at the row** `#61` `errors` `types` `tooling`
  one absorption defect: `t_absorb` kept `X | X` and dropped mutual equals — an antichain fix restores the `"(N)"` descent, and the exact top prints `term`

## Not yet specified — index

Bodies in [`fog.md`](fog.md) — except where an entry has none, and then the ticket in `issues/` is
the body. These are open: read the body before assuming a direction.

- **A refined `int` parameter admits a float** `#58` `codegen` `types`
  **`is_integer/1` in the exported head unless the pattern pins the kind** — 18 §1(b), decided and never emitted. A range subtraction does NOT fix it: `100.5` reaches `>= 9` and `=< 255` is true. **Built, F24**
- **The boundary manifest's concrete format** `#24` `agent` `tooling`
  one artefact, not three — the classification, the advisory and the elision list
- **The walking skeleton** `codegen`
  which slice, and what language the compiler is written in. First slice built; two debts struck
- **The typed model of OTP itself** `#14` `otp` `types`
  which behaviours ship built in, and how a user declares one
- **A refinement cannot say `-5`** `#57` `types` `syntax`
  refused, though the same literal in a *pattern* reads fine — half of every signed domain is unnameable
- **The language's name** `naming` <!-- tracked by ENG-280 -->
  unresolved. `beam-sharp` is a working title
- **Does `using` get an alias?** `#47` `modules` `syntax`
  §2 inverted the argument that shelved it; may be the only spelling when two imports collide
- **Where DDD invariants live** `types` `errors`
  ticket 20 §5 settles half; refinement in type declarations is available where the predicate is decidable
- **How a user-declared opaque refinement is actually checked** `#29` `types`
  three owed items, recorded in full on ticket 20 §5
- **Stdlib shape as a principle** `modules` `prelude` <!-- tracked by ENG-281 -->
  breadth is out of scope, the shape is not — and the prelude already has known contents
- **Interop with Gleam and Elixir, both directions** `ffi` `modules`
  inbound `#50`: **answered by 48** — `Kind`-absent-only makes a foreign struct a `map<atom, term>`. outbound `#62`: Elixir cannot call a PascalCase export, and the tag is a required ABI
- **Laziness and `stream<T>`** `#17` `types` <!-- tracked by ENG-283 -->
  **deferred rather than refused** — David: *"defer lazy, we will want it"*
- **Bootstrapping — how much of beam-sharp is written in beam-sharp** `codegen` `agent` <!-- tracked by ENG-284 -->
  three axes, and the map has nothing on any of them
- **Emitted code quality, and where the ceiling is** `#39` `codegen`
  20% slower on a tight loop while emitting **identical instructions**; a dead heat once the
  runtime dominates. The question is why it is not *ahead* — it discards intervals at emission
- **What the valve keys on: the atom, or the declared type?** `#49` `syntax` `types`
  **resolved: the fixed pair `(:error, _) | :nothing`**. Shape B refused on measurement — a residual
  can be **unguardable** (`binary \ string`), so 09's "one guard in O(1)" does not hold. `:nothing`
  is null's analogue and **17 §4 is overruled**. Not built — **F30** spec'd 2026-08-30 (ENG-279)
- **Dependency provenance: what a `.bs` file says about what it needs** `#52` `ffi` `tooling`
  51 left it: `using :'Elixir.Req'` names the *module*, never the *application*, so dependencies live
  only in the environment that built them. The FFI declaration may already be the home
- **A value-returned foreign error has no declared form** `#56` `ffi` `errors` `types`
  **the payload `foreign_error` asks for the wrapper, not the tag `:error`** — so `(:ok,B)|(:error,R)` is an ordinary union and needs no new syntax. F19 §2 reversed, its debt sentence deleted. **Built, F23**
- **Failure types collapse at `term`** `#64` `types` `prelude`
  `option<term>` and `result<term, E>` normalise to bare `term`; a lookup cannot report absent
- **Reserved names: the policy, not one name at a time** `#65` `modules` `syntax`
  48 reserved `Map` and B# reserves nothing else; five languages learned "user names win"
- **Negation has no spelling** `#63` `syntax` `patterns`
  **refused: no `not`, no `!`** — the guard fragment is already closed under complement, so it adds nothing.
  The absence teaches, naming the comparison to write. `not` stays an identifier — that is 65. **Built, F27**
- **`cond`, or whatever serves a long ladder of unrelated conditions** `#17` `syntax` <!-- tracked by ENG-282 -->
  no case for it yet; the width-five evidence was retracted and 25a's ladder is now a valve chain
- **List length in the algebra: a proved-exhaustive program that crashes** `#54` `types` `patterns`
  **decompose the cons, never measure it** — Gleam's answer; Elixir's set-theoretic types share the hole. Rest is a marker, `[a, b]` exactly-two, `..[]` retired: 08 amended, 53 answered. **Built, F20**
- **The boundary guard applies two rules with different scopes** `#59` `codegen` `types`
  the record tag test is emitted on **private** functions and F24's `is_integer` is exported-only per 18 §4. 46 measured it and left it. Which scope governs both?
- **"Instantiation is matching, not solving": what is the algorithm?** `#37` `types` `generics`
  **Algorithm resolved 2026-08-28**: solve least per occurrence, join across them, then contain.
  Least because the *return type* chooses, not soundness. **The ordering — build §(c) now? — is David's**
- **Exemplar programs the design must serve** `#25` `agent` `tooling`
  a standing test suite for the design, not one session's work. Five of six written (25a–25e); 25e
  is the first stopped by the **checker** — `iodata` is recursive and 09's binder is unbuilt
- **Which modules may name this one?** `#60` `modules`
  `public`/`private` shipped the *what* half as F12; the *who* half has no spelling. Split from 22.
  Do not borrow C#'s `internal` — it is assembly-scoped and this language has no assembly

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
