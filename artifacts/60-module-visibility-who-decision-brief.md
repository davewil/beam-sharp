# Decision brief — ticket 60: which modules may name this one?

**Ticket** [60](../wayfinder/issues/60-which-modules-may-name-this-one.md) · **Linear** [ENG-242](https://linear.app/davewil/issue/ENG-242) · **Date** 2026-10-23
**Status: DECISION OPEN — for David's review; nothing resolved.** No ticket, feature, glossary or compiler file was edited.

Measured on: OTP 28.5 (erts 16.4, built from source), Elixir 1.19.5, Gleam 1.18.1, Elm 0.19.3, `bsc` built from HEAD `c3d50b9c`, x86_64 Linux.
Sources cited: Gleam compiler `0d9fa18`, Gleam stdlib `13359e5`, elm/core `65cea00` (git clones at depth 1), OTP 28.5 source, Elixir 1.19.5 install.

The ticket says *"not owed a decision soon"*. This brief takes that seriously: one of the three options is "do not build it yet", and it is the recommendation.

---

## The gating question, alone

**Should a module be able to say who may name it, enforced by the compiler — and if so, does the callee say it (by where it lives, or by a header), or does nothing change yet?**

Direction gates the other three sub-decisions in the ticket (unit, marker-vs-construct, checker cost): once the callee is the one naming callers, the unit is a *caller* set, the marker belongs on the module and not a function, and the cost is one more field in the world entry. If the caller declares its dependencies instead, the unit is a callee set and the rule is a project-level list. So ask direction, and let the rest follow.

Here is the program that decides it. `Shop.Orders.Totals.Recompute` has to be `public` because `Shop.Orders` and `Shop.Orders.Fulfil` are different modules (F15: a directory is a module), so `private` cannot serve:

```csharp
// Shop/Orders/Internal/Totals/Totals.bs        (option A: the PATH says "internal")
module Shop.Orders.Internal.Totals
public int Recompute(Order o)
Recompute(o) -> ...

// Billing/Invoice/Invoice.bs                    an outsider
module Billing.Invoice
using Shop.Orders.Internal.Totals     // A: error — Shop.Orders.Internal.Totals may not be named from Billing.Invoice
                                      // B: (header says visible to Shop.Orders) the same error
                                      // C: compiles; Recompute is public, so it is "client API"
```

I built option A and ran exactly this (probe 60d): the outsider is refused with `Invoice.bs:2:1: error: Shop.Internal.Calc may not be named from Billing.Invoice`, `Shop.Orders` and a deeper sibling compile, and the pristine compiler accepts all three.

## Sub-decisions, in dependency order

| # | Sub-decision (ticket's numbering) | Role | Settled by |
|---|---|---|---|
| 1 | **Direction**: callee names who may call, or caller declares what it depends on (ticket Q2) | **gating** | this brief's question |
| 2 | **Unit**: subtree / named group / explicit list (ticket Q1) | following — a subtree falls out of A for free; B can offer all three | 1 |
| 3 | **Marker or separate construct** (ticket Q3) | following — A has no marker at all; B is a module-header clause | 1 |
| 4 | **Checker cost** (ticket Q4) | following — measured below for A; B adds a parser rule | 1 |

"Caller declares" is not offered as an option. Reason, measured: `using` already *is* the caller's declared dependency list, and the compiler refuses a qualified call that skips it (`Billing/Direct.bs:3:31: error: Shop.Internal.Calc is called but never imported`, probe 60d). A caller-side rule can only restrict what a module imports *about itself*; it cannot let a module protect a helper it owns from an unknown consumer, which is the stated need (24 §2). It is a layering policy file, not a visibility feature, and it is a different ticket.

---

## What the platform allows (shared by every option)

**The enforcement point is the caller's compile, and it can only be that.** Evidence:

- **60b** — on the BEAM, a module's exported function is callable from every module (`vis_foreign → vis_lib:plain()` returned `ok`); the control, an unexported function, is `{error,undef}`. There is no "export to some modules".
- **60b (3)** — a callee that tries to enforce at runtime has to read its own stacktrace. Measured: it answers correctly for a genuine non-tail call (`allowed`) and for a foreign caller (`{denied,vis_foreign}`), and **wrongly denies the friend when the friend calls in tail position or writes `R = f(), R`** (`{denied,vis_driver}` — `erlc` compiles that bind-and-return to a tail call, so the frame is gone). Cost: **8.7 ns/call plain vs 419.5 ns/call guarded** (median of 7 runs of 1e6, spread 388–427), roughly 48×.
- This agrees with ticket 18 §1's measurement (*"a BEAM function has one entry label shared by both call kinds"*) and with ticket 60's own "compile-time check on the caller, or nothing".
- **Every `using` edge, and every qualified call, passes through one site.** `add_import/7` (`compiler/src/bs_check.erl:498`) handles `using`; `qualified_module/3` (`bs_check.erl:4569`) requires that a `using` entry exist (comment at `:4567`: *"those entries declare the file's dependencies"*). Types follow the same path (`type_module_not_imported`, `bs_check.erl:447`). The ticket's cited `add_module_import/5` at lines 407–425 has since moved; it is `add_module_import/3` at `:512`.
- **The promise can only be "among B# code".** Gleam's `@internal`/`internal/` modules are still callable from Erlang (60a D: `lib:attr_internal() = 7`, `lib@internal@secret:helper() = 41`). Any B# rule inherits that, and it is the same boundary as ticket 18's *"your types are checked among beam-sharp code"*. Ticket 62 (the outbound ABI) is where foreign callers are handled.

## Neighbours (file:line, re-read before citing)

| Language | Unit | Direction | Enforced? | Evidence |
|---|---|---|---|---|
| **Gleam** | the **package**; a module is internal by path (`<pkg>/internal`, `<pkg>/internal/*`, overridable with `internal_modules` globs in `gleam.toml`) or a *definition* by `@internal` | callee, by path or attribute | **No.** Hidden from docs, autocomplete and the exported interface; still compiles and still runs | `compiler-core/src/config.rs:207` (field), `:291-313` (*"hidden in the docs or not"*, default globs `:306-309`); `compiler-core/src/type_.rs:1028-1030` (*"technically importable by other packages but to do so is violating the contract of the package"*); `type_/environment.rs:1009` (only effect on the checker: suggestions skip it); `ast.rs:822-856` (`Publicity::Internal` still `is_importable`); `changelog/v1.1.md:47-49` (*"hide those definitions from the generated documentation, autocompletions and the exported module interface"*). Stdlib uses it on single functions of public modules: `stdlib/src/gleam/dict.gleam:571-572`. One related enforcement was tried and withdrawn: `changelog/v1.1.md:40` (*"Revert the change that would make the build tool refuse to publish a package that exposes an internal type in its public API"*) |
| **Elixir** | none in the language. `@moduledoc false` / `@doc false` per module / function | callee, advisory | **No.** Documentation metadata only | `lib/elixir/lib/module.ex:322-323` (*"invisible to documentation extraction tools"*). A caller-side check *is* buildable with a compiler tracer: `lib/elixir/lib/code.ex:1758` (`:tracers`), `:155` (`{:remote_function, meta, module, name, arity}` events). The `boundary` library is the known user of that hook; **it is not installed here and is not surveyed** |
| **Erlang/OTP** | none. `-export` is the only gate; `-doc hidden` and EDoc `@hidden`/`@private` are documentation | callee, advisory | No. Tooling only (`xref`, a library, not the language) | `lib/stdlib/src/shell_docs.erl:841-843` (a hidden doc prints *"This probably means that it is internal and not to be used by other applications"*); `lib/edoc/src/edoc_tags.erl:93,95` (`hidden`, `private` tags); `lib/stdlib/src/escript.erl:404` (`-doc hidden.` in use) |
| **Elm** | the **package**: `elm.json` `exposed-modules` lists what dependents may import; any module under `src/` not listed is hidden | callee, in a manifest outside the source | Yes in the real compiler; **not run here** (the package registry is unreachable, so `elm make` stops before compiling — attempted, see Not measured) | `elm/core/elm.json:7` (`exposed-modules`), the module `Elm.JsArray` exists at `src/Elm/JsArray.elm:1` and is absent from that list |
| **C#** | the assembly (`internal`) | callee | yes | **Not surveyed** — no local source. Ticket 60 already records that `internal` means assembly-scoped and B# has no assembly |

Reading: the only surveyed language that enforces who-may-name is Elm, and it does so from a manifest at the package boundary, where the compiler also owns the single door. Gleam, the closest precedent for *spelling* (a path convention plus an attribute), chose not to enforce. Probe 60a measured it: a dependent package imports `lib/internal/secret` and calls an `@internal` function, both exit 0; the control, a non-`pub` function, is refused (`The module lib does not have a really_private value`, exit 1).

---

## Options

### A. The path says so: an `Internal` segment (callee side; unit = the subtree above it; no marker, no syntax)

A module whose dotted path contains a segment `Internal` may be named only from modules under the path before that segment.

```csharp
module Shop.Orders.Internal.Totals          // only Shop.Orders.** may `using` it
```

**Compiler delta (prototype, built and run — probe 60d):** `module_visible(Self, M, L)` called from `add_import` at the `true ->` arm (`bs_check.erl:498-501`), one new error `module_not_visible` with a `built/2` clause and a `message/1` clause in `bs_diag.erl`. **21 lines added, 1 changed** (comments and blanks included), against a copy of `compiler/`; the repo is not touched (`artifacts/probes/60/proto_internal_segment.patch`). No lexer, parser, grammar or world-entry change.

**Measured:** 60d exit codes — `Shop.Orders` 0/0, `Shop.Internal.Deep.Leaf` 0/0, `Billing.Invoice` pristine 0, prototype 1 (the refusal above). Compile wall time, 15 interleaved rounds, median [min..max] ms: `Shop/Reports` pristine 465 [407..548] vs prototype 444 [403..604]; `Shop` 519 [439..665] vs 493 [439..576]. Indistinguishable inside the spread, and the corpus contains no `Internal` segment, so this shows *no regression*, not the cost of a refusal. Isolated: **~760 ns per check** (1e6 calls; one check per `using` line).

**Strongest counterargument:** it reserves a path segment. It is ticket 65's question (reserve a name, or let user names win) arriving by the back door, and ticket 65 says to decide it once while the list is empty. `reserved_qualifiers()` already burns four names (`bs_check.erl:1701`). The repo has no directory named `Internal` today (`find` shows none), so it is cheapest now and dearer after the first user program has one. Second: it is location-as-semantics, and Gleam's own comment concedes the weakness of a convention-only version (see table). Third: Gleam's `internal` is package-scoped and B# has no package, so the borrowed word is a false friend in exactly the sense ticket 60 warns against; the subtree rule is B#'s own meaning, and `Internal` would have to be defined in the glossary as such.

### B. The module header says so (callee side; unit = chosen; a clause on the `module` line)

```csharp
module Shop.Orders.Totals visible Shop.Orders      // hypothetical spelling; any word, or a list, would do
```

**Compiler delta (not built):** a lexer rule and parser arm for the clause, a `visible` field in the world entry (`bs_check.erl:512` reads only `exports`/`types` today), the same check in `add_import`, and a glossary term. Ticket 22 priced a keyword as one lexer rule, one `signature` arm, one `type_decl` arm (22 line 185) and counted it against a *sixteenth* keyword; this one is the seventeenth if the word is new, or reuses `using`/`module` with a modifier at the cost of a second meaning for them.

**Measured:** nothing of its own. The check and its cost are A's (60d); the parser delta is **not measured** because it was not built.

**Strongest counterargument:** two sources of truth. F15 makes the directory the module, so moving a directory renames the module and silently invalidates a hand-written allow-list in the header; A cannot go stale because the path *is* the rule. It also spends grammar for a feature whose demand is unmeasured (below), which ticket 22 refused to do for `incomplete` on the same grounds.

### C. Build nothing yet; record the trigger

`public`/`private` stays the whole story. The one remaining who-question is a helper that must be `public` only so a sibling module can call it. Today such a helper is simply public, and appears in `--api` as part of the module's operations.

**Compiler delta:** none. **Measured evidence that demand is thin (probe 60e, text census, method stated in the script):**

- Compiled corpus (`compiler/examples` minus `exemplars/`): 100 public signatures by independent `grep`; the census regex sees 94 of them (it misses fn-typed and brace-bodied signatures: 6 in `Pricing`, `Discounts`, `Signalbox`, none in a behaviour module). The **one** behaviour module (`Counter`) has 3 public functions, all GenServer callbacks (confirmed by `bsc --api`), so **0 `unclassified`**.
- Exemplars (do not compile yet, so text only; regex and independent count agree at 30 public): 81 signatures, **30 public, 51 explicitly private**. In their 3 behaviour directories: 8 public callbacks, **8 public non-callbacks** (`Consume` ×2, `Decide`, `EncodeAck`, `ByStatus`, `Fetch`, `Summarise`, `Ask`). Those 8 are the candidates ticket 24 §2 worried about; reading their names, they look like client API (`Ask`, `Fetch`), not helpers like `RecomputeTotal`. Not read function by function, so "look like" is a judgement, not a measurement.
- `using` edges that cross a module boundary in the whole corpus: **8** (listed by a `grep` over `using [A-Z]` lines). None is a "public only for siblings" case that I can identify; `Shop.Collections.Ints` is used by `Shop.Reports` (sibling) and, via `Shop.Collections`, by `Pipeline` (outsider), and that second edge is a real consumer of a public function.
- F12 had already removed most of 24 §2's `unclassified` remainder: a helper is private by default now, which is why the exemplars hold 51 private signatures. Ticket 24 §2 was written when *"every function in an aggregate is exported"*.
- The consumer 24 §2 names, the boundary manifest, is not built (`grep -rn "boundary manifest" compiler/src` returns nothing).

**Strongest counterargument:** the reservation window. If `Internal` (or any word) is to be reserved, it costs least while no program uses it, and A shows the feature is a 21-line delta, so deferring saves almost nothing on the compiler and spends the one thing that cannot be recovered: a user's directory named `Internal`. Also the agent-drift argument in the ticket is real and not measured here: nobody has measured how often an agent writing tests picks a helper, and the ticket's point is that it picks the easiest target.

---

## Recommendation

**C now, with A as the pre-costed fallback, and one cheap hedge.** Reasons, in order: the ticket itself says no decision is owed soon; the consumer that would use the answer (the boundary manifest) is unbuilt; F12 already took most of the problem; the corpus shows no instance (0 of 1 compiled behaviour modules, 8 client-API-looking publics among the exemplars); and A is fully measured at 21 lines, so waiting costs little compiler work.

The hedge is the counterargument to C: decide ticket 65 (reserved names) first or together, and in the same stroke say whether `Internal` is on the list. That settles the window without building anything. If David prefers to decide the feature now, **A**, because it is the only one of the three with no grammar, no allow-list to rot, and a measured diff.

**What would change this:** (1) the boundary manifest gets built and `--api` must tell client API from shared helper — then A or B; (2) a real program needs a helper shared across sibling modules; (3) an agent-written test suite is measured targeting public helpers — then move straight to A; (4) the glossary gains a package/assembly notion, which would reopen the unit question (B's explicit list becomes more attractive).

---

## Evidence ledger

| Id | Claim it tests | Control | Result | Does NOT show |
|---|---|---|---|---|
| 60a | Gleam does not enforce `internal` across packages | non-`pub` call from the dependent package | A: internal-module import exit 0; B: `@internal` call exit 0; C control refused, exit 1; D: Erlang calls both; E: package-interface lists only `lib`, `api` | Elm; Gleam on JS target; that Gleam never enforces anything (only these three forms) |
| 60b | BEAM cannot restrict callers; runtime check is costly and tail-call-wrong | unexported function → `undef`; non-tail friend allowed, foreign denied | exported fn callable from anywhere; stack check 8.7 → 419.5 ns/call; wrong on tail calls | any JIT-level mitigation; a caller identity other than the stacktrace (e.g. a token argument) |
| 60c | Elixir `@moduledoc false` prevents nothing; a caller-side check is buildable | `defp` outside: compile **warning** + run-time `UndefinedFunctionError` (not a compile error) | outsider compiled and ran (`42`); docs metadata `:hidden`; tracer refuses outsider (`RESULT: refused`), admits friend (`RESULT: compiled`); 13-line tracer body | the `boundary` library; macro-expanded callers; Mix project builds |
| 60d | A caller-side `Internal` rule is one site and cheap in bsc | pristine accepts all; qualified call without `using` refused by pristine | 21 lines +, 1 −; outsider refused with position and message; wall time inside spread; 760 ns/check | cost of a *refusal path* in the corpus (no `Internal` there); types leaking through a visible signature (not tested); `bsc --api`, ibs, the test suite |
| 60e | Size of the `unclassified` remainder | independent `grep -c '^public '` | exemplars: agree (30); compiled: 100 vs 94, **disagree** (stated, explained, none in a behaviour module) | which of the 8 non-callback publics are helpers (names only, not read) |

Each probe is a script in `artifacts/probes/60/`, with its captured run in `output-60?.txt`. Source `env.sh` from the session scratchpad (`$S/env.sh`) first.

## Not measured / caveats

- **Elm enforcement** — attempted: `ELM_HOME` seeded with `elm/core` from a git clone; `elm make` always asks `package.elm-lang.org` for the registry (403 through the proxy), so the compile never ran. The Elm row rests on `elm.json:7` and `src/Elm/JsArray.elm:1`, plus my knowledge of 0.19, which is not evidence.
- **C#** — not surveyed.
- **Elixir `boundary`**, Erlang `xref` analyses — not installed / not run.
- **Types leaking through a visible module's signature** (an outsider holds a record minted in an `Internal` module without naming it): not tested; Gleam hit this class and handled it at publish time (then withdrew that, `changelog/v1.1.md:40`).
- Wall-time measures are whole-process (`bsc` startup dominates, ~450–520 ms); the in-VM figure is the 760 ns number.
- The prototype is for sizing only; nothing was added to `compiler/`.
- Toolchain: OTP 28.5 is the repo pin; Elixir is 1.19.5, not the version the 62a prototype used (not recorded there).
