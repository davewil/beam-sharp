# Brief for ticket 60 — which modules may name this one? (ENG-242)

Status: decision brief for David. The ticket stays open. Nothing under `wayfinder/` or `compiler/` was edited.
Measured at HEAD `a5af573` on Linux x86_64 (OTP 28, rebar3 3.27.1, Elixir 1.20.4, Gleam 1.19.1, Elm 0.19.3, Go 1.24.7).
Every probe is in `artifacts/probes/60/`; `run.sh` reruns them from a scratch dir and `output.txt` is its last output.

## 1. What the ticket claims, checked

| Claim | Result |
|---|---|
| `add_module_import/5` reads only the callee's export set; cited `bs_check.erl:407-425` | Half right. The function is `add_module_import/3` now, at `bs_check.erl:512-528` (HEAD), and it also reads the callee's `types`. The point stands: it never reads who the importer is. `add_import/7` at `:498` has `Self` and `Mode` in hand and does not use `Self`. |
| no `internal`, `friend`, `sealed` or `visible_to` anywhere | Confirmed. `run.sh` section 1 greps `compiler/src`, `LANGUAGE.md` and `wayfinder/issues`. The only hits are prose: ticket 22's own sentence, and "sealed inside its declaration" in tickets 05 and 16. No later ticket decided any of it (grepped `internal`, `friend`, `visible`). |
| 24 §2: "every function in an aggregate is exported today", so `RecomputeTotal/1` lands `unclassified` | **Stale.** 24 resolved 2026-08-13; F12 made private the default on 2026-08-17. An unmarked helper is private. `bsc --api` omits it and `bsc … Recompute 5` refuses to run it (output section 1). The `unclassified` case now exists only for a helper that must be `public` because a sibling module calls it. |
| 18 §5: a function has one entry label, so per-function export control is not cheap | Confirmed, and it bites here (section 1 of output). `public Recompute` disassembles with a leading `{test,is_integer,…}`; the private one has none. Any helper a sibling may call is exported, boundary-guarded and callable from `erl` by anyone. Enforcement can only be a source-level check on the caller. |

The consumer claim, shown on a real program. Two modules need the same helper:

```
Shop/Orders/Orders.bs   Total (the client API), and a helper Recompute that Shop.Billing needs
Shop/Billing/Billing.bs using Shop.Orders;  Invoice(c) -> Recompute(c)
Web/Handler/Handler.bs  using Shop.Orders;  Handle(c)  -> Recompute(c)     // outside Shop
```

Today, with `Recompute` left private, Billing is refused, and the diagnostic hands the agent the drift:

```
Billing.bs:6:19: error: Invoice calls Recompute/1, which Shop.Orders declares `private`
  a private function is not exported, so no other module can
  reach it. Mark it `public` in Shop.Orders, or move the call inside it.
```

With `public Recompute`, Billing and Web.Handler both compile (`bsc … Web/Handler Handle 5` prints `105`). The manifest
that ticket 24 builds its test boundary from now reads `int Recompute(int)` / `int Total(int)`: the client API and the
sibling-only helper are indistinguishable. That is the real residue of 24's `unclassified`, and it is smaller than
the ticket describes: a purely local helper is already unreachable by tests.

Direction (sub-decision 2) is not open in practice. A caller-side declaration cannot restrict anything: Web.Handler's
`using Shop.Orders` is already the caller declaring what it depends on, and nothing refuses it. A rule that refuses must
live on the callee's side. (A project-wide allow-list per caller, Elixir `Boundary` style, is a different design; the
library is not installed here, so UNMEASURED.)

## 2. The gating question, asked alone

> When a helper must be callable by sibling modules but not by the world, does the compiler **derive** the permitted
> callers from where the helper's module sits in the directory tree, or does the helper's module **write them down**?

The granularity (module or function), the marker-or-construct question and the spelling all follow from this one.
Both programs below are module-granular so the comparison isolates this single variable (see section 5 on function granularity).

### Option A — derived from the tree: a module under an `Internal` directory is nameable only from under its parent

```
Shop/Internal/Totals/Totals.bs     module Shop.Internal.Totals
                                   public int Recompute(int cents)
                                   Recompute(cents) -> cents + 100
Shop/Orders/Orders.bs, Shop/Billing/Billing.bs, Shop/Reports/Reports.bs    using Shop.Internal.Totals
Web/Handler/Handler.bs                                                     using Shop.Internal.Totals
```

Prototype bsc (`probes/60/patch-position.diff`), output section 2a:

```
Shop/Orders, Shop/Billing, Shop/Reports   -> compile, rc=0   (Reports is a module added later; nobody edited anything)
Web/Handler -> Handler.bs:3:1: error: Web.Handler cannot name Shop.Internal.Totals
                 an `Internal` module is visible only under Shop.
control: the unpatched bsc compiles Web/Handler and runs it (105).
bsc --api Shop.Orders           -> int Total(int)              (the helper is gone from the client API)
bsc --api Shop.Internal.Totals  -> int Recompute(int)
```

- **Compiler delta.** One function, `reach/2`, in `bs_check.erl`, called from `add_import/7` (`:498`) in `strict` mode, and a
  `not_visible` descriptor plus message clause in `bs_diag.erl`. No parser, lexer, emitter or world-entry change, because the
  rule needs only `M` and `Self`, which `add_import` already has. 27 lines added, 2 removed, 2 files.
- **Existing suite.** `rebar3 eunit`: 1434 passed on unpatched HEAD and 1434 on the patch. `bin/check-diagnostics.sh`: ok
  (it requires every minted tag to have a `message/1` clause, which is why the diag lines are not optional). Wall times
  (10m13s, 8m14s) differ by more than the patch could cause, so they are noise, not a speed claim.
- **Rough edges the prototype shows.** `using Shop.Internal` (a namespace import) from Web silently drops the hidden module,
  and the user then gets `calls Recompute/1, which nothing declares`, which is true and unhelpful (output 2a, `Web/NsHandler`). A
  real build needs a hint there, like `private_callee/3` (`bs_check.erl:4331`) gives for `private`. Not built: LOC UNMEASURED.
  Lenient mode (`--api`, `types_of`) is deliberately unchecked.
- **Consumer test.** An agent-written test module `Shop.OrdersTests` that names the helper **compiles** (rc=0); the same test at
  top level, `OrdersTests`, is refused. So the rule classifies the helper (it is not in the client API) but does not keep
  tests off it if tests live under `Shop`. Where tests live is open (24 hands it to the module-system fog).
- **Cost of the shape.** The helper must be its own module (a directory), so Orders' call to it becomes a remote call and it
  adds a `.beam`. Measured (`probes/60/erlang/bench_call.erl`, 5M calls x 25 warm runs): remote costs 0.95, 1.92 and 1.48 ns
  more per call in three runs; the noise floor (max-min of the local loop) was 21-38 ms per 5M calls. The direction is real, the
  size is "one to two nanoseconds on a trivial body" and no better than that.
- **Strongest counterargument.** The rule lives in a directory *name*. Rename `Internal` or move it one level up and the
  meaning changes with no source edit; `index.bs` is the only other magic file name in the language and that one is checked by
  F15. A C# reader will also bring `internal`'s assembly meaning to the word (ticket 22's false-friend rule); here the
  word is a directory, not a keyword, but the collision is there. Go has exactly this shape and the same weakness.

### Option B — written down: the helper's module lists its friends

```
Shop/Totals/Totals.bs     module Shop.Totals
                          friend Shop.Orders
                          friend Shop.Billing
                          public int Recompute(int cents)
Orders, Billing, Reports, Web.Handler all `using Shop.Totals`
```

Prototype bsc (`probes/60/patch-written.diff`), output section 2b:

```
Shop/Orders, Shop/Billing -> compile, rc=0
Shop/Reports -> Reports.bs:3:1: error: Shop.Reports cannot name Shop.Totals
                  Shop.Totals lists its `friend` modules and Shop.Reports is not one of them.
Web/Handler  -> Handler.bs:3:1: error: Web.Handler cannot name Shop.Totals
                  Shop.Totals lists its `friend` modules and Web.Handler is not one of them.
control: the unpatched bsc refuses the file: `friend` is not B# (it reports `using Shop.Totals` names no module).
bsc --api Shop.Totals  -> int Recompute(int)        (the manifest does not know about friends)
```

- **Compiler delta.** A new keyword: `friend` in `bs_lexer.xrl`, `friend_decl` in `bs_parser.yrl`, a `friends`
  field in the `World` entry built in `bsc.erl`, `may_name/3` in `bs_check.erl` called from `add_import` and from the namespace
  branch, `not_visible` in `bs_diag.erl`. 28 lines added, 4 removed, 5 files. `rebar3 eunit` 1434 passed (so no
  corpus program uses `friend` as an identifier); `check-diagnostics.sh` ok.
- **What it buys that A does not.** The permission is greppable in the callee and survives moving a directory. It can name a
  module in another tree (a test module, a sibling application), which a path rule cannot. The helper may keep its place in
  `Shop/Orders` if the construct is later made function-level.
- **What it costs.** The prototype is fail-open: a module with no `friend` lines is nameable by anyone, so forgetting a line
  hides nothing. And when `Shop.Reports` is added, the refusal tells the agent to edit another module's header. The one-line fix
  (`friend Shop.Reports`) is the unreviewed edit the ticket wants to stop, in a new place. The manifest needs a change too
  (`--api` must print the friends), which A gets for free from the path.
- **Strongest counterargument against B** is the reverse of A's: it is a list, and lists rot. Every new sibling is an edit to the
  callee, and the agents the language is written for will make that edit to turn the error green.

### Option C — build nothing; correct the premise

Leave `public`/`private` as shipped. Sibling-needed helpers are `public` and show in `--api`; document that the client API is
"the public functions whose names a module outside the namespace calls", derived by a gate rather than by the compiler.
Cost: zero compiler work. Against it: the diagnostic above tells the agent to "Mark it `public`", and nothing ever tells it to stop.

## 3. How neighbouring languages answer

| Language | Mechanism | Does the compiler refuse an outside importer? | Evidence |
|---|---|---|---|
| **Go** | `internal` path element: importable only from the tree rooted at the parent of `internal` | **Yes**, at build. Placement sets the scope: with `internal` under `shop/orders`, even sibling `shop/billing` is refused; under `shop`, only `web` is. | `probes/60/go`; rule at `$GOROOT/src/cmd/go/internal/load/pkg.go:1472-1477` (`disallowInternal`). Error: `use of internal package example.com/app/shop/internal/totals not allowed` |
| **Gleam** | `internal_modules = [...]` in `gleam.toml`, and `@internal` on a definition | **No.** A dependent package that imports `lib/internal/helper` and calls `lib.also_hidden` **builds and runs**, no warning. The flag only removes them from the package interface and docs. | `probes/60/gleam`: `gleam build` rc=0, `gleam run` prints `Running app.main`. `gleam export package-interface` lists `lib` -> `total` and `lib/other` -> `sibling` only. The binary contains a publish-time message about modules that "leak internal types in their public API and cannot be published"; UNMEASURED because Hex is blocked. |
| **Elixir** | `@moduledoc false` (a documentation flag) | **No.** A module outside `Shop` calls `Shop.Orders.Internal.recompute/1` and compiles with no diagnostic. `Code.fetch_docs` reports the moduledoc as `:hidden`. `mix xref` has `--exclude` for reporting only. | `probes/60/elixir`. The install holds only `.beam` files (no `.ex` source), so I probed behaviour and read `mix help xref`, not source. |
| **Erlang** | `-export` only. `xref` is an external, closed-world analysis | **No** at compile (`erlc -Wall`: 0 diagnostics). With `+debug_info`, `xref:q(s, "E || (Fun) shop_orders:recompute/1")` lists the callers, and picking the ones outside `shop_` is a hand-written rule. OTP xref has no ignore attribute (0 matches in `tools-4.1.4/src/xref*.erl`); `-ignore_xref` is rebar3's (2 matches in its `rebar_prv_xref.beam`). | `probes/60/erlang`. Operators documented at `tools-4.1.4/src/xref.erl:413-428`; `exports_not_used` at `:1551`. My first xref run failed because I compiled without `+debug_info`; fixed and rerun, noted here. |
| **Elm** | `exposed-modules` in a package's `elm.json` | Not measurable here. `elm make` needs `package.elm-lang.org` for `elm/core` and the proxy returns 403 (`probes/60/elm`, output section 7). **UNMEASURED.** | |

Reading: of Erlang, Elixir and Gleam, none refuses an outside importer, and Elm could not be measured. The one enforced rule
I found (Go, which the ticket did not name) is derived from the path, with a renamed directory as its failure mode. That is evidence for
A's shape, not for B's, but it is one language.

## 4. Recommendation

Option A. It is derived from the layout F15 already makes meaningful, adds no keyword and no list that rots, and it is the
only option whose behaviour on a *new* sibling (`Shop.Reports` accepted without anyone editing anything) is right. It also
answers 24's classification without a manifest change, because the helper is a different module. Take C instead if you judge
that a helper forced `public` by a sibling is rare enough: the 24 premise that motivated this ticket is weaker than it reads.

If you choose A, the follow-ups are small and separate: whether the directory is spelled `Internal`, the namespace-import hint,
and whether a function-level form is wanted.

## 5. Unmeasured, and not built

- **Function granularity** (a marker beside `public`/`private` on the signature). Not prototyped. By grep, a third visibility value
  touches the `visibility` nonterminal (`bs_parser.yrl:325-326`), a lexer rule, and five readers of the visibility field
  (`bs_check.erl:299, 365, 376, 479`; `bs_emit.erl:141`), and the exports/private tables need a third state. LOC UNMEASURED.
  The BEAM side is settled by 18 §5: such a function is exported and guarded regardless.
- Elm's refusal text, Gleam's publish-time check, Elixir `Boundary`, Go behaviour with a test-only importer.
- Whether tests under the helper's subtree should be allowed (a layout question, owned by 24's module-system fog).
- Time for the clean-clone gate run (`gates.sh`, ~10 min a tree) is not in `run.sh`; observed results are in `gates-output.txt`.
  A first attempt ran two suites in parallel on 4 cores, hit a 5 s test timeout ("tests were cancelled"), and was discarded and rerun sequentially.

## 6. Probes and how to rerun

- `artifacts/probes/60/run.sh` — everything except the slow gate run; prints tool versions first; output in `output.txt`.
  - `src/` — today's program (Shop.Orders, Shop.Billing, Web.Handler). `disasm.escript` shows the boundary guard.
  - `src-position/`, `patch-position.diff` — option A. `src-written/`, `patch-written.diff` — option B. `run.sh` clones HEAD, applies each patch, builds it.
  - `gleam/`, `elixir/`, `erlang/` (with `bench_call.erl`), `elm/`, `go/` — the surveys.
- `artifacts/probes/60/gates.sh` — `rebar3 eunit` and `check-diagnostics.sh` on HEAD and both patched clones. Slow.
- Every control is in the output: unpatched bsc accepts the program A refuses, unpatched bsc refuses B's syntax, `Shop.Reports` and
  `Shop.OrdersTests` are the "should be accepted" cases beside the refused ones.
