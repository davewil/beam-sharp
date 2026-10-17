# Decision brief — ticket 60 / ENG-242: which modules may name this one?

Status of the ticket: **left open.** This brief decides nothing. Ticket file: `wayfinder/issues/60-which-modules-may-name-this-one.md`.
Probes: `artifacts/probes/60/` (`run.sh` builds three compilers from copies of `compiler/src` and runs everything; its output of 2026-10-17 is in `run.out.txt`).

**Caveats that apply to every number below.** The host is OTP 25.3 / Elixir 1.14.0 / Gleam 1.12.0 / Go 1.25.1; the tickets were measured on OTP 28. `leex` here has no `TokenLoc`, so `build-bsc.sh` patches the *copied* lexer to column-approximate positions: diagnostic columns are wrong, checker behaviour is not. Elm could not be executed (`package.elm-lang.org` is 403 here, so `elm/core` never resolves), C# could not be executed (no `dotnet`), and the Elixir `Boundary` library is not installed — each is labelled where it appears.

## 0. The gating question comes first, and it is smaller than the ticket

The ticket says there is "a consumer waiting": ticket 24 §2's `RecomputeTotal/1`, which "lands `unclassified`". Measured on today's compiler (probe 5), that case is already served:

```csharp
// Shop/Orders/Apply.bs
module Shop.Orders
public int Apply(int net, int tax)
Apply(net, tax) -> RecomputeTotal(net, tax)

// Shop/Orders/RecomputeTotal.bs  — a sibling FILE of the same module
module Shop.Orders
private int RecomputeTotal(int net, int tax)
RecomputeTotal(net, tax) -> net + tax
```

`bsc … Apply 40 2` prints `42`, and the emitted module's exports are exactly `[{'Apply',2}]`. F15 made the directory the module and F12 made `private` mean "this module", so a helper shared by sibling files is private and *not* part of the client API. What `private` cannot reach is a helper shared by **different modules**:

```csharp
// Shop/Billing/Ledger/Ledger.bs
module Shop.Billing.Ledger
public int Recompute(int net, int tax)      // `public` only because Shop.Billing, another module, calls it
Recompute(net, tax) -> net + tax

// Shop/Reports/Reports.bs  — nothing says it should not do this
module Shop.Reports
using Shop.Billing.Ledger
public int Restate(int n)
Restate(n) -> Recompute(n, 0)
```

Today's `bsc` compiles `Restate 5` and prints `5` (probe 1a). The only remedy the compiler's own diagnostic offers for the opposite case is to widen: a call to another module's `private` function ends *"Mark it `public` in Shop.Billing, or move the call inside it"* (probe 1b), and marking it `public` is precisely what opens it to every module. So the real residue of ticket 60 is: **a helper that must be `public` for a sibling module has no way to stay out of an unrelated module's reach.** The ticket's wording of the consumer overstates it by one case.

## 1. The four sub-decisions, answered from what the checker already does

**Where the check lands (sub-decision 4).** `using` is the one place a module is named: LANGUAGE.md says "a qualified call to a module with no `using` is an error too — a file's `using` lines are its dependency list". `bs_check.erl:add_import/7` (line 498) is where a `using` line meets the world, and it already has `Self` and `World` in hand. The ticket cites `add_module_import/5` at `bs_check.erl:407-425`; that is stale — it is `add_module_import/3` at line 512 now, and the right hook is its caller, because only `add_import` knows `Self`. One check there covers unqualified, qualified and namespace imports.

**Direction (sub-decision 2).** At the check site both ends are visible, so direction is a question of where the *declaration* sits, not where the check runs. A callee-side declaration names who may call; a caller-side one would restate what the caller's `using` list already says. I prototyped callee-side only. I did not prototype a caller-side allow-list, so nothing below is measured about it.

**Unit (sub-decision 1).** Both prototypes use the directory subtree under the *parent* of the marked module (`Shop.Billing.Ledger` ← `Shop.Billing` and anything under it). F15 makes that the cheap unit; a list of named modules or a named group was not prototyped.

**Marker or construct (sub-decision 3).** Prototype P1 needs no marker at all; P2 is a module-level line, not a signature marker — `public`/`private` stay a statement about a function and `internal` is a statement about a module.

## 2. What the BEAM bounds: "enforcement" can only mean "bsc refuses"

Probe 2/3. The compiled `Shop.Billing.Ledger` exports `Recompute/2`; attributes are `[{vsn,…}]`.

* An Erlang caller and an Elixir caller each call `'Shop.Billing.Ledger':'Recompute'(40,2)` and get `42` (2c, 2f). `apply/3` hides even the static edge (2d).
* A `-bs_visible_to(['Shop.Billing'])` attribute **can** ride in the beam and shows in `module_info(attributes)` (2g) — and the VM ignores it: a shell call succeeds.
* A run-time caller check is the only emitter-side alternative. Measured: `process_info(self(), current_stacktrace)` costs **~310-340 ns/call against ~9-11 ns plain (≈27-36×, typically ≈34× over six verifier runs)**, and it is unsound — a tail-called callee does not see its caller's frame at all (probe 3: frames `[who,main,…]` with `tail_caller` absent).

So the rule is a compile-time refusal for B# callers, the same ceiling `private` already has (a `private` function is simply not exported; Erlang can still not reach it, but any `public` function is reachable by anyone). Nothing about this ticket makes foreign callers refusable.

## 3. How the neighbours do it (executed unless marked)

| Language | Rule | Evidence |
|---|---|---|
| **Go** | `internal/` is enforced: only code rooted at `internal`'s parent may import it | **Executed** (probe 9): `shop/billing` builds; `shop/reports` fails `use of internal package …/billing/internal/ledger not allowed`. Source: `/usr/local/go1.25.1/src/cmd/go/internal/load/pkg.go:1466` (`disallowInternal`), message at `:1568` |
| **Gleam** | `internal` is **advisory**: hides from docs and from "did you mean to import" suggestions; a dependent may still import it | **Executed** (probe 8): `app` imports `lib/internal/secret` from a path dependency, compiles with no warning, prints `41`. Source (v1.12.0): `compiler-core/src/config.rs:259-276` (`is_internal_module`, default globs `$package/internal`, `$package/internal/*`), `type_/environment.rs:792` (the only use that filters by package: `suggest_modules`), `analyse.rs:329-331` |
| **Elixir** | `@moduledoc false` hides a module from docs; nothing refuses a caller. `mix xref` can *answer* "who names this" but never refuses | **Executed** (probe 6): docs chunk is `:hidden`, `Shop.Reports.restate(5)` returns `5`, `mix xref graph --sink lib/ledger.ex` lists both callers. `Boundary` (the third-party enforcement library) is **not installed**, so nothing is claimed about it. Source (v1.14.0, fetched raw — the installed package ships only `ebin/`): `lib/mix/lib/mix/tasks/xref.ex:89-110`, `lib/elixir/lib/module.ex:292` |
| **Erlang** | `-export` is by function; no per-caller notion. `xref` has `deprecated_function_calls` (`xref.erl:610-613`) but no caller restriction: every `restriction` hit in `xref_base.erl` is the set-algebra operator (e.g. `:1046`), not a rule | Source grep, `/usr/lib/erlang/lib/tools-3.5.3/src/`. Not otherwise executed |
| **Elm** | A package's non-`exposed-modules` are invisible to dependents — enforced by omission: only exposed modules' interfaces are gathered into the package's artifacts | **Not executed** (registry 403). Source (0.19.1): `builder/src/Elm/Details.hs:452` (`exposedDict`), `:507-513` (`gatherInterfaces exposed artifacts`), `:363` (`isPublic`). Scope is the *package*, which B# does not have |
| **C#** | `internal` = assembly; `InternalsVisibleTo` names friends | **Not executed**, no `dotnet`. Ticket 22 already refused borrowing the spelling without the semantics |

Reading across: the two toolchains whose rule is path-shaped and *enforced* agree (Go), the one that names the same convention and does not enforce it is the cautionary case (Gleam). A convention that nothing refuses teaches the wrong thing — Gleam's executed result is the strongest evidence against shipping a doc-only marker.

## 4. The options, as B# programs and compiler deltas

All three are measured by running the *same* program through three compilers (probe 7). `Billing → Ledger` is the legitimate edge and must stay green; `Reports → Ledger` is the one to refuse. Controls: each prototype on the *plain* tree changes nothing (rows 4–5 of probe 7: `7` and `5` as today).

### Option A — defer; document what `private` already covers

No code. `private` serves sibling files (probe 5); the cross-module helper stays reachable (probe 1a, prints `5`).

* **Measured:** the ticket-24 consumer is satisfied today; the open case needs a *second* module that wants to hide a `public` helper from a third.
* **Strongest counterargument:** that case is exactly what agent-written code produces — a helper that had to be `public` for one sibling gets reached by the next file the agent writes — and the compiler's only advice (*"Mark it `public`"*) makes it worse. Waiting means every multi-module exemplar grows edges that would need unpicking once a rule lands.

### Option B (P1) — a path convention: `Internal` as a segment

```csharp
// Shop/Billing/Internal/Ledger/Ledger.bs
module Shop.Billing.Internal.Ledger
public int Recompute(int net, int tax)
Recompute(net, tax) -> net + tax

// Shop/Billing/Billing.bs                        // accepted: Shop.Billing is the parent of `Internal`
module Shop.Billing
using Shop.Billing.Internal.Ledger
public int Charge(int net, int tax)
Charge(net, tax) -> Recompute(net, tax)

// Shop/Reports/Reports.bs                        // refused
using Shop.Billing.Internal.Ledger
// error: `using Shop.Billing.Internal.Ledger` names a module Shop.Reports may not reach
```

Compiler delta (`probes/60/p1-internal-segment.patch`): one function `visible_to/2` in `bs_check.erl`, called from `add_import` (the module branch) and filtering the namespace branch's children, plus one tag in `bs_diag.erl` (`built/2` and `message/1` clauses). **2 files, 24 lines added, 2 changed.** No grammar, lexer, `bsc.erl` or editor change; the emitted `.abstr` of the plain tree is byte-identical under today's, P1 and P2 compilers (`cmp` over all three modules; the check emits nothing).

* **Measured cost to the checker.** Synthetic tree of 120 modules × 6 `using` each (720 imports), compile-all in one VM, 9 runs: P1 428–498 ms min vs base 390–478 ms min, medians 513–538 vs 500–503 (probe 4). The two compilers' spread across repeats (±20%) is wider than any difference between them. The rule in isolation: **≈2.0 µs per import** (verifier: 1.9-2.3 µs; an earlier draft said 3.4 µs, which did not match its own captured output), ≈1.5 ms across all 720 imports, ≈0.3% of the compile (probe 4b; function body copied from the patch).
* **Measured cost to the corpus.** 163 `.bs` files outside `artifacts/`; **0** have an `Internal` segment in a module name (probe 10).
* **Compatibility.** Today's compiler accepts the Internal-segment tree unchanged (probe 7, row 7) — the convention is inert on a compiler that does not know it.
* **Strongest counterargument.** It is a reserved *spelling*, not a language construct: the word `Internal` in a path now changes what the compiler refuses, and a reader of one file cannot see that without knowing the convention. Ticket 65 is the reserved-names policy question; this would be a new entry in it. A second miss: the rule is fixed to "parent subtree", so a module that wants a *sibling* to see it (not its parent's whole subtree) has no spelling. Also, the namespace case needs its own diagnostic: a filtered `using Shop.Billing.Internal` currently reports "`names no module and no namespace`", which is misleading (observed while probing the namespace import).

### Option C (P2) — an explicit module-level marker: `internal`

```csharp
// Shop/Billing/Ledger/Ledger.bs
module Shop.Billing.Ledger
internal
public int Recompute(int net, int tax)
Recompute(net, tax) -> net + tax
```

`Shop.Billing` may `using` it; `Shop.Reports` gets ``error: `using Shop.Billing.Ledger` names an `internal` module Shop.Reports may not reach``. The path does not dictate visibility, and the marker is a separate construct from `public`/`private`.

Compiler delta (`probes/60/p2-internal-marker.patch`): lexer keyword, one grammar production (`decl -> 'internal' : {internal, Line}`), two world-entry sites in `bsc.erl` (`build/4` and `types_world/2` each gain `internal => …`), `visible_to/3` in `bs_check.erl`, the diag clauses. **5 compiler files, 26 lines added, 5 changed.** Beyond the compiler, a new keyword is hand-listed in editor files: `private` is hand-listed in 7 of them (syntect, nvim, two vscode, tree-sitter `grammar.js` and `highlights.scm`, `check-syntect.sh`), plus regenerated `parser.c` (probe 10; proxy count, not an edit I made).

* **Measured:** same enforcement result as P1 (probe 7); no file in the corpus uses the word `internal` (0 of 163), so reserving it breaks nothing today.
* **Surprise, measured.** Today's compiler on the marker tree does not say "unknown keyword": it reports ``using Shop.Billing.Ledger names no module and no namespace`` for **both** the legitimate and the refused edge (probe 7, last row), because a file it cannot parse drops out of the module world. A reader of the spec who has not got `internal` sees an error about a different thing. That is relevant to the clean-room handoff, whose agents will meet unknown syntax this way.
* **Strongest counterargument.** It is the heaviest of the three for the same enforcement — five compiler files and ~7 editor files — and it answers a question nothing has yet asked in the language's own programs. It also puts a *third* visibility concept in the language (`public`, `private`, and a module-scoped `internal`) where ticket 22 deliberately split "what" from "who" and F12 shipped only "what".

## 5. Recommendation

**Option A for now (defer), with Option B as the answer when the evidence below appears.** Reasons, in order of weight: (1) the stated consumer is already served (probe 5), so the ticket's "owed soon" pressure is lighter than its text says; (2) the ticket itself says it is not owed a decision soon; (3) if a rule is wanted, Go's path-shaped, *enforced* rule is the evidenced one (probe 9), Gleam's unenforced one is evidenced not to teach anything (probe 8), and B is the cheapest enforced form — 24 lines, no grammar, inert on today's compiler, 0 corpus conflicts.

What would change the recommendation to "decide now": (a) a shipped exemplar in which a `public` helper made for one sibling module is reached by an unrelated module (probe 1a shows the shape compiles today; none is recorded as having happened); (b) the clean-room spec needing a stated module-boundary rule so the audition's tickets can test it; (c) ticket 24's classification actually being built and needing a cross-module `unclassified` bucket.

When David is asked, ask the gating question alone and as code: *"`Shop.Reports` is refused for `using Shop.Billing.Internal.Ledger`, and `Shop.Billing` is not — yes or no?"* The spelling (segment vs marker) follows from the answer and has no bearing on it; do not ask both together.

## 6. Which results could be circular, and how I guarded them

* P1 and P2 are *my* implementations of the rule, so "refused under the prototype" proves only that I built the rule I described. The meaningful controls are the accept rows: the same prototype compilers on the plain tree and on the legitimate `Billing → Ledger` edge still print `5` / `7`, and today's compiler accepts the P1 tree. A rule that refused everything would fail those.
* Probe 4b copies the `visible_to` body rather than calling the patched `bs_check` function; it measures that algorithm, not the integrated call.
* Probe 3 compares two functions I wrote (plain vs stacktrace-checked). It bounds what a run-time check *could* cost on OTP 25; it is not a measurement of an emitter that exists.
* Probe 4's timing difference is inside run-to-run noise; I report it as "below noise", not as zero.

## Independent verification (separate agent, rebuilt both prototype compilers from the patches)

Verdict: **sound with caveats.** Reproduced: probes 1-3, 5-10; patch sizes (P1 24+/2-, 2 files; P2 26+/5-, 5 files, lexer and parser included); 163 `.bs` files, none with an `Internal` segment. Mutations all flipped as predicted (caller moved under the allowed parent: accepted; `Internal` segment removed: accepted; `internal` line deleted: accepted; `Shop.BillingX` prefix trap: refused).

Corrections applied above: the probe 4b figure and the run-time-check ratio.

Caveats a reader must carry:
1. "Byte-identical .abstr" had no committed probe; the verifier ran `cmp` on 15 files and they matched, but only on a tree that cannot trigger the new check.
2. P1/P2 refusals prove the author's rule is implementable, not that it is the right rule. Accept-side controls are real.
3. The checker-cost result is statistically indistinguishable from zero (±20% spread), not a measured zero.
4. Probe 5's fixture has ticket 24's shape, not its real classification code; "the consumer is already served by `private`" rests on that.
5. The run-time-check cost measures an invented check, not an emitter that exists.
6. Diagnostic columns are wrong on this host (lexer patch). Elm, C# and Elixir `Boundary` were not executed.
