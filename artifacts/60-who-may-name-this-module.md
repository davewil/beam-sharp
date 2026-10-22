# Decision brief: ticket 60 / ENG-242 — Which modules may name this one?

Repo HEAD when written: `c3d50b9`. Toolchain actually used: OTP 25 (erts 13.2.2.5), Elixir 1.14.0 (built with OTP 24), Gleam 1.5.0, Elm 0.19.3, Go 1.24.7, rustc 1.97.0, rebar3 3.19.0.
The tickets cite OTP 28 and Gleam 1.18.1. **Every result below is on the older versions; see "Limits".**
Nothing in the repo outside `artifacts/` was touched. The ticket file, Linear and git were not touched.

## 1. Ticket summary

`public`/`private` (F12) controls what a module exposes. Nothing controls who may name a module. The ticket asks four things:
1. What is the unit (subtree, named group, explicit list)?
2. Which side declares (callee names who may call it, or caller declares its dependencies)?
3. Is it a third visibility marker or a separate construct?
4. What does it cost the checker?

## 2. Sub-decisions and gating order

| # | Sub-decision | Gates |
|---|---|---|
| **G** | **Is the thing restricted a *module* or a *function*?** F15 makes the directory the BEAM module. A helper in a sibling `.bs` file of the same directory is in the same module, so a directory-level rule cannot scope it. | everything below |
| 2 | Direction: callee-declared or caller-declared | 1, 3 |
| 1 | Unit and spelling (path rule, explicit scope, list) | 3 |
| 3 | Marker vs separate construct | follows from G |
| 4 | Checker cost | measured per option below |

Ask G alone first. If the answer is "module", questions 1 and 3 collapse into "which directory names", and no new syntax is needed.

## 3. Probes

Re-run any of them with the `run.sh` in its directory. Each prints raw output, and the committed `output.txt` beside it is the capture from this session. `common/build-bsc.sh WORKDIR [patch]` builds a scratch copy of `compiler/` on OTP 25 (its header lists the four patches).

### 3.0 Reference compiler on OTP 25: built, with a column-loss caveat
`compiler/` fails under plain `rebar3 escriptize` on OTP 25 because leex has no `error_location` option. Patched in the **scratch copy only**:
1. `rebar.config`: dropped `xrl_opts` and the eunit→escriptize provider hook.
2. `bs_lexer.xrl`: `TokenLoc` becomes `{TokenLine,1}`, plus an `adjust_col/3` stub. **Every reported column is therefore 1.**
3. `bs_run.erl`: `~kp` becomes `~p`.

Nothing else was changed. I did not run the repo's eunit suite on the port.
The `\x{2014}` in some diagnostics is a locale-encoding artefact of the OTP 25 console, not a compiler difference.

### Probe 01 — `probes/01-baseline-who/run.sh`: what the compiler does today
Command: `bsc -o OUT --src-root src src/Callers/<X> Go 5`, plus `bsc --api`.
```
=== Callers/PublicCall   -> 11 (exit 0)
=== Callers/PrivateCall   (calls Shop.Orders.RecomputeTotal, unmarked = private)
src/Callers/PrivateCall/PrivateCall.bs:5:1: error: Go calls Shop.Orders.RecomputeTotal/1, which Shop.Orders declares `private`   (exit=1)
=== Callers/InternalCall  (using Shop.Orders.Internal; calls its PUBLIC Recompute)  -> 15 (exit 0)
=== Callers/NoUsing       (fully-qualified call, no `using`)
src/Callers/NoUsing/NoUsing.bs:4:1: error: Shop.Orders is called but never imported   (exit=1)
=== --api of Shop.Orders           -> module Shop.Orders / int Total(int)
=== --api of Shop.Orders.Internal  -> module Shop.Orders.Internal / int Recompute(int)
```
It shows four things.
- **The gap is real.** `InternalCall` compiles. Once a function is `public`, any module can name it.
- **Ticket 60's "consumer" claim is stale.** The ticket says `RecomputeTotal/1` "lands `unclassified`" because it is neither a callback nor client API. That was true when every function was exported (ticket 24 §2 says so). Since F12's private-by-default, an unmarked `RecomputeTotal` is refused to every other module and is absent from `--api`. What remains is a helper that must be `public` because two sibling modules in one subtree share it.
- **`unclassified` is not built.** `--api` prints no boundary/callbacks/unclassified categories. `grep unclassified compiler/src` finds only an unrelated diagnostic tag (`bs_api.erl:280`, `bs_diag.erl:75`).
- **`using` is the one choke point.** A qualified call without `using` is refused (`NoUsing`). `bs_check.erl:4567` says so: "Qualified calls still require a `using` entry: those entries declare the file's dependencies."

### Probe 02 — `probes/02-option-a-internal-dir/run.sh`: Option A, built as a scratch prototype
Same B# tree compiled with the unmodified compiler and with `common/proto-a-internal-dir.patch`. The patch is 28 added and 2 removed lines in `bs_check.erl` and `bs_diag.erl`.
```
BASE:   all six modules exit=0
PROTO:  Shop/Orders (uses Internal)          exit=0
        Shop/Orders/Pricing (sibling subtree)  exit=0
        Shop/Orders/Tests (a test module)      exit=0
        Shop/Billing                         src/Shop/Billing/Billing.bs:2:1: error: Shop.Orders.Internal cannot be named from here
                                               a module under an `Internal` directory is nameable only from Shop.Orders and below.   exit=1
        Shop/OrdersExtra  (text-prefix trap)   same error, exit=1
        Shop/Reports (uses public Shop.Orders) exit=0
namespace tier, src-ns: Callers.Via does `using Shop` then Orders.Internal.Recompute(5)
        BASE exit=0 (15);  PROTO:  error: Orders.Internal is called but never imported
                                   add `using Orders.Internal` ...   exit=1
```
- **The refusal works** for direct `using`, with a segment-aware prefix.
- **A known flaw in the prototype.** The namespace-tier import path is refused only indirectly. The prototype filters the children out, so the diagnostic is the misleading "never imported", whose advice (`using Orders.Internal`) would then hit the real error. A real implementation needs its own diagnostic in `add_namespace_import`.
- The rule uses the **last** `Internal` segment, copying Go's `findInternal` (`pkg.go:1584-1587`: "the final one produces the most restrictive requirement").
- The prototype's `Internal` is a case-sensitive PascalCase segment, my choice. The repo's examples have no `Internal` module (find returned nothing), so existing programs are unaffected.

### Probe 03 — `probes/03-option-b-marker-grammar/run.sh`: can a scoped marker be spelled on the signature?
yecc `{report,true}` on the unmodified `bs_parser.yrl` and on three variants. The baseline reports 6 shift/reduce conflicts.
```
baseline  6 shift/reduce, 0 reduce/reduce
parens    visibility -> 'public' '(' modpath ')'   7 shift/reduce      (+1)
brackets  visibility -> 'public' '[' modpath ']'   6 shift/reduce      (+0)
to_kw     visibility -> 'public' 'to' modpath      6 shift/reduce      (+0)
```
Parsing with the real lexer:
```
baseline parser, line 4 `public(Shop.Orders) int Helper`: {error,{{4,1},baseline,["syntax error before: ",["int"]]}}   (expected)
parens parser:   {error,{{2,1},parens,...}}   <- line 2 is `public (int, int) Pair(int n)`, VALID today, now breaks
brackets parser: {ok,[... {signature,{2,1},'Pair',{t_tuple,...},...,public,[]}, ... ]}   both lines parse
```
- `public(Scope)` is **refused by the grammar**. Tuple return types begin with `(`, and `public (:reply, int, int) ...` is already legal.
- `to` as a keyword adds no conflict. But `grep -w 'pid to'` finds `examples/exemplars/25g-jev-server/jev_index.bs:19`, so a `to` keyword would steal an identifier already in use.
- Brackets parsed on the OTP 25 yecc; the repo's grammar header says it measured conflicts on OTP 28 with the same tool. I have not seen a version difference.

### Probe 04 — `probes/04-beam-callers-and-cost/run.sh`: BEAM enforcement and structural costs
```
OTP 25, erts 13.2.2.5
1a friend:go(2)=6 stranger:go(2)=6 stranger:dyn(2)=6          (any module, and apply/3, reaches an exported helper)
1b callee.S: {call,1,{f,4}}. % helper/1                         (in-module call to an exported fn is a LOCAL call)
1c stranger.S: {call_ext_only,1,{extfunc,callee,helper,1}}      (cross-module = call_ext)
2a 1e6 remote calls: plain=11618 us, with stacktrace caller guard=424459 us (ratio 36.5)
2b friend in BODY position : 7
2c friend in TAIL position : {rejected,{not_visible,erl_eval}}   <- tail call erases the friend frame
2d stranger (shell)        : {rejected,{not_visible,erl_eval}}
3  5e6 helper calls: same-module=57445 us, other-module=60551 us, 0.62 ns extra/call   (earlier runs: -0.15, -1.74 ns)
3b bytes (+strip): one.beam 744; two_a.beam 708 + two_b.beam 636 = 1344
```
- **Runtime caller enforcement is not viable.** Reading the stack costs about 36 times a plain call here, and it falsely rejects a legitimate friend that calls in tail position (2c). `apply/3` bypasses any static check (1a). So "compile-time check on the caller, or nothing" is accurate for the BEAM, and the check cannot extend to Erlang, Elixir or foreign callers.
- **Ticket 18's structural claim holds.** An exported function is still called locally inside its module (1b), and the module has one export table. A function cannot be exported to only some callers.
- **Splitting a helper into its own module costs bytes.** The toy's stripped beams go from 744 to 1344 bytes (+600, +81%). That is a fixed per-module overhead, and a real helper amortises it.
- **Splitting costs no measurable call time on OTP 25.** The remote-minus-local difference sits inside run-to-run noise (+0.62, -0.15, -1.74 ns). Ticket 41 cites `01d` at +6% remote on OTP 28. These are different versions and loop shapes. I neither confirm nor refute 6%.

### Probe 05 — `probes/05-go-rust-internal/run.sh`
```
go build ./orders           exit=0     (importer is the parent)
go build ./orders/pricing   exit=0     (importer is in the parent's subtree)
go build ./billing          billing/b.go:2:8: use of internal package example.com/shop/orders/internal/recompute not allowed   exit=1
go build ./ordersextra      same error   exit=1                       (segment-aware, not a text prefix)
go test ./orders/internal/recompute   ok                              (a _test.go inside the tree may name it)
rustc: error[E0603]: function `recompute` is private   (r.rs:6, the call from `mod billing`; `pub(in crate::orders)` allowed orders and orders::pricing)
```

### Probe 06 — `probes/06-gleam-internal/run.sh` (Gleam 1.5.0, two packages joined by a path dependency)
```
1 in-package, incl. a sibling subtree imports shoplib/internal/recompute   exit=0
2 app imports shoplib                                                       exit=0
3 app imports shoplib/internal/recompute  (internal_modules = ["shoplib/internal", ...])   Compiled, no warning, exit=0
4 app calls an @internal pub fn of a non-internal module                                   Compiled, no warning, exit=0
```
In 1.5.0 `internal_modules` and `@internal` are **not enforced at compile time**; they are documentation hints. The ticket's Gleam is 1.18.1, so I cannot say what 1.18.1 does.

### Probe 07 — `probes/07-elixir-erlang-who/run.sh`
```
a) Billing.bill(2) via a @moduledoc-false module = 6  (compiled and ran; nothing refused)
b) TRACER REFUSES Billing -> Orders.Internal.recompute/1 (line 2), friends=[Orders]
   (a tracer only REPORTS; both modules still compiled and loaded: Billing.bill(2)=6)
c) xref {use,{callee,helper,1}} (functions that use it) = [{friend,go,1},{stranger,go,1}]
```
- Elixir's `@doc false` / `@moduledoc false` do not restrict.
- Elixir's compile tracer **is** handed the caller's `env.module` at every remote call. So a callee-declared friend rule is a small addition at the point where the checker knows both names. `bsc` has that (`import_env/4` receives `Self`).
- Erlang has only after-the-fact analysis (xref), and xref needs `+debug_info` beams.

### Probe 08 — `probes/08-elm-attempt/run.sh`: could not be run
`elm make` stops with `ProxyConnectException "package.elm-lang.org" 443 ... 403`. No Elm result exists in this brief. I cite nothing about Elm's `exposed-modules` rule.

### Probe 09 — `probes/09-sites-and-prefix/run.sh`: grep of the sites in the repo compiler
```
1a visibility readers: bs_api.erl:152, bs_api.erl:158, bs_check.erl:365, bs_check.erl:376, bs_emit.erl:141 (is_public: element(7,F) =:= public); bs_check.erl:1524 constructs `public`
1b add_import bs_check.erl:498; add_module_import/3 bs_check.erl:512; qualified_module 4569; require_imported 4577
1c children/2 already uses prefix ++ "." (segment-aware)
1d no catch-all message/1 clause in bs_diag (a new error tag without a clause crashes the printer)
text prefix lists:prefix("Shop.Orders","Shop.OrdersExtra") = true   (wrong)
segment prefix = false
```

## 4. Neighbour survey

Only installed sources are cited.

- **Go**, `/usr/local/go/src/cmd/go/internal/load/pkg.go`:
  - `:1473-1476`: "An import of a path containing the element “internal” is disallowed if the importing code is outside the tree rooted at the parent of the “internal” directory."
  - `:1582-1596` (`findInternal`): the last `internal` element governs.
  - `:1573-1574`: `"use of internal package %s not allowed"`.
  - Probe 05 shows the behaviour. The semantics are exactly "subtree rooted at the parent", and tests inside the tree may name it.
- **Rust**: `pub(in path)` is a function-level scoped marker (probe 05). rustc source is not installed, so no line citation.
- **Gleam 1.5.0**: binary only, no source, no citation. Probe 06 shows `internal_modules` and `@internal` unenforced in this version.
- **Elixir 1.14**: `/usr/lib/elixir/lib/elixir/` holds `ebin` only, so no source citation. Probe 07 shows the behaviour: no restriction exists, and the tracer API carries the caller.
- **Erlang/OTP**:
  - `erl_lint.erl:258-259`: `format_error(export_all) -> "export_all flag enabled - all functions will be exported"`.
  - `xref_base.erl:411-412`: `analysis({use, F}, functions) -> make_query("domain (E || ~tw : Fun)", [F])`.
  - `xref.erl:609`: `'exports_not_used'`.
  - Erlang has no caller-scoped export.
- **Elm**: unverifiable here (probe 08).
- **C#**: `dotnet` is not installed. I did not verify `internal` or `InternalsVisibleTo`. The ticket's claim that C# `internal` is assembly-scoped is from the ticket, not from me.

## 5. Measurements

| Quantity | Value | Command |
|---|---|---|
| Option A checker delta (prototype) | 28 added, 2 removed lines, 2 files (`bs_check.erl`, `bs_diag.erl`); no grammar, lexer, emit or parser change | `grep -c '^+[^+]' common/proto-a-internal-dir.patch` |
| Option A bytes in the `.beam` | 0 by construction: dependents are checked from source (`bsc.erl:270 type_world`). Not measured by diffing beams. | read |
| Option A, extra module for the helper | +600 bytes stripped for a toy helper (744 → 1344); call time within noise on OTP 25 | probe 04 §3, §3b |
| Option B grammar | `public(Scope)` +1 conflict and breaks tuple returns; `public[Scope]` +0 | probe 03 |
| Option B sites to touch | 6 visibility readers (probe 09 1a) + grammar + import filter + new diagnostic | probe 09 |
| Runtime guard | 36.5 times the plain call, false reject on a tail call | probe 04 §2 |

## 6. Options

All three are compile-time and source-only. The BEAM cannot enforce any of them (probe 04), and ticket 22 already accepted this.

### Option A — the callee's *directory* says it: `Internal/` is nameable from the subtree under its parent (no syntax)
```
Shop/Orders/Orders.bs              module Shop.Orders         using Shop.Orders.Internal; Total() calls Recompute  -> compiles
Shop/Orders/Internal/Recompute.bs  module Shop.Orders.Internal  public int Recompute(int n)
Shop/Orders/Pricing/Pricing.bs     module Shop.Orders.Pricing   using Shop.Orders.Internal                         -> compiles
Shop/Orders/Tests/Tests.bs         module Shop.Orders.Tests     using Shop.Orders.Internal                         -> compiles
Shop/Billing/Billing.bs            using Shop.Orders.Internal           -> refused: "Shop.Orders.Internal cannot be named from here"
Shop/OrdersExtra/OrdersExtra.bs    using Shop.Orders.Internal           -> refused (segment prefix)
```
These are the probe 02 fixtures; the outputs are in section 3 above.
- **Compiler work:**
  - A `may_name(M, Self)` test in `add_import` (`bs_check.erl:498`), same shape as the existing `children/2`.
  - A filter in `add_namespace_import`, with its own diagnostic (the prototype's misleading message is the proof it is needed).
  - One `bs_diag` `built/2` clause and one `message/1` clause.
  - `bsc --api` could print the restriction (not prototyped).
- **Prior art:** Go `internal/`, same semantics (probe 05, `pkg.go:1473`).
- **Why this answers G with "module":** F15 already makes the directory the unit. The rule is decidable by `ls`, which ticket 23 §10 wants. The word `Internal` matches no C# meaning. Its meaning is "subtree of my parent", so the semantics are documented rather than borrowed (ticket 22's false-friend rule).
- **Strongest counterargument:**
  - The restriction lives only in the path. A reader of `Recompute.bs` sees `public` and nothing says "internal".
  - A reserved directory name is a hidden keyword.
  - Scoping a helper that currently sits next to the API means moving it into a new module. The toy cost is +600 bytes for the extra beam, plus whatever ticket 41's 6% remote-call figure is on OTP 28 (not confirmed here).
  - Rewriting call sites is needed too.

### Option B — the callee's *signature* says it: `public[Shop.Orders]` (function-level, explicit scope)
```
module Shop.Orders
public int Total(int n)
Total(n) -> RecomputeTotal(n)
public[Shop.Orders] int RecomputeTotal(int n)       // nameable only from Shop.Orders and below
RecomputeTotal(n) -> n * 2
```
```
module Shop.Billing
using Shop.Orders
Go(n) -> Shop.Orders.RecomputeTotal(n)              // refused under B; compiles today and under A, because under A the helper stays `public`
```
- **Compiler work (estimate from grep; not prototyped):**
  - Grammar: `visibility -> 'public' '[' modpath ']'` (+0 conflicts; probe 03).
  - Encoding: vis becomes `{public, Scope}`. All six `=:= public` readers (probe 09 1a) must treat it as exported, or the function is silently not exported, the failure F12's amendment named.
  - A `scoped` table beside `private_table` (`bs_check.erl:555`) so the refusal names the rule.
  - `private_callee`-style check (`bs_check.erl:4481`) at the qualified call, since the function is in the export set and import resolution finds it.
  - Diagnostic clauses.
  - I expect this to be several times Option A's 30 lines. That is an estimate.
- **Strongest counterargument:** it is a third visibility marker on a function. Ticket 60's own note says a rule about modules "may not belong on a function at all". It also tempts unscoped drift: `public[Shop]` is easy to write and then means everyone in the context.

### Option C — the *caller* declares: an allow-list in the caller's `index.bs`
```
module Shop.Reports
using Shop.Orders
depends [Shop.Orders]          // Shop.Reports may name only these
...
using Shop.Billing             // refused: Shop.Billing is not in Shop.Reports's depends
```
- **Compiler work (estimate, not prototyped):**
  - Parse a `depends` declaration (`index.bs` already carries declarations).
  - Compare each `using` to it, at the same `add_import` site as A.
  - Add a diagnostic.
- **Strongest counterargument:**
  - `using` already is the caller's dependency list (`bs_check.erl:4567`), so `depends` restates it.
  - The guard sits on the side the violator edits. An agent that adds a test module that calls the helper also edits that module's own `depends`.
  - It protects no particular callee, only the caller's declared architecture. That is a layering feature, and it does not meet the stated consumer.

## 7. Recommendation

**Answer G with "module", spell it as Option A, and defer Option B.** I recommend A over B, and I expect to hold that view unless David's own reading of the programs differs.

1. A is the cheapest answer measured. The checker delta is 30 changed lines in two files with no grammar change, and all the cases in probe 02 behave as intended. B needs a spelling that does not break tuple-returning signatures (`public(X)` does; `public[X]` does not), a change to six readers whose silent failure mode is "function not exported", and a new refusal path.
2. A matches F15 and the only mature precedent. Go's `internal/` has exactly these semantics, tests inside the tree may name it, and the segment-aware prefix is the same one `children/2` already uses.
3. The ticket's stated consumer has mostly shrunk. After F12, unmarked helpers are already private and absent from `--api`. What is left is a helper shared across a subtree, which is what a directory naturally models.
4. C has the declaring side wrong for the consumer: the party being restricted writes the list.
5. Open points for David, to be decided with the code in front of him:
   - **The name.** `Internal` is my choice, not a decision. It needs a grep of the tickets for an existing convention before it is fixed.
   - **Top-level `Internal/`.** In the prototype, a top-level `Internal` module has an empty parent, so it is open to everyone. Go behaves the same way; whether B# should refuse it is open.
   - **Whether `bsc --api` shows the restriction.** I did not prototype this.
6. The deferral of B should wait for a **second occurrence**: a helper that must be scoped but cannot reasonably live in its own directory. One occurrence gets a sentence, not a feature.

## 8. Limits and what I could not verify

- **Versions.** Everything ran on OTP 25, Elixir 1.14, Gleam 1.5.0, rustc 1.97.0, Go 1.24.7. The repo cites OTP 28.5 and Gleam 1.18.1. Cross-version risk is highest for: (a) the 6% remote-call cost (my measurement is noise-level on OTP 25), (b) Gleam's internal-module enforcement, which may well be stronger in 1.18.1, (c) yecc conflict counts (same tool, newer version unseen).
- **bsc.** It was run through a scratch OTP 25 port. All reported columns are 1, so column-sensitive diagnostics differ from the real compiler. Claims about the reference compiler's *behaviour* rest on this port plus reading the source. I did not run the repo's eunit suite or gates on either the port or the prototype, so I cannot claim the prototype breaks nothing.
- **Options B and C** are not prototyped. Their line-count and site claims are estimates from grep (probe 09) and from probe 03's grammar measurement.
- **Ticket drift.** The ticket cites `bs_check.erl:407-425` and `add_module_import/5` at `0b761f6`. That SHA is not in this checkout. At HEAD `c3d50b9` the site is `add_import` (498) and `add_module_import/3` (512), and it reads `types` as well as exports. The ticket's substance holds: no `internal`, `friend`, `sealed` or `visible_to` exists in the compiler (grep finds only unrelated comments).
- **Not verified:** Elm (network blocked, probe 08), C# `internal`/`InternalsVisibleTo` (no dotnet), Elixir sources (not installed), and anything about OTP 28 behaviour.
- **Prototype scope.** It checks `using` only. It does not cover type-only imports beyond what `add_module_import` already does, `--api` output, or the REPL.

## Verification errata (independent verifier, see 60-verification.md)

Probes 01–07, 09 reproduced; 08 (Elm) not runnable. Corrections that supersede the text above:
- "Stripped beams 744 to 1344 (+600)" is mislabelled (`erlc +strip` does not strip). With `beam_lib:strip`: 322 to 567, about +245 bytes (+76%).
- Reader count is 5 readers plus 1 constructor, and the grep missed `bs_check.erl:299`, `:479` and `vis_source` at `:2465`; Option B's cost is understated.
- Unreconciled: under Option A a `Tests` module inside the subtree may name `Internal`, which re-admits the test-targets-helper drift the ticket was about.
- Ticket 41 line 490 already uses `Internal/` as a sub-module name; the "no C# meaning / needs a ticket grep" point was asserted, not done.
- Option B and C costs are estimates, not measurements; recommendation point 1's "measured" applies to Option A only. The 36x stacktrace-guard ratio (39.5x on re-run) is against a trivial body (~0.45 us absolute). The Gleam null result has no negative control.
