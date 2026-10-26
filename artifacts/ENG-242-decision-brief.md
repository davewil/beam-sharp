# Ticket 60 (ENG-242) — Which modules may name this one? Decision brief

**Status of this document:** evidence for a decision. Nothing is resolved, claimed or committed.
Probes: `artifacts/probes/ENG-242/` (`run-all.sh` re-runs everything). Ticket:
`wayfinder/issues/60-which-modules-may-name-this-one.md`.

## What could and could not be executed here

| Tool | State | Consequence |
|---|---|---|
| Erlang/OTP 25 | installed, run | P1–P3 are real runs. The repo pins OTP 28. |
| Elixir 1.14 | installed, run | tracer, `mix xref`, timing are real runs. |
| Elm 0.19.1 | installed, **cannot run a build** | the package registry returns 403 from the egress policy (`elm/run.out`). No Elm behaviour is claimed. |
| Gleam | **not installed** | only its compiler *source* was read as text (never run). |
| `bsc` | **not built** | needs OTP 26+. Every claim about `bsc` below is "cited from repo, not re-executed", with file:line. |

## Two things the repo already says that change what this ticket is for

1. **Ticket 24 §2's "consumer waiting" predates F12.** 24 §2 (`24-testing-story.md:~225`) says
   *"every function in an aggregate is exported today"* and parks `RecomputeTotal/1` as `unclassified`.
   F12 (2026-08-17) then made an unmarked signature **private**, and a call to a private function from
   another module is refused: `private_callee/3` at `bs_check.erl:4470`, reported at `:3850` and `:4391`
   as `private_function`. So an unmarked `RecomputeTotal` is already unreachable from a test in another
   module. (Cited, not re-executed. If tests live in the same directory, private is visible to them,
   which is ticket 24's open "where tests live" and not this ticket's.) What is left for 60 is a
   **public** function that sibling modules need and outsiders should not name.
2. **`using` is already the single chokepoint.** A call or type name from a module not in the file's
   `using` list is refused (`module_not_imported`, `type_module_not_imported`; `bs_diag.erl:555,669`;
   ticket 41 §1). Both functions and record/type names cross by `using` (F44). So a who-may-name check
   placed where `using` is resolved, `add_import/7` (`bs_check.erl:495`, which already receives
   `Self`), sees every B# reference to a module, functions and types alike, with no call-site walk.

**Prior decisions this must not contradict (grepped `wayfinder/issues/` for internal / friend / visible / namespace):**
nothing decides who may name a module. Binding constraints: 22 (do not borrow C# `internal`'s
spelling without its semantics; enforcement is "compile-time visibility over beam-sharp source only");
18 §1 (BEAM elision is exported-vs-local, one entry label, so the emitter cannot enforce it); 22's
resolution (no new keyword was spent on an incomplete marker, so keyword budget is a live concern);
F15 (a directory with `.bs` files is a module, modules may nest: `Shop` is a module holding module
`Shop.Billing`; a directory with only directories is an erased namespace); CONTEXT.md has no entry for
this concept yet.

## Sub-decisions, in the order they gate each other

The ticket lists four: unit, direction, marker-vs-construct, checker cost. **Direction gates the rest**
(if no declaration points at a callee, "unit" and "marker" have nothing to be about), so it is asked
first and alone. Checker cost is not a decision; it is the compiler delta under each answer.

---

### Q1 (gating). Who writes the rule: the module being named, the module doing the naming, or nobody?

**Callee names its audience.** `Shop/Pricing/index.bs`:

```csharp
module Shop.Pricing
visible to Shop.Checkout          // placeholder spelling; spelling is not the question

// Shop/Checkout/Cart.bs      using Shop.Pricing     → compiles
// Shop/Billing/Billing.bs    using Shop.Pricing     → refused
Billing.bs:14:7: error: `Shop.Pricing` may not be named from `Shop.Billing`
  Shop/Pricing/index.bs:2 lets only Shop.Checkout name it.
```

Compiler delta: one World-entry key `visible_to` beside `private` (`bsc.erl:239`, where
`private => bs_check:private_of(Decls)` is built); one clause in `add_import/7` that compares `Self`
with the callee's entry; one `built/2` and one `message/1` clause modelled on `unknown_module`
(`bs_diag.erl:665`, `:2090`); one parser rule beside `module_decl` (`bs_parser.yrl:192`).

**Caller names its reach.** `Shop/Billing/index.bs`:

```csharp
module Shop.Billing
may use Shop.Rows, Shop.Collections

// Billing.bs   using Shop.Pricing   → refused:
Billing.bs:14:7: error: `Shop.Billing` declares it may use only Shop.Rows, Shop.Collections
```

Compiler delta: the same check mirrored. Evidence against: the `using` lines **are** the caller's
dependency list (`bs_diag.erl:2095`, ticket 41 §1), so a second list on the same module restates
what the first already proves, and the check can never fail except by someone editing two lists.
It becomes new information only if entries are *patterns* (a layering rule: "Billing may use any
`Shop.Core.*`"), which is a different, larger feature (architecture rules) that this ticket did not ask for.

**Nobody; no construct.** A repo-level check outside the language. Measured (P2, P4): on the BEAM
a caller whitelist is 11 non-comment lines of escript over `xref` and runs in 0.19–0.23 s on three
modules; in Elixir it is a 21-line compile tracer that reported
`billing.ex:3: error: Shop.Billing may not name Shop.Orders.Internal (only Shop.Orders.* may)` and
exited 1 (`ex/tracer3.out`). Strongest counterargument to doing it: CLAUDE.md rules that a gate guards
the language or the handoff, and a check living outside `bsc` is invisible to the clean-room handoff
(an implementer of B# cannot agree with it, because it is not part of B#).

**Corpus measurement — CORRECTED after verification.** The committed probe P5 (`p5_corpus_audiences.out`)
reported "35 modules, exactly 3 named, each by one caller, no module has two callers". **That is wrong and
is withdrawn**: the script takes a directory's module to be the first `module` line in any of its files and
drops self-edges, but `compiler/examples/exemplars/25g-jev-server/` holds two modules (`Jev`, `Triage`) in
one directory, and 25a–25d have no `module` line so the script invented four names. An independent recount
(every `*.bs` under `compiler/examples`, 75 files; module = distinct `module X` declaration; `using Uident…`
at line start; foreign `using :atom` excluded): 32 declared modules. In the **compiling** examples, 28
modules and 2 named (`Shop`←`Shop.Billing`, `Shop.Collections.Ints`←`Shop.Reports`), one caller each.
Including the exemplars (which are headed "does not parse today", and 25g's layout violates F15's
module-path rule): 4 named, and **`Support.Triage` has two callers** (`Jev` and `Triage`, `jev_index.bs:15`
and `triage_index.bs:15`) — a hierarchy-crossing case. `Shop.Collections` is a namespace named by two
modules; `Shop.Orders` (named by 25a) exists nowhere. So the corpus gives **little signal either way** — 2
named modules in the compiling set — and is not an argument for holding the build.

**Strongest counterargument to callee-side:** the owner must name its callers, so renaming or
splitting `Shop.Checkout` edits `Shop.Pricing`'s `index.bs`: coupling points from the stable thing
to the volatile one. Caller-side ("layering") scales better to large trees; this is the reason
Boundary-style tools work from the caller. (Named for vocabulary only; not executed here.)

**Recommendation:** callee names its audience, at module level, in `index.bs`. It is the only answer
whose refusal carries information `using` does not. Whether to build now or wait is a **separate
call the evidence does not settle**: the original corpus argument for waiting was a miscount (see the corrected
corpus measurement), and the corrected recount is too thin either way (2 named modules in the compiling set;
`Support.Triage` has two callers only in non-compiling exemplars). Deciding the shape now is cheap and
leaves no hole where 22 left one.

---

### Q2 (follows Q1 = callee). What does an entry name: exactly one module, or a path and everything under it?

Real tree: `Shop` is a module; `Shop.Checkout` would be a module with a child module `Shop.Checkout.Promo`.

```csharp
// Shop/Pricing/index.bs
module Shop.Pricing
visible to Shop.Checkout

// Shop/Checkout/Promo/Promo.bs
module Shop.Checkout.Promo
using Shop.Pricing
//  entry = path and descendants   → compiles
//  entry = exactly one module     → Promo.bs:2:7: error: `Shop.Pricing` may not be named from
//                                   `Shop.Checkout.Promo`; Shop/Pricing/index.bs:2 lists Shop.Checkout only.
```

An entry that names a **namespace** (`visible to Shop.Collections`; no atom, erased) can only mean the
path-and-descendants reading, and `add_import` already resolves such names with `children/2`
(`bs_check.erl:587`). With "exactly one", a namespace entry is either an error or a second meaning.
An entry naming neither a module nor a namespace should reuse `unknown_module` (`bs_diag.erl:2090`).

**Strongest counterargument to path-and-descendants:** admission is by spelling. An agent (the
ticket's stated hazard is agent-written trees) that adds `Shop/Checkout/Anything/` gains access to
`Shop.Pricing` silently, and nothing in `Shop.Pricing` changed. Exact-module lists make every new
caller a visible edit to the callee. Cost of exact: one list entry per caller module, which is the
maintenance burden counted in Q1.

**Recommendation:** path-and-descendants, one rule for module and namespace entries. The counterargument
is real; the mitigation is that the diagnostic names the declaring line, so the widening is
discoverable. Say so in the spec.

---

### Q3 (follows Q1 = callee). A marker on each signature, or one declaration per module?

```csharp
// per signature: audience repeated in every function file
// Shop/Pricing/Recompute.bs
public(Shop.Checkout) int Recompute(Order o)
// Shop/Pricing/Total.bs
public int Total(Order o)                      // forgot: this one is open to everyone

// per module: one place, in index.bs
module Shop.Pricing
visible to Shop.Checkout
```

Evidence: the layout puts **one function per file** (F15), so a per-signature audience is repeated
across files in a module with no check that siblings agree; the ticket's own worry about "a rule about
modules" not belonging on a function. And **types cannot carry it**: record and type names cross `using`
(F44, `examples/Shop/Billing/Billing.bs` uses `Order` and `Doc` unqualified), and a `record` has no
signature to mark. A per-signature marker leaves `Shop.Pricing`'s types nameable by anyone who may name
the module at all, so the rule would cover functions and not the data they take. `index.bs` already holds
exactly the module-level declarations (`module`, `using`, `type`, `record`, `behaviour`; no functions;
`bs_check.erl:210`), so one more fits where its siblings live.

**Strongest counterargument to per-module:** it is coarse. One module cannot expose a client API to
everyone and a helper to a sibling. The remedy is to split it into two modules, which in this layout is a
directory plus an `index.bs`; whether that is cheap enough was not measured here.

Neither answer borrows C#'s `internal` (22's rule): `visible to` is a placeholder and the keyword budget
(22) means a contextual spelling should be preferred; that is a separate, later question.

**Recommendation:** one declaration per module, in `index.bs`, refused anywhere else (same shape as
`no_function_in_index`, inverted).

---

### Q4. What does enforcement cover? (the compiler delta and the escapes)

Work, concretely (all cited from the repo, **not re-executed; no `bsc` build here**):

| Piece | Where | Size (my estimate, unmeasured) |
|---|---|---|
| Parse `visible to <modpath>[, …]` | `bs_parser.yrl`, beside `module_decl` :192 | 1–2 rules |
| Carry it into the dependent's World entry | `bsc.erl:226-239` | 1 map key |
| Refuse at `using` | `bs_check.erl:495` `add_import/7`, `Self` already in scope | one clause |
| Skip in `--api` / lenient mode | same function's `Mode` | follows `unknown_module` |
| Diagnostic + JSON tag | `bs_diag.erl` `built/2` :665 and `message/1` :2090 | two clauses |
| Declaration only in `index.bs` | next to `no_function_in_index` `bs_check.erl:210` | one clause |
| Tests, per CLAUDE.md written first | one scenario per refusal and one per allowed path | — |

**What escapes, each probed or flagged:**

- *Any caller outside B# source.* P1: an Erlang module called an exported function of another through
  `apply(M, secret, [])` with `M` built at run time and got `secret_value`; the BEAM has nothing to
  restrict. This confirms 18 §1 / 22: compile-time on the caller is the only enforcement point, and it
  covers B# sources only.
- *What a static caller check cannot see.* P2: `xref` reported the computed-module call as unresolved
  (`{'$M_EXPR',recompute,1}`) rather than as a violation; P4: the Elixir tracer reported the aliased call
  and missed `apply(Module.concat([...]), …)`. Whether B# can spell a computed-module call at all was
  **not checked**.
- *Unverified and must be a test scenario:* the foreign form `using :'Shop.Pricing' { … }` names an
  arbitrary atom (`bs_parser.yrl` foreign using; ticket 32). Whether it can be pointed at a B# module and
  so bypass `add_import`'s check was **not executed**.
- *Values flow out regardless.* A restricted module's records travel through the public functions of
  allowed modules; naming is restricted, not reachability of the value. (Reasoned from F44/F3, not run.)

**Measured cost of the cheapest external alternative (P4, `ex/time200.out` and the repeat in `run-all.out`):**
200 generated modules, 8 alternating runs per condition, Elixir 1.14. Run 1: plain min 2216 / median 2829.5 ms,
traced min 2240 / median 2479 ms (traced faster). Run 2 (repeat): plain min 1967 / median 2444.5 ms, traced min
2182 / median 2610 ms (traced slower by ~7% at the median). The sign flips between runs and the within-run
spread (~1 s) exceeds either gap, so **no tracer overhead is detectable at 200 modules, and none is ruled out**.
The rules never matched the generated modules, so the measured path is the no-violation path.

---

## Neighbour survey

Executed or read from real sources:

| Language | What was run or read | Finding |
|---|---|---|
| Erlang/OTP 25 | `p3_erlang_otp25_moduledoc.out` | `-moduledoc false` compiles on OTP 25 and appears only as an inert attribute in `module_info(attributes)` (`[{moduledoc,[false]}]`); it restricts nothing. `-deprecated` is enforced by nobody except `xref` (`{ok,[{{e,h,0},{d,g,0}}]}`); `erlc` compiled the caller without a warning. P2: an `xref` caller whitelist is 11 lines. |
| Elixir 1.14 | `ex/tracer.exs` (22 lines), `ex/xref.out` | tracer API makes a caller-side check on the callee's name possible; `mix xref callers Shop.Orders.Internal` lists **files** (`lib/billing.ex (runtime)`, `lib/orders/orders.ex (runtime)`), not modules, and omits the computed call. |
| Gleam | source text only, `gleam/fetch-and-grep.out`, `main` branch at fetch time, commit not pinned | `internal_modules` is a gleam.toml glob list (`compiler-core/src/config.rs:207`); its own doc comment (`config.rs:291-294`) says internal modules are **hidden in the docs**; `analyse.rs:1382-1390` marks public items of an internal module `Publicity::Internal`; `docs.rs:86` filters them out. In the five files read I found **no error variant that rejects a reference to an internal module** (`type_/error.rs` internal hits are only `InternalAnnotation` and two comments). That is absence in five files, not proof Gleam never refuses; a different file may. |
| Elm | `elm/run.out` | **Not surveyed.** `elm make` stopped at "PROBLEM LOADING PACKAGE LIST … 403". Cross-package `exposed-modules` behaviour was not observed. |

Named for vocabulary only; not executed, no file:line: C# `internal` (assembly-scoped), Kotlin `internal`
(module-scoped), Rust `pub(crate)` / `pub(in path)`, Java `module-info` `exports … to`, Elixir's Boundary
library (caller-side). The borrow rule (22) says refuse a word whose meaning is adjacent but wrong; B# has no
assembly, so `internal` is the false friend.

## Evidence limits

- `bsc` was never built or run; every `bsc` behaviour is a citation, and the diagnostics shown are
  *proposed*, not observed.
- OTP 25 / Elixir 1.14, not the pinned OTP 28.
- Elm and Gleam give no behavioural evidence.
- P5 (corpus) was miscounted by the worker's script and is corrected above; its committed `.out` is kept as the evidence of the defect, not of the claim.
- Verifier results: p1, p2, p3, the Elixir tracer and xref probes reproduce (timing noise only). The 200-module tracer overhead is a noise-limited bound, not a measurement: min plain 1951 ms vs traced 1967 ms over 10 alternating runs (verifier), ~35k trace events at ~1 µs ≈ 1–2% estimated; the verifier confirmed the tracer really fires and that a planted violation fails the build (exit 1). Rules in p2 and the tracer are hard-coded to the planted names (capability demos, each with an allowed call that is correctly not flagged); the tracer matches by `starts_with?` prefix text, so `Shop.OrdersX` would also match. `-moduledoc` on OTP 25 is an inert attribute and says nothing about its behaviour on the pinned OTP 28. The p3 script's own label says "warns" though its output shows no warning.
- **The `using` chokepoint is leakier than stated:** foreign declarations are processed by `{foreign, _, Mod, Sigs} <- Decls` (`bs_check.erl:620`, `:638`) with no World lookup, so a `using :'Shop.Pricing' {…}` would bypass an `add_import` hook (likely, by reading; not executed), and the namespace branch of `add_import` (`~bs_check.erl:501-505`) bypasses `add_module_import`, so the delta is more than "one clause".
- Gleam: nine source files fetched from unpinned `main` were saved and read as text only (never executed); the quoted lines were verified to exist (`config.rs:207`, `:291-294`, `analyse.rs:1382-1390`, `docs.rs:86`, `type_/error.rs:756,766,1317,1334`) and `type_/environment.rs:1009` additionally hides other-package internal modules from suggestions. Commit provenance not checked.
- Mis-citations fixed: the exported-vs-local elision finding is in ticket 18 §1 (not §5, which is "No opt-out"); `24-testing-story.md` quotes are at 218-220 and 229; ticket 22 says only that no keyword was spent on the incomplete marker (the "keyword budget is a live concern" is this brief's inference); the xref run time is 0.19–0.23 s (no 0.34 s run exists); the tracer file is 21 lines. Ticket 41:490 still draws an `Internal/` "SUB-MODULE, source-only" directory that F15 later reinterpreted — a wording hazard for the `visible to` design.
- The timing runs' variance exceeds the effect and flips sign between runs; no overhead conclusion beyond "undetected".

## Verification

`artifacts/probes/ENG-242/run-all.sh` runs every probe in sequence (Elm and the Gleam fetch need network
and the Elm one is expected to fail here). The separate verifier subagent for this ticket has not been
run by this worker.
