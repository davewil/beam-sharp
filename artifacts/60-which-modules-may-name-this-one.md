# Decision brief: ticket 60 (ENG-242), which modules may name this one

Prepared for David. Nothing here decides anything and no ticket, Linear issue, `compiler/` or `wayfinder/` file was touched.
Prototypes are `.patch` files against a copy of `compiler/`; the repo's compiler is unmodified.
Every probe: `artifacts/probes/60/run.sh` (rebuilds the compiler from the repo, applies the patches, re-runs everything). Raw output: `artifacts/probes/60/out/`.
Edits to probes after first output: `artifacts/probes/60/CHANGELOG.md` (probe bugs or measurement-method fixes, each with its reason; none was made to flip a result).
Compiler fingerprint at run time: `bad8cbb2bfcea1c2` (sha of `compiler/src` sources, `out/_fingerprint.out`). I did not run git, so I have no SHA.

## 1. Sub-decisions

1. **Unit.** Subtree of the dotted module path / named list of modules / one function. The module atom IS the directory path (F15, `module_path_mismatch`), so a subtree needs no filesystem: it is a prefix test on two atoms (p15: 0 of 27 corpus modules declare a name different from their path).
2. **Direction.** Callee names who may call it, or caller declares what it depends on. The caller side is already built and enforced (`using` is the dependency list; a call without it is refused, p01). What no one can do today is refuse a `using`. A *caller-declared allowlist* would have to live in a namespace, and a namespace holds no `.bs` file and emits nothing (F15.8), so it has nowhere to be written.
3. **Marker vs construct.** Per-function marker (third visibility value) or a module-level declaration. Measured in section 4: a marker forces the function onto the export list, so it costs the boundary guard `private` elides (p13).
4. **Checker cost.** Where it hooks, how many sites, how many lines, compile-time, emitted code (section 4).
5. **The false friend, the word `internal`.** Measured neighbours give it three different meanings (section 3). It is also the only word of the three that is a *directory name* in one language (Go).
6. **(Found, not on the ticket)** What "subtree" is scoped to: the callee's parent namespace, or its root namespace. The corpus's only cousin edge (`Shop.Reports` using `Shop.Collections.Ints`) crosses a parent boundary (p15), so the two readings disagree on real code.

## 2. Executed facts

Ticket claims marked **REFUTED** or **NOT REPRODUCED** are collected in section 8.

| # | Fact | Probe | Result (raw excerpt) |
|---|---|---|---|
| E1 | Today any module can name any other's public functions, including from outside the namespace | p01 | `bsc --src-root . Outsider Peek "[1,2,3]"` -> `6`, `exit=0`. `Outsider` is not under `Shop`; it does `using Shop.Internal`. CONFIRMED |
| E2 | A call still needs a `using` line | p01 | `Outsider2/Peek.bs:4:26: error: Shop.Internal is called but never imported` |
| E3 | Private is refused today, as a hard error, not a warning | p01 | `Peek calls Sum/2, which Shop.Internal declares 'private'` |
| E4 | The checker has no who-may-name construct | p01 | word-grep of `bs_check.erl` hits only three comments (lines 109, 188, 4861); none in `bs_parser.yrl`/`bs_lexer.xrl`. CONFIRMED |
| E5 | The BEAM cannot restrict callers of an exported function | p02 | an unrelated Erlang module reaches `callee:f/1` by literal call `{f,1,2}`, by `M:F(A)` `{f,2,3}`, by `apply(list_to_atom(..),..)` `{f,3,4}`; the only refusal is `undef` for the *non-exported* `hidden/1`. A bsc-emitted `'Shop.Internal':'RecomputeTotal'([4,5,6])` -> `15`. The beam's chunks: `AtU8 Code StrT ImpT ExpT LocT Attr CInf Dbgi Line Type`; `ExpT` holds `{Name,Arity,Label}` only (I name chunk ids; I cannot show absence of a feature beyond that list). CONFIRMED |
| E6 | Every compile-time rule is bypassable from B# source itself | p03 | `using :erlang { int apply(atom m, atom f, list<list<int>> args) }` then `:erlang.apply(:'Shop.Internal', :'RecomputeTotal', [xs])` compiles and returns `6` **under each prototype** while the control with a plain `using` is refused. CONFIRMED. No `using Shop.Internal` is written, so the dependency list is also wrong (pre-existing, not new) |
| E7 | Even Erlang's static tool misses variable-module calls | p06 | `xref {module_use, callee}` -> `[callee,literal,stranger]`; `sneaky` (calls `M:F(X)` through variables) absent; `UC` lists `{'$M_EXPR','$F_EXPR',1}` for it, `stranger:dynamic/3`, `stranger:via_apply/1`. `xref.erl:40-55` documents it ("results of analyses may be invalid"). CONFIRMED |
| E8 | A **nested directory holding `.bs` is its own module**, not a source-only sub-module | p17 | `Shop/Orders` and `Shop/Orders/Internal` compile to separate `Shop.Orders.beam`, `Shop.Orders.Internal.beam`; a cousin `using Shop.Orders.Internal` runs. F15.11 is right; 41 section 5's `Internal/ ... SUB-MODULE, source-only` diagram does not describe what was built |
| E9 | The three-way `boundary / callbacks / unclassified` listing of 24 section 2 is not built; `--api` prints one flat list | p14 | `bsc --api Orders` lists `Apply, HandleCall, HandleCast, Init`; a `private` `Recompute` is **absent** and a test module naming it is refused (`declares 'private'`). A helper made `public` for a sibling is listed with no distinction (`int Recompute(int)`). The only `unclassified` in `bs_api.erl` is a diagnostic tag (line 280) |
| E10 | Parser: a `visible_to`/`internal` keyword adds no grammar conflict | p11 header lines | yecc: `6 shift/reduce, 0 reduce/reduce` for base, A, B and C (the 6 pre-exist) |
| E11 | The module-level refusal has to be placed at **three** places, not one | p11 | `add_import` (module-tier `using`), `hide/4` memo for a namespace-tier `using`, and `qualified_module/3` where the short name is resolved. A call through the namespace import (`using Shop` then `Internal.RecomputeTotal(..)`) otherwise reaches `module_not_imported`, which would tell an author who has the `using` to add one (F12's `private`-vs-`unknown` lesson again). I did not build the naive filter to measure that message; I read it from `qualified_module`'s code |

## 3. Neighbour survey

| Language | What it does (measured here) | Enforces? | Where |
|---|---|---|---|
| **Gleam 1.18.1** | `internal_modules = ["libpkg/internal", "libpkg/internal/*"]` in `gleam.toml` plus `@internal` on a `pub fn`. A *separate* package `app` (path dependency, no hex) imports `libpkg/internal` and calls the `@internal` fn: `gleam build` prints only `Compiling libpkg / Compiling app / Compiled`, no warning; `gleam run` runs it. Generated docs list `plain`, `total`; `recompute` and `marked` are absent | **No. Hides from docs only** | `out/p04_gleam.out`. No compiler source is installed; this is behaviour only |
| **Elixir 1.19.5** | `@moduledoc false` / `@doc false`: `Outsider.peek([1,2,3])` -> `6`, no warning; docs chunk records `:hidden`. A call to a `defp` of another module compiles with **exit 0 and a warning** (`Shop.Internal2.sum/1 is undefined or private`), not an error. `mix help xref` lists `trace`/`graph` analysis modes only | No (and `defp` across modules is only a warning) | `out/p05_elixir.out`. No `.ex` sources are installed (beams only). Boundary-style libraries are not installed: nothing claimed |
| **Erlang/OTP 28** | `-export` is the only per-function mechanism. xref is analysis, blind to variable-module calls (`xref.erl:40-55`; `{module_use, ..}` at `xref.erl:1587`). OTP's own "internal": 67 of 103 modules in `kernel/src` carry `-moduledoc false`; `erl_internal.erl:22-25` says "Internal Erlang definitions" and `erl_internal:bif(abs,1)` is callable from anywhere; `logger:internal_init_logger/0` (`logger.erl:1573`) is an exported function called from `kernel.erl:37` | No; convention + docs + a name | `out/p06_erlang_xref.out` |
| **Elm 0.19.0** | `exposed-modules` in `elm.json`. `elm make` could not run: it fetches `https://package.elm-lang.org/all-packages` and the proxy returns 403 | **NOT MEASURED** | `out/p07_elm.out` |
| **Go 1.24.7** *(added; installed)* | `internal/` directory: `outsider/o.go:3:8: use of internal package example.com/m/shop/internal/calc not allowed`; the same import from `shop/reports` builds. A subtree rule decided from the import path alone | **Yes, at build** | `out/p08_go_internal.out`. Reflection/plugin bypass not measured |
| **Java 21** *(added)* | `exports lib.internal to friend;`: `package lib.internal is not visible ... which does not export it to module stranger`; `friend` compiles. A callee-declared named list | **Yes, at compile** | `out/p09_java_exports_to.out` |
| **Rust 1.97** *(added)* | `pub(in crate::shop) fn`: outside caller gets `E0603 function 'recompute' is private`. Per item, scope written as a path | **Yes, at compile** | `out/p10_rust_pub_in.out` |
| **C# `internal`** | not installed. Assembly-scoped per ticket 22; **NOT MEASURED**, no runtime claim made | | |

**The false friend, measured.** Among words that are *spelled* `internal`, Go means "subtree of the path, enforced", Gleam means "hidden from docs, not enforced", C# means "assembly" (unmeasured). Rust and Java do the job without the word. A B# `internal` keyword would agree with none of them exactly; a *directory named `Internal`* would agree with Go exactly.

## 4. Measurements

All on this machine; timing is noisy (see the spread).

| Measure | A (path segment) | B (`visible_to`) | C (`internal` marker) |
|---|---|---|---|
| Code lines changed (comments/blank excluded), p12 | `bs_check` +35 -3, `bs_diag` +14 = **+49 -3** | `bs_check` +30 -4, `bs_diag` +14, `bs_parser` +6 -2, `bs_lexer` +1, `bsc` +1 = **+52 -6** | `bs_check` +51 -17, `bs_diag` +9, `bs_emit` +1 -1, parser/lexer/`bsc` +4 -1 = **+65 -19** |
| Of which the rule itself | 15 lines (`visibility/3`, `internal_parent/1`) | 9 lines (`visibility/3`, `visible_to_of/1`) | n/a (scope fn + 3 routes) |
| Shared machinery (refusal at `using`, namespace memo, `qualified_module`, `under/2`) | ~17 lines in A and B alike | same | does not apply: per function it needs the table in 3 routes (see E11) plus five visibility readers (`bs_check` lines 299, 364, 375, 478; `bs_emit.erl:141`) |
| New keyword | none | `visible_to` (lexer 1, grammar 6) | `internal` |
| Compile time, 27-module corpus, 15 interleaved `bsc --batch` runs, median | -1.4% | +15.1% | +8.2% |
| Base run-to-run spread | 1894-3160 ms (1266 ms) | | |

p12's own verdict: no measurable delta, every median difference is inside the base spread. An earlier, identical-method run (kept as `out/p12_measure.out.firstrun-before-beam-hash-fix`) gave -0.1% / -2.2% / -1.1%. B and C swapped sign between runs, so I read noise, not cost. I would not defend either figure as a delta.
The "<20 net code lines in `bs_check`" bar I wrote into p12's header before the first run is **exceeded by all three** (A 32, B 26, C 34 net). The refusal is not a one-liner at `add_module_import`.

- **Emitted code unchanged** for programs not using the rule: `beam_lib:md5/1` of all 31 corpus beams is identical across base, A, B, C (p16, `c3989ba0222d901d` for each). The rule is a check, not codegen.
- **All 27 corpus modules still compile** under each patch (exit 0 x27, p12).
- **`internal` costs a guard `private` elides** (p13): the same `Bump(int n)` compiled `private` has 0 type tests, `public` 1 (`{test,is_integer,{f,3},[{x,0}]}`), `internal` 1, and it is in the export table. Intra-module calls (`Twice` -> `Bump`) hit the guard too, because one entry label serves both (ticket 18 section 1, reproduced).
- **Path alone decides a subtree rule** (p15): 27 modules, 0 mismatch between directory-derived name and declared `module`. 6 have a dotted path; 21 are single-segment (a parent-scope rule has nothing to scope for them).
- **Demand in the corpus: none.** 4 cross-module `using` edges in `compiler/examples`; **0** would be refused by an opt-in rule (nothing is marked). If scope-to-parent were a *default* for every module, 2 of the 4 would be refused, which shows the parent/root question (sub-decision 6). Exemplars (do not all parse, text scan): 4 native `using` lines (`Support.Triage` twice, `Jev`, `Shop.Orders`); none looks like a hiding need.

## 5. Options

Same module in each, so the three read as one program: `Shop.Orders` has a helper `RecomputeTotal` that its siblings in `Shop` need and that nobody outside `Shop` (nor a test of the client API) should name.

### Option 1: do nothing now

```csharp
// Shop/Orders/Total.bs
module Shop.Orders

public int RecomputeTotal(list<int> xs)          // must be public so Shop.Reports can use it
RecomputeTotal(xs) -> Sum(xs, 0)

private int Sum(list<int> xs, int acc) ...       // helpers nobody else needs: already invisible (F12)
```

`Outsider` (`using Shop.Orders`) compiles today (E1). Nothing in the compiler changes.
- **Compiler delta:** none.
- **Evidence for waiting:** the consumer the ticket names is mostly served already. A *private* helper is absent from `bsc --api` and refused in a test module (E9); `private` is the default (F12), so ticket 24's `unclassified` bucket only exists for a helper somebody made `public` on purpose. Zero corpus edges need the rule (section 4). No session has yet logged an agent calling a sibling-only public function from outside (I found none: the only evidence is the reasoned risk in 24 section 2). CLAUDE.md asks for a second occurrence before a new check, and says progress shows in exemplars/audition/editor; this moves none of the three.
- **STRONGEST COUNTERARGUMENT:** the gap is real and narrower than "unclassified": `RecomputeTotal` has to be `public` for `Shop.Reports`, so `bsc --api` publishes it as client API, and the test boundary ("the narrower surface a caller is meant to use", CONTEXT.md) cannot exclude it. That is exactly the function an agent in a loop tests (24 section 2), and with no spelling of "who", the project has no way to even measure how often it happens.

### Option 2: callee declares a named list, subtree being a list entry that is a namespace (`patches/B.patch`)

```csharp
// Shop/Orders/index.bs
module Shop.Orders
visible_to Shop.Billing, Shop.Reports      // modules; an entry may be a namespace: `visible_to Shop` = everything under Shop
```

Compiles: `Shop.Billing`, `Shop.Reports` (each `using Shop.Orders`, calling `RecomputeTotal`). Refused (p11):

```
Shop/Audit/Audit.bs:3:1: error: Shop.Orders declares `visible_to Shop.Billing, Shop.Reports`, and this module is not under any of them
  add this module's path to that list in Shop.Orders, or name something else.
Outsider/Peek.bs:3:1: error: Shop.Orders declares ... (same)
OutsiderNs/N.bs:6:19: error: Shop.Orders declares ... (namespace-tier `using Shop` then `Orders.RecomputeTotal(..)`)
```

`Shop.Audit` is *under* `Shop` but not listed, so it is refused; with `visible_to Shop` instead it compiles and `Outsider` is still refused (p11, `shopB2`).
- **Compiler delta (measured):** lexer keyword `visible_to` (1 line); grammar `visible_decl`, `modpaths` (6 lines, no new conflicts); `bs_check:visible_to_of/1` and one World key `visible_to` in `bsc:build` (1 line); `refuse_unless_visible/4` at `add_import`, `hide/4` memo for namespace imports, one clause in `qualified_module/3`; one `bs_diag` `built` + 2 `message` clauses. `+52 -6` code lines; the rule is 9 of them. Emitted code identical (p16). Module-level, so the function stays private-or-public as F12 left it: no new export, no new guard.
- **Neighbour:** Java qualified exports (p09) enforce exactly a callee-declared named list.
- **STRONGEST COUNTERARGUMENT:** a named list on the callee makes the callee's file the thing a new caller must edit, and agents write one function per file (F15/24). `Shop.Audit`'s author gets the diagnostic above, which literally tells them to add themselves to the list. The rule becomes a speed bump the agent steps over by editing `index.bs`, so it constrains reviewers (who see the diff) and not the author. Also: new keyword, and bypassed by `:erlang.apply` like every option (E6).

### Option 3: callee declares by placement, `Internal` path segment, no syntax (`patches/A.patch`)

```csharp
// Shop/Internal/Recompute.bs         the directory is the declaration
module Shop.Internal

public int RecomputeTotal(list<int> xs)
RecomputeTotal(xs) -> Sum(xs, 0)

// Shop/Reports/Totals.bs   compiles: Shop.Reports is under Shop
module Shop.Reports
using Shop.Internal
public int Report(list<int> xs)
Report(xs) -> RecomputeTotal(xs)
```

Refused (p11):

```
Outsider/Peek.bs:3:1: error: Shop.Internal may only be named from Shop and the modules under it
  this module is outside Shop. Name something Shop publishes instead,
  or move this module under Shop.
```

Also refused through `using Shop` + `Internal.RecomputeTotal(..)` (same text, at the call), and unchanged: a call with no `using` is `module_not_imported`.
- **Compiler delta (measured):** no lexer, grammar, World entry or AST node. `internal_parent/1` (find the last `Internal` segment after the first; parent = the segment's prefix) and `under/2` on two atoms; the same three refusal sites as B; the same diagnostic plumbing. `+49 -3` code lines; the rule is 15. Decided from the module atom alone (p15). A nested module `Shop.Orders.Internal` is legal (E8), giving `Shop.Orders`-scoped hiding by placing the directory one level down.
- **Neighbour:** Go's `internal/` directory, enforced (p08).
- **STRONGEST COUNTERARGUMENT:** a path segment becomes a keyword by convention. Renaming a directory changes what compiles; `Internal` can no longer be an ordinary module name (same reserved-name pressure as F32's reserved qualifiers); and the scope is wherever the segment sits, so a cousin like `Shop.Reports` needing `Shop.Collections.Internal` (parent `Shop.Collections`) is refused, which is the corpus's only cousin edge shape. Granularity is the whole module (every public function of `Shop.Internal`), so `RecomputeTotal` has to be moved into its own directory, which is a rewrite of the aggregate for a visibility flag.

### Appendix: the per-function marker (`patches/C.patch`), measured and not offered

`internal int RecomputeTotal(list<int> xs)` in `Shop.Orders` refuses `Outsider`, the fully qualified `Shop.Orders.RecomputeTotal(..)` and the namespace short call (`Peek calls RecomputeTotal/1, which Shop.Orders declares 'internal'`), and accepts `Shop.Reports` and a public `Fetch` from outside (p11). Against the module-level options it costs: `+65 -19`, an emitter change, five visibility readers changed so none of them treats the new value as private, a tagged `privates` table, the guard on an exported function (E: p13), and a scope definition B# does not yet have (parent or root namespace, sub-decision 6). Its one advantage is granularity: a single function, in a module that otherwise stays closed.

## 6. Recommendation

**Option 1, do nothing now, with a stated trigger; if it is built, Option 2 (`visible_to`, namespace entries as subtrees) over Option 3.**

Why: the evidence that makes a who-rule urgent is missing. F12 already removed the `unclassified` helper for every helper that can be private (E9), the corpus has no edge a rule would change (section 4), and the rule is weaker than F12: `private` is enforced by the VM (`undef`, p02), whereas any who-rule is a compile-time check that `:erlang.apply` walks around (E6). The project's own bar (CLAUDE.md) asks for a second occurrence of a failure before a new check.

If David wants it built: B before A because one construct covers both the list and the subtree (a namespace entry), the declaration sits in `index.bs` beside `using`/`type`/`record`/`behaviour` where F15 already puts module-level declarations, it avoids reserving a directory name, and it costs 9 rule lines against 15. It is open to the counterargument above (an agent edits the list), which no option here closes.

What would flip the pick to building A or B: a logged instance of agent-written code, or an audition ticket, that calls a sibling-only public function from outside its aggregate. What would flip it to C: a case where a single function must be sibling-visible in a module that otherwise has public clients, and C's guard cost is accepted.

## 7. What I could not verify

- **C# `internal`**: no dotnet. No semantics measured.
- **Elm `exposed-modules`**: registry blocked (403); nothing measured.
- **Gleam, Elixir sources**: none installed. Everything is binary behaviour. Boundary-style Elixir libraries: not installed.
- **Go reflection / Java reflection** bypass: not measured, only B#'s and Erlang's.
- **The repo's own suite**: I did not run `bin/verify.sh` or eunit against the patches (about 13 minutes per pass, and the gate-before-implementation order in CLAUDE.md applies to a real feature, not to this prototype). What I did run: 27-module corpus compiles under every patch and emits identical code (p12, p16). No new test or gate was written.
- **`bsc --api` (lenient mode)** under the refusal; **`ibs`** and the LSP; a `visible_to` that names a module that does not exist; a `visible_to` split across several files of one module (only `index.bs` tested); namespace-tier ambiguity when a hidden child shares a short name with a visible one.
- **Naive-filter message** (E11): not built; reasoned from `qualified_module` code only.
- **Compile-time cost**: not measurable here; per-run noise (1.3 s spread) dwarfs any plausible delta, and a +15% reading appeared once.
- `visible_to`/`internal` as new reserved words: grep of `compiler/examples` and `aoc` found no `.bs` using either as an identifier. I did not grep `wayfinder/prototypes` or `handoff/`.
- Spelling is not evaluated. `visible_to` is the ticket's neutral word; `friend` and `exports ... to` are alternatives from other languages, not chosen. Per the project rule, spelling would be asked after the gating question.

## 8. Ticket 60 facts refuted or not reproduced

1. **REFUTED (stale):** "`add_module_import/5` reads only the callee's export set (`bs_check.erl:407-425`)". It is `add_module_import/3` at `bs_check.erl:511-525` (repo as of this run) and it reads the callee's `exports` **and** its `types` entry (F44's type crossing). The line numbers were from `0b761f6` as the ticket says.
2. **REFUTED (narrowed) / consumer claim:** "a helper like `RecomputeTotal/1` is neither [callback nor client API] and lands `unclassified`". Ticket 24's three-way listing is not built (`--api` is a flat list; no `unclassified` category exists), and since F12 a private helper is absent from `--api` and refused in a test module (p14). The claim survives only for a helper that was made `public` so a sibling can call it.
3. **REFUTED (superseded):** 41 section 5's tree marking `Internal/` "inside a module" as a "SUB-MODULE, source-only". F15.11/p17: a nested directory holding `.bs` is its own module with its own beam. Relevant because candidate A's `Shop.Orders.Internal` is a legal module path.
4. **NOT REPRODUCED (not testable here):** the neighbours Elm (`exposed-modules`) and C# (`internal`).
5. **Confirmed, no change:** no `internal`/`friend`/`sealed`/`visible_to` in the checker (three unrelated comments only); a module can name any other's public functions today; the BEAM cannot enforce callers; "one entry label per function, exported-vs-local" (p13 reproduces the guard difference).
