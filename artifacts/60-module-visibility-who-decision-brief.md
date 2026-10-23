# Decision brief — ticket 60: which modules may name this one?

**Ticket** [60](../wayfinder/issues/60-which-modules-may-name-this-one.md) · **Linear** [ENG-242](https://linear.app/davewil/issue/ENG-242) · **Date** 2026-10-23
**Status: DECISION OPEN — for David's review; nothing resolved.** No ticket, feature, glossary or compiler file was edited.
**Revision 2** — corrected after an independent verifier re-ran every probe. The probes reproduced; the verifier found that the first Option A prototype could be bypassed through a namespace `using`. That is fixed and now a probe case (60d). Corrections are listed at the end.

Measured on: OTP 28.5 (erts 16.4, built from source), Elixir 1.19.5, Gleam 1.18.1, Elm 0.19.3, `bsc` built from HEAD `c3d50b9c`, x86_64 Linux.
Sources cited: Gleam compiler `0d9fa18`, Gleam stdlib `13359e5`, elm/core `65cea00` (git clones, depth 1), OTP 28.5 source, Elixir 1.19.5 install.

The ticket says *"not owed a decision soon"*. One of the three options is "do not build it yet", and it is the recommendation.

---

## The gating question, alone

**Who writes the rule: the callee about its callers — or nobody yet?**

(A third answer, *the caller about its own dependencies*, is **my assumption to drop, not a finding**; see "Not costed" below. If David wants it costed, say so and it becomes the gating answer instead.)

The sub-decisions in the ticket follow from this one: once the callee names its callers, the unit is a *caller* set, the marker belongs to the module, and the cost is one more field in the world entry. They are asked only if the answer is "the callee".

The program that decides it. `Shop.Orders.Internal.Totals.Recompute` must be `public` because `Shop.Orders` and `Shop.Orders.Fulfil` are different modules (F15: a directory is a module), so `private` cannot serve:

```csharp
// Shop/Orders/Internal/Totals/Totals.bs
module Shop.Orders.Internal.Totals          // A: the path says "internal"
visible Shop.Orders                         // B: a line says who (hypothetical spelling)
public int Recompute(Order o)
Recompute(o) -> ...

// Billing/Invoice/Invoice.bs                 an outsider
module Billing.Invoice
using Shop.Orders.Internal.Totals     // A, B: error — Shop.Orders.Internal.Totals may not be named from Billing.Invoice
                                      // C:    compiles; Recompute is public, so it is part of the module's API
```

What was actually run (60d, 60f): A and B built as compiler prototypes and exercised on this shape. The fixtures use `Shop.Internal.Calc` (hidden under `Shop`) and, for the nested case, `Acme.Orders.Internal.Totals` (hidden under `Acme.Orders`, and refused from `Acme.Billing`, which sits under `Acme` but outside `Acme.Orders`). The example above is the same shape with names the ticket would use, not a verbatim run.

## Sub-decisions, in dependency order

| # | Sub-decision (ticket's numbering) | Role | Settled by |
|---|---|---|---|
| 1 | **Direction**: callee names who may call (or nobody yet) (ticket Q2) | **gating** | this brief's question |
| 2 | **Unit**: subtree / named group / explicit list (ticket Q1) | following — A gives the subtree for free; B offers all three | 1 |
| 3 | **Marker or separate construct** (ticket Q3) | following — A has no marker; B is a declaration line | 1 |
| 4 | **Checker cost** (ticket Q4) | following — measured for A and for B below | 1 |

### Not costed: "the caller declares"
`using` already is the caller's declared dependency list, and the compiler refuses a qualified call that skips it (`Billing/Direct/Direct.bs:3:31: error: Shop.Internal.Calc is called but never imported`, probe 60d). A rule on the caller's side can limit what a module imports, but it cannot let a module protect a helper it owns from an unknown consumer, which is the stated need (24 §2). So it is a layering policy file, not a visibility feature. That is a judgement I made to keep the options to three; I have not built or measured it.

---

## What the platform allows (shared by every option)

**The enforcement point is the caller's compile, and it can only be that.**

- **60b (1)** — an exported function is callable from every module (`vis_foreign → vis_lib:plain()` returned `ok`); the control, an unexported function, gives `{error,undef}`. There is no "export to some modules".
- **60b (2)(3)** — a callee that enforces at run time has to read its own stacktrace. It answers correctly for a genuine non-tail call (`allowed`) and for a foreign caller (`{denied,vis_foreign}`), and **wrongly denies the friend when the friend calls in tail position, or writes `R = f(), R`** (`{denied,vis_driver}`: `erlc` compiles that bind-and-return into a tail call, so the frame is gone). Cost: **8.7 ns/call plain vs 419.5 ns/call guarded** (median of 7 runs of 1e6; guarded spread 388–427), about 48×.
- This agrees with ticket 18 §1 (*"a BEAM function has one entry label shared by both call kinds"*) and with the ticket's own *"a compile-time check on the caller, or it is nothing"*.
- **Every dependency edge enters through `add_import/7`** (`compiler/src/bs_check.erl:498`). That function has two arms: a module `using` (the `true ->` arm, line 500) and a namespace `using` (the `{Children, _}` arm, ~line 507, via `add_namespace_import`). A qualified call must have a `using` entry first (`qualified_module/3`, `:4569`; comment at `:4567`: *"those entries declare the file's dependencies"*), and types follow the same path (`type_module_not_imported`, `:447`). The first version of this brief said "one site suffices" and the prototype guarded only the first arm; the verifier compiled an outsider through the second and it passed. Both arms are now guarded and both bypasses are probe cases (`Billing.Ns`: `using Shop.Internal` then `Calc.Double(n)`; `Billing.Ns2`: `using Shop` then `Internal.Calc.Double(n)`). The ticket's cited `add_module_import/5` at lines 407–425 has since moved; it is `add_module_import/3` at `:512`.
- **The promise can only be "among B# code".** Gleam's internal modules are still callable from Erlang (60a D: `lib:attr_internal() = 7`, `lib@internal@secret:helper() = 41`). Any B# rule inherits that, the same boundary as ticket 18's *"your types are checked among beam-sharp code"*. Ticket 62 is where foreign callers are handled.
- **The rule does not stop a hidden type leaking through a visible signature** (60d, "known gap", asserted): with `Lib.Api` (visible) returning a record minted in `Lib.Internal.Types`, an outsider compiles `var r = Make(n); r.Id` without ever naming that module (exit 0), and its type error prints the hidden tag: `not covered by the declared return type: { Kind: :'Lib.Internal.Types.Row' }`. Whether that is acceptable is a fourth sub-decision this ticket does not list.

## Neighbours (file:line, re-read before citing)

| Language | Unit | Direction | Enforced? | Evidence |
|---|---|---|---|---|
| **Gleam** | the **package**; a module is internal by path (`<pkg>/internal`, `<pkg>/internal/*`, overridable by `internal_modules` globs in `gleam.toml`) or a *definition* by `@internal` | callee, by path or attribute | **No for naming.** Hidden from docs, autocomplete and the exported interface; still compiles and runs. It **does** touch two checker outputs (below) | `compiler-core/src/config.rs:207` (field), `:291-313` (*"hidden in the docs or not"*, default globs `:306-309`); `type_.rs:1028-1030` (*"technically importable by other packages but to do so is violating the contract of the package"*); `type_/environment.rs:1009` (suggestions skip it); `ast.rs:822-856` (`Publicity::Internal` is still `is_importable`); `analyse.rs:1380-1390` (public types in an internal module get `Publicity::Internal`); `exhaustiveness/printer.rs:68-81` (an internal type from **another module** is printed as `_` in an exhaustiveness residual: *"We don't want to expose information about an internal type, making it easy to rely on its internal structure"*); `changelog/v1.1.md:47-49`. Stdlib uses it on single functions: `stdlib/src/gleam/dict.gleam:572-573` |
| | | | **Leak refusal: written, then withdrawn** | `compiler-core/src/error.rs:399` and `:1510` define `CannotPublishLeakedInternalType` ("These modules leak internal types in their public API and cannot be published"); a search of the tree finds no place that constructs it, and `changelog/v1.1.md:35-41` records *"Revert the change that would make the build tool refuse to publish a package that exposes an internal type in its public API"* |
| **Elixir** | none in the language; `@moduledoc false` / `@doc false` per module / function | callee, advisory | **No.** Documentation metadata only | `lib/elixir/lib/module.ex:322-323` (*"invisible to documentation extraction tools"*). A caller-side check is buildable with a compiler tracer: `code.ex:1758` (`:tracers`), `:155` (`{:remote_function, meta, module, name, arity}` events). `boundary` is the known user of that hook; **not installed, not surveyed** |
| **Erlang/OTP** | none. `-export` is the only gate; `-doc hidden` and EDoc `@hidden`/`@private` are documentation | callee, advisory | No. Tooling only (`xref`, a library) | `lib/stdlib/src/shell_docs.erl:841-843` (*"This probably means that it is internal and not to be used by other applications"*); `lib/edoc/src/edoc_tags.erl:93,95` (`hidden`, `private`); `lib/stdlib/src/escript.erl:404` (`-doc hidden.` in use) |
| **Elm** | the **package**: `elm.json` `exposed-modules` | callee, in a manifest outside the source | **Not probed** (see Not measured). The module `Elm.JsArray` exists at `src/Elm/JsArray.elm:1` and is absent from `elm.json:7`'s list; that it is therefore hidden from dependents is my knowledge of Elm 0.19, not evidence from this session | `elm/core/elm.json:7`, `src/Elm/JsArray.elm:1` |
| **C#** | the assembly (`internal`) | callee | yes | **Not surveyed** — no local source |

Reading: Gleam, the closest precedent for *spelling*, chose not to enforce naming — and its residual-printing rule (`printer.rs:68-81`) matters to B#, whose defining feature is exhaustiveness: a restricted module's types appearing in an outsider's residual is the same leak 60d measured (`{ Kind: :'Lib.Internal.Types.Row' }`). Probe 60a: a dependent package imports `lib/internal/secret` and calls an `@internal` function, both exit 0; the control, a non-`pub` function, is refused (exit 1).

---

## Options

### A. The path says so: an `Internal` segment (callee side; unit = the subtree above it; no marker, no syntax)

A module whose dotted path contains a segment `Internal` may be named only from modules under the path before that segment.

**Compiler delta (prototype, built and run — 60d):** `visible/2`, `require_visible/4` and `visible_children/5` in `bs_check.erl`, called from both arms of `add_import`; one new error `module_not_visible` with a `built/2` and a `message/1` clause in `bs_diag.erl`. **33 lines added, 2 removed in the unified diff (a changed line counts once in each), 2 files**, comments and blanks included (`proto_internal_segment.patch`). No lexer, parser, grammar or world-entry change. `--api` (lenient mode) is not checked.

**Measured (60d, every row has an expected result and the script exits non-zero if any differs; the refusing rows also check the error names the case's own file):**

| case | pristine | prototype |
|---|---|---|
| `Shop.Orders` (`using Shop.Internal.Calc`) · `Shop.Internal.Deep.Leaf` · `Shop.Orders.Ns3` (`using Shop.Internal`) · `Shop.Orders.Ns4` (`using Shop`) · `Acme.Orders.Fulfil` (nested `Internal`) | 0 | 0 — admitted |
| `Billing.Invoice` (module `using`) · `Billing.Ns` (`using Shop.Internal`) · `Billing.Ns2` (`using Shop`) · `Acme.Billing` · `Acme.BillingNs` (`using Acme.Orders.Internal`) | 0 | 1 — refused |
| `Billing.Direct` (qualified call, no `using`) | 1 | 1 |

Message quality: the module-`using` and `using Shop.Internal` refusals say `may not be named from …`. **`Billing.Ns2` (`using Shop`) is refused with a worse message**, `Internal.Calc is called but never imported`, because the namespace import silently drops the hidden children rather than naming them. A diagnostic fix is not prototyped.

Compile wall time, 15 interleaved rounds, ms, median [min..max], final capture: `Shop/Reports` pristine 462 [417..505] vs prototype 477 [431..493]; `Shop` 463 [442..491] vs 463 [429..494]. **Within spread — no difference is resolved**, and the corpus contains no `Internal` segment, so this shows the accept path costs nothing visible, not the cost of a refusal. Isolated: **about 700–800 ns per check** (final capture 710.1, min 693, max 889; five captures of the median ranged 698–805), one check per `using` line.

**Strongest counterargument:** it reserves a path segment. That is ticket 65 (reserve a name, or let user names win) arriving by the back door, and ticket 65 says to decide it once while the list is empty. `reserved_qualifiers()` already burns four names (`bs_check.erl:1701`). The repo has no path or `.bs` source containing `Internal` today (60g: none), so it is cheapest now. Also: location-as-semantics; and Gleam's `internal` is package-scoped where B# has no package, so the borrowed word is the false friend ticket 60 warns about; B#'s meaning ("the subtree above") would have to be defined in the glossary.

### B. A declaration line says so (callee side; unit = whatever the line names; marker = a line like `behaviour`/`using`)

```csharp
module Acme.Orders.Totals
visible Acme.Orders          // any number of lines; each names a subtree
visible Acme.Audit
```

Spelled as its own line, **not** inside the `module` line: `{module, L, Name}` is matched in many places (`module_name/1`, `bs_check.erl:269-273`), a new declaration is not.

**Compiler delta (prototype, built and run — 60f):** lexer keyword `visible` (1 line), parser terminal + `visible_decl` + `decl` arm (4 lines), `visible => [...]` in the world entry in `bsc.erl:227-`, the same check reading the entry in `add_import` (both arms), and the same `module_not_visible` error. **38 lines added, 4 removed, 5 files** (`proto_visible_line.patch`). yecc conflicts: 6 shift/reduce before, **6 after** (no new ones).

**Measured (60f, same expectation-and-exit-code discipline):** `Acme.Orders.Fulfil` (under the first path) admitted; `Acme.Audit` (second path, outside `Acme.Orders`) admitted; `Acme.Billing` refused; `Acme.BillingNs` (`using Acme.Orders`, then `Totals.Double`) refused; `Acme.BillingOpen` (callee with no `visible` line) admitted. **What the keyword takes away:** whole-word `visible` in the repo's `.bs` files: 0 occurrences outside comment-only lines (a regex filter, not hand-read). The pristine compiler on the callee itself: `syntax error before: '.'`.

**Strongest counterargument:** two sources of truth. F15 makes the directory the module, so moving a directory renames the module and silently invalidates a hand-written `visible` path; A cannot go stale because the path *is* the rule. It also spends a keyword (the seventeenth, if 22's count of sixteen stands) and a grammar arm for a feature whose demand is unmeasured, the grounds on which ticket 22 refused `incomplete`. Its one advantage over A is the multi-path list (`Acme.Audit`), which A cannot express at all.

### C. Build nothing yet; record the trigger

`public`/`private` stays the whole story. The remaining who-question is a helper that must be `public` only so a sibling module can call it. Today it is simply public:

```csharp
// Shop/Orders/Totals/Totals.bs
module Shop.Orders.Totals
public int Recompute(Order o)         // public only because Shop.Orders.Fulfil is another module
Recompute(o) -> ...

// Billing/Invoice/Invoice.bs
module Billing.Invoice
using Shop.Orders.Totals              // compiles; Recompute appears in `bsc --api Shop/Orders/Totals`
```

The pristine columns of 60d are exactly this: the outsider compiles under the unmodified compiler (`pristine=0` for `Billing.Invoice`).

**Compiler delta:** none. **Evidence on demand (60e text census, method in the script; its control compares the regex with independent `grep -c` counts and exits non-zero on disagreement — it now passes: public 100/100 and 30/30, private 15/15 and 51/51):**

- Compiled corpus (`compiler/examples` minus `exemplars/`): 116 signatures, 100 public. Its **one** behaviour module (`Counter`) has 3 public functions, all GenServer callbacks (`bsc --api` agrees): 0 `unclassified`.
- Exemplars (do not compile yet): 82 signatures, 30 public, 51 explicitly private. In their 3 behaviour directories: 8 public callbacks and **8 public non-callbacks** (`Consume` ×2, `Decide`, `EncodeAck`, `ByStatus`, `Fetch`, `Summarise`, `Ask`). They look like client API from their names; I did not read them function by function.
- `using` edges between modules in the whole corpus: **8** (60g). The only one I can identify as reaching past a subtree is `Pipeline → Shop.Collections`, a real public consumer.
- F12 removed most of 24 §2's remainder: a helper is private by default, hence the 51 private signatures. The boundary manifest 24 §2 would feed is not built (`grep -rn "boundary manifest" compiler/src` is empty).

**This evidence cannot reject the hypothesis that the who-half is needed**, and I do not claim it does. The compiled corpus has one behaviour module whose publics are all callbacks, so a zero there is guaranteed by the corpus; the exemplars were written before any visibility feature existed; and no program written by an agent under a visibility rule exists to count. What it does show is that nothing in the repo *requires* the feature today.

**Strongest counterargument:** the reservation window. If a word is ever reserved (A), it costs least while no program uses it, and A is 33 lines, so deferring saves almost nothing on the compiler and spends something that cannot be recovered: a user's directory named `Internal`. The agent-drift argument in the ticket is also untested here: nobody has measured how often an agent writing tests picks a public helper.

---

## Recommendation

**C now, with A as the pre-costed fallback, plus one cheap hedge.** Reasons: the ticket says no decision is owed soon; the consumer (the boundary manifest) is unbuilt; F12 took most of the problem; nothing in the repo requires the feature (with the limits stated above); and A is fully measured at 33 lines in two files. The hedge answers C's counterargument: **decide ticket 65 (reserved names) first or together, and say there whether `Internal` is on the list.** That closes the window without building anything. If David prefers to decide the feature now, **A** over B, because it has no grammar change, no list to go stale and the smaller diff — and A's namespace arm, its worse `using Shop` diagnostic, and the type-leak gap are the three things to review before building it.

**What would change this:** the boundary manifest gets built and must tell client API from shared helper (then A or B); a real program needs a helper shared across sibling modules; an agent-written test suite is measured targeting public helpers (then straight to A); a package/assembly notion enters the glossary (reopens the unit, B's explicit list gains).

---

## Evidence ledger

| Id | Claim it tests | Control | Result | Does NOT show |
|---|---|---|---|---|
| 60a | Gleam does not enforce `internal` across packages | non-`pub` call refused | A and B exit 0; control exit 1; Erlang calls both; interface lists only `lib`/`api` | Elm; Gleam JS target; any other form of internal marking |
| 60b | BEAM cannot restrict callers; a run-time check is costly and tail-call-wrong | unexported → `undef`; non-tail friend allowed, foreign denied | exported fn callable from anywhere; 8.7 → 419.5 ns/call; tail-call friend denied | JIT-level mitigation; non-stacktrace caller identity (a token argument) |
| 60c | Elixir `@moduledoc false` prevents nothing; a caller-side check is buildable | `defp` outside: compile **warning** + run-time `UndefinedFunctionError` | outsider compiled and ran (42); docs `:hidden`; tracer refuses outsider and admits friend; 13-line tracer | the `boundary` library; Mix builds |
| 60d | Option A: both `using` arms guarded; cost; known gap | pristine accepts all but `Billing.Direct`; expectations asserted, exit non-zero on any difference, refusal must name its own file | 11 cases as expected plus the asserted leak; 33+/2−; wall time within spread; ~700–800 ns/check; type leakage compiles | refusal-path cost in the real corpus; `--api`/ibs/test suite; diagnostics for the `using Shop` case |
| 60e | size of the `unclassified` remainder | regex vs independent `grep -c`, exits non-zero on disagreement (passes) | table above | demand in agent-written code; whether the 8 non-callbacks are helpers |
| 60f | Option B: cost and cases | same discipline as 60d | 38+/4−, 5 files; 6→6 conflicts; 5 cases as expected; 0 `visible` identifiers | a second `visible` spelling (e.g. on the `module` line); diagnostics quality |
| 60g | the 8 cross-module edges; no `Internal` path in the repo | — | 8 edges / 75 files; none | exemplar semantics (text only) |

Each probe is a script in `artifacts/probes/60/` with its captured run in `output-60?.txt`. Source `env.sh` from the session scratchpad first (`/tmp/claude-0/-home-user-beam-sharp/9903cb2c-0a5d-5378-89d7-c06a67894f0b/scratchpad/env.sh`). 60d and 60f copy `compiler/` to a temp directory, delete its generated `bs_parser.erl`/`bs_lexer.erl` (gitignored; stale copies hid the patched grammar the first time), apply the patch and build there; the repo is not touched.

## Not measured / caveats

- **Elm enforcement**: attempted. `ELM_HOME` seeded with `elm/core` from a git clone; `elm make` asks `package.elm-lang.org` for the registry (403 through the proxy) before compiling. Unprobed.
- **C#**, the Elixir `boundary` library, Erlang `xref` analyses: not surveyed.
- **Diagnostics**: the `using Shop` refusal in A is poorly worded; the leak of a hidden record tag into an outsider's type error is measured, the fix is not.
- Wall-time measures are whole-process (`bsc` start-up dominates, ~450–500 ms); the per-check figure is the in-VM one and drifts run to run (698–805 ns).
- The prototypes are for sizing only; nothing was added to `compiler/`.
- Toolchain: OTP 28.5 is the repo pin; Elixir is 1.19.5, a version the earlier 62a prototype did not record.

## Corrections since revision 1

1. Option A bypass through a namespace `using` — fixed; both bypass shapes and insiders are 60d cases. Line delta re-counted: 33 added / 2 removed, 2 files (was "21 + 1").
2. The example's names versus the probe's — stated above; the nested `Internal` case (`Acme.*`) is now run.
3. Per-check cost "~760 ns" replaced by the measured range (about 700–800 ns).
4. Gleam row corrected: `@internal` also changes exhaustiveness output (`printer.rs:68-81`) and type publicity (`analyse.rs:1380-1390`); the leak refusal exists as dead code (`error.rs:399,1510`) after the revert.
5. "Demand is thin" now states what the evidence cannot show; 60e exits non-zero when its own control disagrees (it did: the regex was improved until it agreed).
6. The "+21 / 1 changed" double count removed.
7. Citations: `dict.gleam:572-573`; `bs_check.erl` module arm at 500 (the function starts at 498).
8. One gating question; "caller declares" is stated as my assumption, not a finding.
9. Wall-time wording is "within spread".
10. Option B now has a built prototype (60f); Option C has a B# program.
11. Unprobed items are scripted (60g) or marked as knowledge (Elm).
