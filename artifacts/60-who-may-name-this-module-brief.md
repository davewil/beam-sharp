# Brief: ticket 60 (ENG-242), who may name this module

Status: **OPEN - for human review.** Nothing here resolves the ticket, edits `compiler/`, or touches Linear.
Compiler measured at `712b9e9`. All probes: `sh artifacts/probes/60/run.sh` (writes `<dir>/run.out`).

## Ticket and gating question

`wayfinder/issues/60-which-modules-may-name-this-one.md`: a module controls *what* it exposes (F12) but not
*who* may name it. Four sub-questions: unit, direction, marker-vs-construct, checker cost.

**Gating question, asked alone:**

> Is "who may name this module" a fact about **where the module sits** (its path), or a fact the module
> **declares**?

If it is the path, the unit is a subtree (nothing else a path can express), the direction is callee-side,
there is no marker to place, and the cost is a function over two names. If it is a declaration, then unit,
direction and marker are three further decisions. So the other three follow from this one.

## Findings that contradict or date the ticket (read first)

1. **Ticket 22's false-friend premise is wrong about Go.** 22/60 say a subtree *"is not what `internal`
   means anywhere else"*. Go's `internal` directory rule is exactly a subtree rule, enforced by the
   compiler driver (`probes/60/go/run.out`). C#'s `internal` is assembly-scoped; Go's is not. The word is not a
   false friend in Go. It would be one only for a C#-only reader.
2. **Gleam's `internal_modules` / `@internal` refuse nothing** (Gleam 1.19.0, `probes/60/gleam/run.out`). A
   dependent package that imports the internal module and calls the `@internal` function builds with exit 0
   and no warning. Gleam only drops the module from generated docs. So "survey what each language's word
   means" gives: C# assembly-scoped, Go subtree-scoped and enforced, Gleam documentation-scoped.
3. **Ticket 24's consumer is already served by F12 for same-module helpers.** 24 §2 wrote
   `RecomputeTotal/1 -> unclassified` when *"every function in an aggregate is exported today"*. F12 landed after.
   A test module calling a `private RecomputeTotal` is refused today:
   `Probe calls Shop.Orders.RecomputeTotal/1, which Shop.Orders declares private` (`probes/60/bsc/run.out`).
   24 never mentions F12 (`grep -n -i 'F12\|private' wayfinder/issues/24-testing-story.md` is empty). What is
   left unserved is a **sub-module** helper that has to be `public` so its parent can call it.
4. **The cited site moved.** The ticket says `bs_check.erl:407-425`. At `712b9e9` `add_module_import/3` is
   `bs_check.erl:511-525` (15 lines), reached from `add_import/7` (`:497-507`). The claim itself (it reads only
   the callee's export set) still holds.
5. **`using` is the only way in.** A qualified call with no `using` is refused:
   `Shop.Orders.Cache is called but never imported` (`probes/60/bsc/run.out`, module `Other/NoUsing`; the
   rule is `bs_check.erl` import resolution, 41 §5). So a check at `add_import` cannot be bypassed by
   qualifying. The check stays at the import line, not at call sites.
6. **A nested module already compiles.** `Shop.Orders.Internal.Cache` inside `Shop/Orders/` compiled and an
   outsider ran it: `Other.Thing.Go 4 -> 8`, exit 0 (`bsc/run.out`). A path segment named `Internal` is legal
   today, so Option A changes the meaning of a legal name. The corpus has **0** such segments in 88 module
   names (`proto/run.out`, `proto/mods.txt`).

## Sub-decisions

| # | Sub-decision | Gated by |
|---|---|---|
| G | path-derived or declared (above) | none |
| 1 | unit: subtree / list / group | G |
| 2 | direction: callee names callers, or caller lists dependencies | G (path-derived forces callee-side) |
| 3 | third visibility marker or separate construct | G (a path rule has no marker at all) |
| 4 | checker cost | measured per option below |

Caller-declared direction (Boundary-style: a caller lists what it may depend on) is **not probed**. Boundary is
not installed and hex is unreachable (`probes/60/elixir/run.sh` header). My argument against it is reasoning,
not evidence: the file being restricted writes its own restriction, so an agent that hits the error edits its
own header. I do not offer it as an option.

## Evidence table

| claim | probe | result | verdict |
|---|---|---|---|
| `using` needed before any qualified call | `probes/60/bsc/run.sh` | `never imported` error when absent (see finding 5) | confirmed; add_import is the sole chokepoint |
| private same-module helper unreachable from a test module | `bsc/run.out` | `Probe calls ...RecomputeTotal/1, which ... declares private`, exit 1 | confirmed; 24's `unclassified` is closed by F12 |
| a public sub-module is nameable by any outsider today | `bsc/run.out` | `Other.Thing` uses `Shop.Orders.Internal.Cache`, prints 8, exit 0 | confirmed; this is the real gap |
| Go enforces a subtree rule | `go/run.out` | `use of internal package .../orders/internal/cache not allowed` from `billing` and `other`; `orders` and `orders/sub` build, exit 0 | confirmed |
| Gleam enforces `internal_modules` | `gleam/run.out` | exit 0, no diagnostic; docs omit the module | **refuted**; docs-only |
| Elixir `@moduledoc false` restricts callers | `elixir/run.out` | compiles; `Other.Thing.go(4)` is 8; `Code.fetch_docs` says `:hidden` | refuted; docs-only |
| Elixir xref can enforce | `elixir/run.out` | `mix xref callers` lists `other/thing.ex` and `orders.ex`; it reports, it does not refuse | listing tool only |
| Erlang can declare callers | `erlang/run.out` | `-moduledoc false` gives `hidden`; `other_thing:go(4)` is 8; `xref:analyze({module_use,..})` finds the outsider after the fact | no declaration exists; external audit possible |
| Elm hides unexposed modules | `elm/run.out` | **not testable offline** (`ProxyConnectException package.elm-lang.org 403`) | unverified |
| segment-aware prefix is needed | `proto/run.out` | `lists:prefix("Shop.Orders","Shop.OrdersX") = true`; the segment-aware rule refuses `Shop.OrdersX` | confirmed trap |
| the rule is cheap | `proto/run.out` | 765,600 checks in 866 ms = 1.13 us/check (one run, no spread) | fine at this scale |
| existing corpus is unaffected | `proto/run.out` | 88 modules, 7,656 ordered pairs, **0** refused | confirmed |

Two expectations in my own prototype table were wrong on first run (`Shop.Billing -> Shop.Internal`, and
`Other -> Internal.X`, which I expected refused). The function was right and I was wrong: the parent of
`Internal` is `Shop` (or empty, meaning the whole source root), which is Go's rule. I corrected the expected
values and left a comment at each in `proto/run_proto.escript`. Two probes also hit setup mistakes of mine, fixed
without changing what they assert: xref needs `debug_info`, and a first Elixir `fetch_docs` match was wrong.

## Neighbour survey

- **Go** (installed 1.24.7). `/usr/local/go/src/cmd/go/internal/load/pkg.go:1472` `disallowInternal`;
  `findInternal` `:1582-1596` (last `internal` segment wins, "most restrictive"); the decision is
  `:1563-1564` `parentOfInternal := p.ImportPath[:i]; if str.HasPathPrefix(importerPath, parentOfInternal)`.
  `HasPathPrefix` is segment-aware: `.../cmd/go/internal/str/path.go:16-28`. The rule is the callee's *path*; the
  callee writes nothing.
- **Gleam** (binary only, 1.19.0; no source installed, so behavioural probe only). Docs-hiding, not enforcement
  (above). `strings` on the binary shows a publish-time message "These modules leak internal types in their
  public API and cannot be published". I could not exercise it (needs hex). Treat as unverified.
- **Elixir** (source installed). `lib/elixir/lib/elixir/lib/module.ex:318-320`: `@moduledoc false` *"will make the
  module invisible to documentation extraction tools"*, and nothing more. `module.ex:593-594`
  `no_warn_undefined` is about undefined calls, not restricted ones. Boundary: **not installed**.
- **Erlang** (OTP 28.5.0.7). `xref.erl:1508,1587` `{module_use, ModSpec}` is the audit query I used. There is no
  declaration. `-compile(no_auto_import)` is unrelated: `erl_lint.erl:361` shows it resolves a local-versus-BIF
  name clash, which is adjacent in name and wrong in meaning, exactly the false-friend case.
- **Elm.** Not probed (offline). `elm.json` `exposed-modules` exists for packages; my claim about the error a
  consumer sees is from memory, so I do not use it.
- **This repo.** `bs_check.erl:497-507, 511-525, 527-535`; `unknown_module` is the template for a new
  refusal (`:504`, `bs_diag.erl:652-653`, `:2029`); `private_function` is the template for wording
  (`bs_diag.erl:358-359`, `:1325`). F15: directory is module (`F15-module-is-a-directory.md:25-36`).
  F12 amendment: private by default (`F12-public-and-private.md`, "AMENDED 2026-08-17").

## Options

### Option A: the path says it (Go's rule, no syntax)

A module whose path has a segment `Internal` may be named only by modules under the segment's parent.

```csharp
// src/Shop/Orders/Internal/Cache/Cache.bs
module Shop.Orders.Internal.Cache
public int Get(int x)
Get(x) -> x * 2

// src/Shop/Orders/Total.bs        compiles: Shop.Orders is the parent
module Shop.Orders
using Shop.Orders.Internal.Cache
public int Total(int x)
Total(x) -> Get(x)

// src/Other/Thing/Thing.bs        refused (today: compiles, prints 8)
module Other.Thing
using Shop.Orders.Internal.Cache      // proposed: Other.Thing may not name Shop.Orders.Internal.Cache;
                                      //           only modules under Shop.Orders may
```

**Compiler delta (concrete):**
- `bs_check.erl:497-507` `add_import`: in the `true ->` branch call `visible(M, Self, L, Mode)` before
  `add_module_import` (1 call site). Raises only when `Mode =:= strict`, so `--api` and `types_of`/`exports_of`,
  which call `import_env` leniently (`:370,383,1547`), are untouched.
- New `visible/4` over module-name atoms: the 9-line `internal_rule/2` of `probes/60/proto/may_name.erl`.
  Directory-subtree-from-names: split the atom on `.` (the same representation `children/2` and `strip_prefix/2`
  already use, `bs_check.erl:589-596`), find the last `"Internal"` segment, require the segments before it to be a
  prefix of the importer's. No `World` change: `Self` and `M` are already in scope.
- `add_namespace_import` (`:527`): filter `Children` by the same function (1 line), or `using Shop` would bring in
  hidden children.
- `bs_diag.erl`: one `built/2` and one `message/1` clause (about 8 lines).
- Not touched: lexer, parser, AST, `World` entries (`bsc.erl:227,293`), emitter, editor grammars.
- Total: about 25 lines in 2 files, 4 sites. Emitted `.beam` is unchanged by construction (a caller-side check,
  per 22's note on ticket 18 §5). I did not measure beam bytes, because no compiler edit was allowed.

**Measured:** 1.13 us per check; 0 of 7,656 corpus pairs refused; the flat-prefix trap (`Shop.OrdersX`) is caught
by segment comparison.

**Strongest counterargument:** a reserved path word is a *convention that looks like a name*. It turns a legal
segment into a rule, which a `grep` for the keyword would not find, and it protects only code the author chose to
move under `Internal/`. A module that is already public and in the wrong place gets no protection until someone
moves it. Go lives with this; B# has one-function-per-file and an agent author who renames files freely, so a
rename changes visibility silently. I did not measure how often agents move files.

### Option B: the module declares it

```csharp
module Shop.Orders.Cache visible_to Shop.Orders      // any module under Shop.Orders may name it
```

**Compiler delta (concrete):**
- Lexer: a new keyword (`visible_to`). Grammar: `bs_parser.yrl:192` `module_decl` gains an optional clause.
- AST: `{module, L, N}` becomes wider. There are **6** non-parser pattern sites to update:
  `bs_api.erl:93`, `bs_check.erl:204,236,251,270`, `bsc.erl:459`. F12's own build note records a seventh-site
  miss that nothing reported, so this count is a known risk.
- Aggregation: a module is many files that each repeat the `module` line (F15). The declaration then appears
  once per file, so a new "files of one module disagree" check is needed, or it is confined to `index.bs`.
- `World`: a new key at both entry constructions (`bsc.erl:227`, `:293`), read in `add_module_import`.
- Same `bs_diag` pair and namespace filter as A.
- Editors: `editor/` has five grammar dirs (tree-sitter, vscode, nvim, syntect, zed). F12 counted three; I did
  not check whether syntect and zed derive from tree-sitter.
- Total: roughly 60-90 lines across 8+ sites plus a new keyword (the 16th, which 22 declined to spend).

**Measured:** only the pure check, identical in cost to A (`declared_rule/3`, `proto/run.out`: allowed, refused).
The parser, AST and editor costs are counted by reading, not built.

**Strongest counterargument:** B is the only spelling that covers a module which is not under a convenient
parent, can name several parents, and is `grep`-able. If the unit is ever a *list or group* rather than a subtree,
A cannot express it at all, and retrofitting B later costs the same as doing it now.

## Recommendation

**Option A.** The only consumer I could confirm needs a *subtree* ("this helper belongs to `Shop.Orders`"), and for
a subtree the path already says everything. A costs about 25 lines and no grammar. It costs nothing in the
current corpus, and its trap (flat string prefix) is demonstrated and covered by the segment test. B is a
complete answer to a wider question (arbitrary lists) that no ticket asks yet.

Two things for David before building, both about *whether* rather than *how*:
- Finding 3 weakens the stated reason for the ticket. F12 may already serve 24's agents. If the only unserved case
  is "a sub-module must be public for its parent", this ticket is smaller than "Not owed a decision soon" implied.
- The word is a choice. `Internal` borrows Go's meaning, not C#'s. The glossary rule (terms only, after a decision)
  means `CONTEXT.md` gets the entry only once settled.

If chosen, per CLAUDE.md the failing test and a `--self-test` gate come first: the Option A program above
(red: `Other.Thing` compiles today), plus a green control beside it for `Shop.Orders`.

## What I could not measure

- **Elm** at all (offline; proxy 403 from the registry). **Boundary** (not installed, hex unreachable).
- **Gleam's publish-time leak check** and any behaviour for hex (non-path) dependencies; my probe used a path dep.
- **Compile-time delta** of the real check and **beam size**: `compiler/` was off limits, so 1.13 us/check is the
  prototype in isolation (one run, no spread, with the Erlang `timer:tc` overhead included).
- **Real call-graph cost** in `add_import`: I measured pairs over 88 module names, not a real import fold.
- **Whether agents rename files** (the strongest counterargument to A), and how the test layout from 24's open
  "where does a test live" item interacts: a test inside the subtree would be allowed, outside refused.
- **How `--api` (lenient) should behave** on a refused import. I assumed it skips, as it does for unknown imports
  (`bs_check.erl:502-505`); not a probe, a reading.
- Editor grammar derivation (syntect/zed), as noted above.

Status: **OPEN - for human review.**
