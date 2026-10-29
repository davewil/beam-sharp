# Decision brief: ticket 60 — Which modules may name this one?

Ticket 60 (Linear ENG-242) · 2026-10-29 · **DECISION OPEN — for human review**
Probes: `artifacts/probes-60/` (map in its `README.md`). Repo HEAD read: `c07bb7f` (shallow clone, 51 commits).

## Premises in the ticket that the evidence contradicts

1. **"C#'s `internal` ... a subtree is not what `internal` means anywhere else."** Go's `internal/` is
   exactly a directory-subtree rule, enforced by the go command's loader (probe 5, MEASURED-HERE). `internal` is a false
   friend against C# but a true friend against Go. The borrow-heuristic survey must say so.
2. **`add_module_import/5` at `bs_check.erl:407-425`.** At HEAD the function is `add_module_import/3`
   at `bs_check.erl:509-523`. Commit `0b761f6` ("measured at") is not in this shallow clone, so the old
   line numbers cannot be checked. The substance holds: it reads only `exports` and `types` of the callee.
3. **24 §2 says `RecomputeTotal/1` lands `unclassified` because "every function in an aggregate is
   exported today".** F12 was amended 2026-08-17 (`F12-public-and-private.md:11`): an unmarked
   signature is now **private**. A private helper in the same module is already unnameable from a test
   in another module (`private_callee`, `bs_check.erl:4470`). The residual 24 cares about is narrower:
   a helper that is `public` because a *sibling module* needs it, and so is nameable by everyone.
   The `unclassified` boundary-manifest line is not built (grep of `compiler/src`: only an unrelated
   diagnostic tag of the same name).
4. **F12 already declined "`protected`, `internal`, or any third level"** (`F12-...md:185`: "Two words,
   because the BEAM has two states"). That is about the *signature* marker. This feature is a
   *module-level* rule, which is sub-decision 3 below.

No hit for `internal`, `friend`, `sealed`, `visible_to` in `CONTEXT.md` (zero lines). In tickets the
hits *in the module-visibility sense* are `22:133,435`, `60:19,31-34`, `F12:185`, and `41:490` which draws `Internal/` as an
example sub-module directory (F15:217-231 then corrected "sub-module" to mean a *file*, so that line
is a stale illustration, but it means a directory called `Internal` already appears in a ticket).

## What is being asked, in gating order

**Gate: the unit.** Can "who may name this module" be answered by *where the module sits*, or must the
module *list* its callers? Everything else follows:
- Direction (callee names callers / caller declares) — see "Why direction is nearly decided" below.
- Marker is module-level, not a signature marker (F15: `index.bs` is the file that holds module-level
  declarations: `using`, `type`, `record`, `behaviour`, "no functions", `F15:31`).
- Spelling — deferred. `restricted` / `visible to` below are **placeholders** for the programs only.

### Why direction is nearly decided (read, not run)
Every cross-module name goes through `using`: a qualified call whose module was not imported is
`module_not_imported` (`bs_check.erl:4566-4570`, `qualified_module/3` at `:4558`). So a callee-side
rule needs exactly one check site, **`add_import/7` (`:495`) → `add_module_import/3` (`:509`)**
(`bs_check.erl:495-523`), where both `Self` and the callee `M` are known. A caller-side rule
("this module may use only X") is a second dependency list beside `using`, which 41 §1 made the single
dependency list (`using` lines "are its dependency list", 41 decisions entry, `LANGUAGE.md:155-158`).

## Evidence

| # | Probe (dir under `probes-60/`) | Claim | Result | Label |
|---|---|---|---|---|
| 1 | `gleam/run.sh` | Gleam `internal_modules` + `@internal` stop another package | **No.** `app_internal` (path-dep on `lib`) imports `lib/internal/helper` and calls an `@internal` fn: compiles, rc 0, no warning. Generated `.erl` exports `recompute/1`, `secret/1` as ordinary exports. `export package-interface` and `docs build` omit them. Control: calling a non-`pub` fn is a hard error ("does not have a `hidden` value"). | MEASURED-HERE (path dependency; verifier reproduced with a `git` dependency, also unenforced; hex not probed). The control tests private visibility, not `internal_modules`: it shows the harness can go red, nothing more. |
| 2 | `elixir/run.sh` | `@moduledoc false` restricts naming | **No.** `Shop.Billing` calls `Shop.Orders.Internal.recompute/1`: no warning, runs, returns 2. Docs show `:hidden`. Calling an absent/`defp` fn is a *warning*, not an error (1.14), runtime `UndefinedFunctionError`. `mix xref callers` lists both callers. | MEASURED-HERE (no Elixir sources installed; behaviour only) |
| 3 | `erlang/run.sh` | Enforcement is compile-time only | `erlc` accepts a call to a non-exported fn (rc 0). Runtime: `undef` with `[{shop_orders_internal,hidden,[1],[]},...]` (also via `apply/3`). The "friend" violation `shop_billing:charge/1` runs fine, returns 2. `error_handler:undefined_function/3` is the runtime gate (`kernel/src/error_handler.erl:39-46`): export-or-nothing, per module. | MEASURED-HERE |
| 3b | `erlang/friend.escript` | A caller-side pass over beams is implementable | xref `"ME"` query yields module edges; 8-line rule (hard-codes the `_internal` suffix and the fixture is named to match, so the violation is fixture-matched: it shows xref exposes module edges, not that a real rule is expressible) reports `{shop_billing,shop_orders_internal}` as the only violation, plus xref's own `undefined_function_calls`. Needs `+debug_info`; without it xref returned `[]` silently (first run). | MEASURED-HERE |
| 3c | `erlang/xref_time.escript` | Price of that pass on real beams | `/usr/lib/erlang/lib/stdlib-4.3.1.3/ebin`: 87 modules, 735 module edges. Load 0.88–1.06 s in my 3 recorded runs (1057, 908, 881 ms); the verifier saw 0.94–1.67 s over 5 runs (machine variance), edge query 54–78 ms, prefix test over all edges 3–4 ms. Dominated by loading beams, not by the rule. | MEASURED-HERE |
| 3d | `erlang/attrs/run.sh` | Attribute escape hatches | `-compile(export_all)` warns (`erl_lint.erl:258-259`); `nowarn_export_all` silences it; `-opaque` is a plain `{t,1}` at runtime. `-ignore_xref` is not in any OTP 25 source here (rebar3 feature) — not probed. | MEASURED-HERE |
| 5 | `go/run.sh` | A subtree rule exists, enforced, and admits a test dir inside the subtree | `shop/orders/internal/pricing` imported from `orders` and from `orders/tests`: builds. From sibling `billing`: `use of internal package ... not allowed`, rc 1. | MEASURED-HERE. Enforced by the `go` command's package loader, not the compiler: the verifier compiled a "refused" package with `go tool compile` and a hand-built importcfg, rc 0. bsc is both loader and checker, so no such bypass unless `--api`/lenient mode skips it (go 1.24.7; not in the brief's survey list, added because it is installed) |
| 4 | `cost/model.escript` | Subtree check cost shape | See below. A MODEL in Erlang, **not** `bsc`; linear-in-edges is true by construction (it iterates edges), and the all-pairs baseline is a strawman quadratic by construction. Treat as "no reason to fear", not evidence of bsc cost. | MEASURED-HERE (model) |
| 6 | `bs_check.erl:4566`, `:509`, `bsc.erl:227-239` | One site; where scope data would live | World entry map is built at `bsc.erl:227-239` (`exports`, `private`, `types`...). No `scope` key exists. | RECORDED-NOT-RERUN (bsc cannot be built here) |

**Cost model (probe 4).** Synthetic dotted module trees, 8 `using` edges per module, every third module
under an `Internal` segment, rule = "callee's path prefix before `.Internal.` must prefix the caller".
min/median of 15 runs, microseconds:

| N modules | using edges | edge-driven (the real shape) | all-pairs (what a callee-names-callers scan would be) |
|---|---|---|---|
| 10 | 80 | 179 / 243 | 234 / 245 (90 pairs) |
| 100 | 800 | 1853 / 1963 | 26635 / 27533 (9,900 pairs) |
| 1000 | 8000 | 19481 / 19890 | 3.35 s / 4.52 s (999,000 pairs) |

Negative control (no restricted modules at all): edge-driven 136 / 1455 / 15335 µs. So the work is
linear in `using` edges and the prefix test is not what costs: a map lookup and `atom_to_list` per edge
dominate. The model's ~2 µs/edge is Erlang list-comprehension overhead, so read the *shape*, not the
constant. A scan that enumerates pairs is quadratic; **do not implement it that way**. The existing
`children/2` (`bs_check.erl:587`) already scans every known module once per namespace `using`, the
same order of cost.

## Options for the gating question (the unit)

Placeholders: `restricted`, `visible to`. Tree:

```
Shop/
  Orders/
    index.bs            module Shop.Orders
    Total.bs            module Shop.Orders           public Total, calls RecomputeTotal
    Pricing/
      index.bs          module Shop.Orders.Pricing
      RecomputeTotal.bs                              public int RecomputeTotal(Order o)
    Archive/
      Snapshot.bs       module Shop.Orders.Archive   needs RecomputeTotal
  Billing/
    Charge.bs           module Shop.Billing          wants RecomputeTotal (the temptation)
```

### Option A — the unit is a subtree, implied by where the module sits

```csharp
// Shop/Orders/Pricing/index.bs
module Shop.Orders.Pricing
restricted                         // placeholder: scope = the parent, Shop.Orders and below

// Shop/Orders/Archive/Snapshot.bs
module Shop.Orders.Archive
using Shop.Orders.Pricing          // compiles: Shop.Orders.Archive is under Shop.Orders

// Shop/Billing/Charge.bs
module Shop.Billing
using Shop.Orders.Pricing          // REFUSED: Shop.Orders.Pricing is restricted to Shop.Orders.*
```

Delta (concrete):
- `bsc.erl:227-239`: World entry gains `scope => none | Prefix` (an atom `Shop.Orders`), derived from the
  module name and the marker parsed from `index.bs`. `bsc.erl:293` (the loaded-from-cache entry) gets the
  same key, default `none`.
- Parser/lexer: one module-level declaration in `index.bs` only; F15's `no_function_in_index`-style
  check refuses it in any other file. Three tree-sitter grammars plus `check-tokens.sh` move with it
  (F12:175 describes the same cost for a keyword).
- `bs_check.erl:509` `add_module_import/3`: before folding exports, `case scope of none -> ok;
  Prefix -> Self =:= Prefix orelse is_child(Prefix, Self)`; otherwise
  `erlang:error({module_not_visible, M, Self, Prefix, L})`. `add_import/7` passes `L` already.
- `add_namespace_import/3` (`bs_check.erl:524`) adds `Children` blindly: `using Shop.Orders` from
  `Shop.Billing` would pull `Shop.Orders.Pricing` in. It must drop children whose `scope` rejects `Self`
  (silently, as a namespace import is a convenience; a *named* import is the error).
- Types ride the same import (`Types` fold in `add_module_import`), so the rule covers types for free.
- `bs_diag.erl`: one `built/2` clause (`:669` shape) and one `message/1` clause (`:2095` shape), a test,
  a `--self-test` gate per CLAUDE.md. No codegen change: the rule is erased (no atom, attribute or beam
  change), same status as namespaces (41 §5).

**The 24 scenario (an agent writing tests in a loop):**
```csharp
// Shop/Orders/Tests/PricingTests.bs      module Shop.Orders.Tests   -> using Shop.Orders.Pricing : COMPILES
// Shop/Tests/OrdersPricing.bs            module Shop.Tests          -> using Shop.Orders.Pricing : REFUSED
```
Under A, an agent that mirrors tests *inside* the aggregate (the layout 24's fog leaves open) reaches
`RecomputeTotal` freely. This is the Go result (probe 5: `orders/tests` builds). A only solves 24's
problem if the test-layout decision (24, "Notes", line 402) puts tests *outside* the subtree.

**Strongest counterargument:** the scope is the directory, so architecture is welded to layout.
"Archive and Billing may use Pricing, Reports may not" cannot be said without moving directories, and
the default placement of tests lands inside the allowed scope.

### Option B — the unit is an explicit list the callee writes

```csharp
// Shop/Orders/Pricing/index.bs
module Shop.Orders.Pricing
visible to Shop.Orders, Shop.Orders.Archive      // placeholder spelling; a list of module paths

// Shop/Billing/Charge.bs          using Shop.Orders.Pricing   // REFUSED
// Shop/Orders/Tests/PricingTests.bs  using Shop.Orders.Pricing // REFUSED: not on the list, wherever it sits
```

Delta:
- Same World key but `scope => [Module]`; check is `lists:member(Self, List)` (O(list) per edge,
  cheaper than the prefix test).
- Each name in the list must resolve to a known module: a new `unknown_module` check at the callee
  (`add_import`'s `Known` set exists, `bs_check.erl:488`), so renames break loudly at the list.
  Namespace paths in the list (`Shop.Orders.*`?) reopen option A inside B — a second grammar decision.
- Same `add_namespace_import` filter, same diagnostics, same gate; more grammar (a list).
- Every tool that reads the list needs the dependency *graph* inverted to answer "who uses this": the
  list is declared intent, `using` is actual use, and the two can disagree (a listed module that never
  uses it is silently allowed). A pass would be needed to warn on that, which is more checker.

**The 24 scenario:** test placement stops mattering. The agent's move is a diff to the *callee's*
`index.bs`, a file a reviewer reads, instead of a new directory.

**Strongest counterargument:** lists rot, and an agent that is blocked edits the list. The enforcement
is a speed bump with a better-placed diff, not a barrier; it also duplicates `using` as a second
statement of dependency, which 41 §1 argued against.

### Option C — build nothing; F12's private-by-default plus a test-placement rule

```csharp
// Shop/Orders/Total.bs and Shop/Orders/Recompute.bs are both `module Shop.Orders`
int RecomputeTotal(Order o)        // unmarked = private; a test in any other module cannot name it
```
Delta: none in the checker. 24's manifest must stop reporting `unclassified` for private functions, and
the test-layout fog decides the rest. **What it cannot express:** `Shop.Orders.Archive` needing a helper
from `Shop.Orders.Pricing` forces `public`, and then `Shop.Billing`, an agent's test module, and any
outside caller can name it.
**Strongest counterargument:** that last sentence. It is the exact case 22 called "the useful half"
and the cost of leaving it is a public helper with no way to say "not for you".

## Recommendation (one)

Ask the gating question as a single program, not a menu: *should a test module under
`Shop/Orders/Tests/` be able to `using Shop.Orders.Pricing`?* The two options answer it differently
(A yes, B no) and nothing else changes. If David wants A, the cost is smallest and best-evidenced: one
check at `bs_check.erl:509`, edge-linear, no codegen, Go is the measured precedent. If he wants "tests
never", only B delivers it, and A needs the test layout fixed outside the subtree. My lean is A, with
the test-layout decision (24 fog) taken *with* it, because B's list duplicates `using` and an agent can
edit it as easily as it can create a directory.

## Limitations

- `bsc` cannot be built here (OTP 28 pinned): every statement about `bs_check.erl` / `bsc.erl` is
  **RECORDED-NOT-RERUN** (read from source at `c07bb7f`). The "refused/compiles" B# programs above are
  design programs, not run. Nothing proves the `add_namespace_import` filter shape or that `index.bs`
  can carry a module-level declaration without a parser change.
- The cost model is Erlang over synthetic names, not `bsc` over real World maps. It shows shape
  (linear in `using` edges) and not the real constant.
- Gleam: path and git dependencies unenforced; a hex dependency might differ (unreachable offline).
- Elixir internals not citable (no sources installed). Elm: not probed (not installed).
- Go was probed, though not on the assigned survey list.
- `0b761f6` not in the shallow clone, so the ticket's "measured at" line numbers are unverifiable.
- Spelling, whether `restricted`-style markers need a keyword at all (vs. a directory named `Internal`
  as in Go), and whether types are in or out of scope were not decided or probed.

## Probe index (re-run from repo root; `S=artifacts/probes-60`)

```
sh $S/gleam/run.sh <path-to-gleam-1.12.0>
sh $S/elixir/run.sh                       # needs `mix`; uses $S/elixir/proj
sh $S/erlang/run.sh                       # erlc +debug_info, runtime undef, xref friend pass
sh $S/erlang/attrs/run.sh
escript $S/erlang/xref_time.escript /usr/lib/erlang/lib/stdlib-4.3.1.3/ebin
sh $S/go/run.sh                           # GOPROXY=off, GOCACHE under the scratchpad (edit path)
escript $S/cost/model.escript             # ~40 s; the all-pairs N=1000 row dominates
```
Scratchpad originals: `/tmp/claude-0/-home-user-beam-sharp/e462f18b-47b0-5059-896d-359d243949c1/scratchpad/probes/60/`.

## Verification

Independent verifier report: `artifacts/verification-60.md`. All probes reproduced exactly (xref load range
differed with machine variance). It found and this brief now corrects: the F12 cite (line 11), the "only
hits" grep wording, the unsupported 0.73 s figure, "compiler-enforced" for Go (it is the go command), the
weak Gleam control, and the fixture-matched `friend.escript` and by-construction cost model. It also
confirmed the Go subtree rule with an independent probe and the Gleam non-enforcement with a git dependency.
Recommendation re-checked: it rests on the Go precedent and the single `using` check site, not on the cost
model, so it stands as a lean, not a proof.
