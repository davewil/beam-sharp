# 60 -- Which modules may name this one?

Status: brief only; ticket left OPEN for David. (ENG-242, `wayfinder/issues/60-which-modules-may-name-this-one.md`)
Repo HEAD moved during the session (019533d, 8b09c30, 1c9a655); `compiler/src/bs_check.erl` was last touched at 0f4859a, so
every compiler claim below is about one source. Probes run from `$REPO`; all under `artifacts/probes/60_*`.

## What the ticket asks, and what changed since it was written

A module controls what it exposes (F12 `public`/`private`, ticket 40 s3) but cannot say who may name it. The ticket asks four
things: the unit (subtree / named group / explicit list), the direction (callee names callers vs caller declares), whether it is
a third visibility marker or a separate construct, and what it costs the checker at `add_module_import`.

Nothing since 2026-08-23 moved it: `grep -l 'ticket 60\|ENG-242'` hits only tickets 22 and 60. Four of the ticket's
measured claims are stale or wrong (Findings 1-3, 6). The consumer in ticket 24 s2 has largely dissolved because F12 landed (Finding 7).

## The gating question (alone)

**What is the unit: a path-derived subtree, or a list the callee writes down?**

Direction and marker follow from it; they are not separate questions.

- Direction: any rule that refuses a caller needs data stored with the callee or in a third place. A caller-side declaration
  can only restrict the caller itself, and `using` already is that declaration. Finding 4 shows the outsider compiles at HEAD
  with its `using` line in place. So under every unit the check runs at the importer but the rule is the callee's. "Caller
  declares" has no content as a *who may name me* mechanism; I treat it as answered, not as an option.
- Marker: `add_import` runs once per `using`, before any function is looked at (bs_check.erl:498-510), so the rule is
  module-level. It cannot be a third value of the signature marker. For a subtree unit it needs no marker at all (the callee's
  position in the tree is the declaration); for an explicit list it needs one declaration per module.
- Cost: see Measurements. Same enforcement site either way.

## Findings

1. **Site and line numbers: STALE.** `./probes/60_site.sh`. Commit `0b761f6` does not exist in this repo
   (`fatal: Not a valid object name`). At HEAD the function is `add_module_import(M, World, Acc)`, **arity 3**, at
   `bs_check.erl:512-525`, called from `add_import/7` at line 500. It does not receive the caller. The caller's identity (`Self`)
   is bound one frame up in `add_import(L, M, Self, World, Known, Mode, Acc)` (line 498), which also has the line `L`. So the
   check goes in `add_import`, not in `add_module_import`. Verdict: ticket's "reads only the export set" CONFIRMED; its
   location and arity REFUTED.
2. **No internal/friend/sealed/visible_to anywhere: CONFIRMED.** Same probe. The word grep over `compiler/src/*.erl *.yrl *.xrl`
   and `LANGUAGE.md` finds only prose ("internal notes", "internal types", "false friend", "checker-internal"); control grep for
   `private` hits the parser (4) and lexer (1).
3. **Second import path the ticket did not mention: a bypass.** `./probes/60_proto.sh`, variant `namespace_import`. At HEAD
   `using Shop` (a namespace, bs_check.erl:503-507 / `add_namespace_import`) brings every descendant module in, so an outsider
   writes `Orders.Internal.RecomputeTotal(...)` with **no** `using Shop.Orders.Internal` line, exit 0. Any rule must therefore
   filter in `add_namespace_import` as well as `add_module_import`. The prototype does (`nameable/2` over `Children`).
4. **Nothing refuses an outsider today: CONFIRMED.** `./probes/60_proto.sh`, `[head]` rows: outsider, sibling and shop-wide
   outsider variants all exit 0 and run.
5. **BEAM can enforce only exported-vs-local: CONFIRMED, with one addition.** `./probes/60_beam.sh`:
   ```
   Pub/1:   labels=[3,4] func_info=1 type_tests=[is_integer]     (public)
   Priv/1:  labels=[5,6] func_info=1 type_tests=[]               (private)
   Twice/1: labels=[7,8] func_info=1 type_tests=[is_integer]     (public, calls Pub/1 locally)
   ```
   One `func_info` and one entry label per function; the guard sits at the entry, so `Pub`'s in-module callers pass through
   it (the disassembly shows `Twice` -> `{call_only,1,{'Guard','Pub',1}}`, a guarded entry). Private has none.
   Run-time proof the BEAM cannot enforce *who*: Erlang with no B# compiler involved calls
   `'Shop.Orders.Internal':'RecomputeTotal'([5,6],0)` -> `11`, and `module_info(exports)` lists it. Control: `'Guard':'Priv'(2)`
   -> `'EXIT'` (undef), `'Guard':'Pub'(foo)` -> `'EXIT'` (guard). So the "what" half is enforced by the VM, the "who" half
   cannot be, and any who-rule is compile-time only. The rule adds **zero bytes** to emitted code: for all five modules the
   Code/AtU8/ExpT/LocT/ImpT/StrT/LitT/FunT chunks are IDENTICAL between HEAD bsc and the patched bsc (file sizes differ by 0-4
   bytes: temp-dir path in the compile-info chunk). Whole-file `cmp` is unusable because **HEAD bsc is not byte-reproducible**
   (two HEAD runs differ); that surprised me, see Probe log. The control (`Shop.Internal` vs `Shop.Orders`) reports DIFFERENT.
6. **"The natural unit is a subtree because a directory is a module" -- PARTLY.** F15.11 allows a directory with `.bs` files to
   have a subdirectory with `.bs` files; both are modules (`Shop.Orders`, `Shop.Orders.Internal`), proven by the fixture tree
   `probes/60_shop/ok` compiling and running (`Invoice [100,200]` -> 430). But module membership is by *atom path*, and the
   containing module does not "contain" the child at run time: they are two `.beam` files. A subtree rule is a rule about atom
   prefixes (`lists:prefix("Shop.Orders.", Self)`), which is why the prototype is string work.
7. **Ticket 24 s2's consumer: STALE in its premise.** `./probes/60_unclassified.sh`. 24 s2 says "every function in an aggregate
   is exported today ... `RecomputeTotal/1` lands `unclassified`". Two facts at HEAD: (a) there is no runnable classifier: the only
   `unclassified` in `compiler/src` is the diagnostic fallback tag (`bs_diag.erl:703`, `bsc.erl:897`, `bs_api.erl:280`), and
   grep for `boundary manifest|callbacks:` finds nothing in src; (b) with F12's private default, a `RecomputeTotal.bs` beside
   `Apply.bs` in one directory is `private`, does not appear in `bsc --api` (prints only `int Apply(list<int>)`), is not in the
   beam's export list, and Erlang calling it gets `'EXIT'`; the sibling file still calls it (`Apply [1,2,3]` -> 6). So the
   test-targeting hazard exists only for a helper that is `public` because it must cross a module boundary (e.g. `Shop.Internal`
   shared by `Shop.Orders` and `Shop.Billing`). That is exactly what rule A or B below addresses, and is a narrower consumer than 24 imagined.

## Neighbours

All five checked by running programs; Gleam and Elm have no source available here (binaries only).

- **Go** (not in the brief's list, run because it is the precedent for a path-derived rule). `./probes/60_go.sh`, go1.24.7:
  `shop/billing` importing `shop/orders/internal/recompute` -> `use of internal package example.com/m/shop/orders/internal/recompute
  not allowed`, exit 1; outsider -> `shop/internal/tax` same; `shop/orders` -> its own `internal`, and `shop/billing` ->
  `shop/internal`, exit 0. Exactly the rule the prototype implements (importer must be rooted at the parent of `internal`).
- **Gleam 1.19.2.** `./probes/60_gleam.sh`. `internal_modules = ["libpkg/internal", "libpkg/internal/*"]` in libpkg's
  gleam.toml and `@internal` on a function. A second package `app` (path dependency) that imports `libpkg/internal/secret` and
  calls `libpkg.annotated()` **builds with exit 0, no warning** and runs. Same-package import also exit 0. Erlang can call
  `libpkg@internal@secret:helper()` -> `41`. What `internal` does: hides from generated docs (`gleam docs build`: `secret` 0
  files, `annotated` 0 files, control `open` 1 file) and the binary contains "These modules leak internal types in their
  public API and cannot be published" (`strings`; refusal is at publish, which I could not run: hex blocked). My first
  expectation (refused at import) was **wrong**; the run refuted it.
- **Elm 0.19.2.** `./probes/60_elm.sh`. `exposed-modules: ["Lib"]` in a *package* elm.json. App depending on `me/libpkg` that
  imports `Lib.Internal.Secret` -> `-- MODULE NOT FOUND` ("I cannot find it!", then a list of near-name suggestions), exit 1;
  importing `Lib` exits 0; building libpkg itself (Lib imports its hidden module) exits 0. The refusal says the module does
  not exist: callee-side list, unit = package, indistinguishable from a typo. **Setup limit:** package.elm-lang.org and
  github archives return 403, so `elm/core`, `elm/json` come from `git clone`, `me/libpkg` is hand-installed in a scratch
  `ELM_HOME`, and `registry.dat` is hand-written (`60_elm_registry.py`, format found by trial). Elm's resolution on those
  packages is real; the registry is forged.
- **Elixir 1.18.5.** `./probes/60_elixir.sh`. `@moduledoc false` module and `@doc false` function called from `Audit` in
  another file: `elixirc` prints nothing, exit 0, runs (`6`). `Code.fetch_docs` shows `:hidden` for both; the doc says so itself:
  `lib/elixir/lib/elixir/lib/module.ex:318` "`@moduledoc false` will make the module invisible to documentation extraction
  tools". Controls: calling a `defp` or a missing function from outside *warns* `Shop.Orders.secret/1 is undefined or private`
  (`module/types/apply.ex:952-953`), still exit 0. No who-check exists.
- **Erlang/OTP 28.** `./probes/60_erlang.sh`. `-export` is the only gate (what, not who). `-moduledoc false`
  (`stdlib-7.3.0.3/src/dets_utils.erl:23`) and `-doc hidden` (`escript.erl:404`) are documentation metadata; `erl_lint.erl:1073`
  tracks them as attribute state and nothing else. `erlc +warn_all` on a module calling an exported "internal" function and an
  unexported one (runtime `undef`) prints nothing about either call (its one warning is the callee's own unused function);
  a remote `-spec` use of a non-exported type warns nothing. The only friend-shaped tool is post hoc: `xref:analyze(s,
  {module_use, shop_orders_internal})` -> `[audit,shop_orders]`; subtracting an allow-list `[shop_orders]` leaves `[audit]`.
  The build must run and own that script (and needs `+debug_info` beams).

## Measurements

| What | Result | n | Probe |
|---|---|---|---|
| Prototype diff | +32 / -2 lines, 2 files (`bs_check.erl`, `bs_diag.erl`); of which 9 are the diagnostic | - | `60_proto.sh`, `60_internal.patch` |
| Emitted code, patched vs HEAD | behaviour chunks identical, 5/5 modules | 5 | `60_beam.sh` |
| Compile, 5-module program (wall ms incl. VM start), final run | HEAD 359/406 (min/median), HEAD again 369/413, patched 376/410 | 15 each, interleaved | `60_timing.sh` |
| Compile, 41-module program, 121 `using` edges, final run | HEAD 530/990, HEAD again 748/903, patched 561/875 | 15 each | `60_timing.sh` |
| Same, earlier run on a quieter machine (not kept: `.out` overwritten) | A: 447/533, 473/545, patched 493/558. B: 489/532, 480/543, patched 492/546 | 15 each | same |
| `nameable/2` per call (under erl_eval) | min 3945 ns, median 5021 ns; no-op control 2649 / 3103 ns; difference ~1.9 us/call median | 5 x 1e6 | `60_check_micro.sh` |

Reading: the HEAD-vs-HEAD gap (7 ms on A; 87 ms on B, other agents were loading the box) exceeds the HEAD-vs-patched gap in
both runs, so no compile-time cost is detectable. The micro number bounds it: 121 imports x ~2 us = ~0.25 ms of a ~400 ms
compile. Not measured: cost of option B's extra parse and AST work (not built).

## Options

The programs are in `probes/60_shop/`. The tree (all modules compile and run at HEAD):

```
Shop/Internal/Tax.bs          module Shop.Internal           public int TaxOn(int cents)
Shop/Orders/Internal/Recompute.bs   module Shop.Orders.Internal   public int RecomputeTotal(list<int>, int)
Shop/Orders/Total.bs          module Shop.Orders             using Shop.Orders.Internal; using Shop.Internal
Shop/Billing/Bill.bs          module Shop.Billing            using Shop.Orders; using Shop.Internal     (sibling)
Audit/Report.bs               module Audit                   using Shop.Orders                          (outsider)
```

### A. The path is the declaration: an `Internal` segment (prototyped and measured)

Rule: a module whose atom is `P.Internal` or `P.Internal.Q` may be named only by `P` and modules below it. No new syntax.

Compiles under A (and at HEAD): `Shop.Orders` using `Shop.Orders.Internal` and `Shop.Internal`; `Shop.Billing` using
`Shop.Internal`; `Audit` using the public `Shop.Orders`; `using Shop` then `Orders.Total(...)`.
Refused under A, compiles at HEAD (`60_proto.sh`, patched bsc):

```
// Audit/Report.bs               using Shop.Orders.Internal
Audit/Report.bs:3:1: error: Shop.Orders.Internal is internal to Shop.Orders and Audit is outside it
// Shop/Billing/Bill.bs          using Shop.Orders.Internal      (sibling of Shop.Orders)
Shop/Billing/Bill.bs:3:1: error: Shop.Orders.Internal is internal to Shop.Orders and Shop.Billing is outside it
// Audit/Report.bs               using Shop.Internal
Audit/Report.bs:3:1: error: Shop.Internal is internal to Shop and Audit is outside it
// Audit/Report.bs               using Shop ; Orders.Internal.RecomputeTotal(...)
Audit/Report.bs:9:32: error: Orders.Internal is called but never imported      (see work item 4)
```

Compiler delta (all in `bs_check.erl` unless noted):
1. `add_import/7`: call `may_name(Self, M, L, Mode)` before `add_module_import` (strict mode only; `--api` lenient skips).
2. `nameable/2` + `internal_scope/1`: split the atom's text at the first `.Internal` segment, prefix test on `Self`.
3. `add_namespace_import/3`: filter `Children` by `nameable/2` (closes Finding 3).
4. **Not done in the prototype, owed:** the namespace-case message suggests `add `using Orders.Internal``, which would then be
   refused; the hint needs to say the module is internal. `bs_diag.erl`: `built/2` + `message/1` clauses for `module_not_visible`
   (done in the prototype); a JSON tag for F47 (not done).
5. `LANGUAGE.md` paragraph + a refusal block (`diagnoses:`) + an example directory under `compiler/examples/` (the
   `every_shipped_surface_form_has_an_example_test` rule); tests in the suite. None written.

Evidence: Finding 5 (identical emitted code), the Go run (same semantics, same diagnostics shape), timings above.

Strongest counterargument, as its best proponent (B) would put it: "A hands the compiler a magic word. `Shop.Internal.Foo` gets
different semantics from `Shop.Inventory.Foo` because of how a directory is spelled, nothing in the file says so, an agent that
renames a directory silently changes what the compiler enforces, and the rule is exactly one shape. Anything other than 'my
ancestors' (Billing and Orders share a helper but neither is the other's ancestor) forces a third module higher up that
everything under `Shop` can then name. Go has lived with that for ten years, but Go's `internal` is a *directory* in a tool that
owns the whole tree; here the atom is a name, and 22 itself said not to borrow a word whose meaning is adjacent."

### B. The callee writes the list (not prototyped; work items counted from real code)

```
// Shop/Internal/index.bs
module Shop.Internal
visible_to Shop.Orders            // keyword spelling is a placeholder
visible_to Shop.Billing
```

Compiles under B: the same tree, plus `Shop.Billing` and `Shop.Orders` both naming `Shop.Internal`, which A allows only because
both are under `Shop`. Refused under B and *allowed under A*: a sibling `Shop.Reports` using `Shop.Internal` (A admits anything
under `Shop`; B refuses unless listed). Refused under B and allowed at HEAD: `Audit` using `Shop.Internal`.
Diagnostic text is the same shape as A's; it is not run.

Compiler delta, counted by following how `behaviour` flows (7 hits in `bs_parser.yrl`, 3 in `bs_lexer.xrl`, 13 in `bs_check.erl`):
1. Lexer: a keyword (the only keywords are listed in `bs_lexer.xrl`; ticket 22 notes the keyword budget). Parser: `decl -> visible_to_decl`,
   modelled on `using_decl -> 'using' modpath` (`bs_parser.yrl:185`). AST node `{visible_to, Line, Mod}`.
2. World entry gets a `visible_to` field where it is built, **twice**: `bs_check.erl:151` and `bsc.erl:240`.
3. `add_import` + `add_namespace_import` check as in A (same two sites).
4. F15 rule: `visible_to` lives in `index.bs` (shared declarations only, `LANGUAGE.md` line ~187) and needs a `module` path check.
5. `bs_api.erl` should print it; `bs_diag.erl` two clauses; LANGUAGE.md, example, tests.
Not measured: any of the above (nothing built). Expect parse/AST work, not check-time work: the check itself is a `lists:member`.

Strongest counterargument, as A's proponent would put it: "B asks an author to maintain a list that the directory tree already
encodes in the ordinary case. The list is a second place that must agree with the layout, which is the drift 40 s3 refused for
`-export` ('a second place that must agree with the definition'). It spends a keyword, an `index.bs` rule, and two World-entry
sites (note `bs_check.erl:151` and `bsc.erl:240` already duplicate the entry construction) for the case where the tree is not
enough, and no exemplar in the repo has shown that case."

### C. No construct: `private` plus module layout

Not a rival to be argued for hard, but it is the null case and Finding 7 says it covers most of what 24 s2 feared. Compiles
under C: today's tree, a helper in `Orders/RecomputeTotal.bs` as `private`. Refused under C: Erlang or B# calling it
(`60_unclassified.sh`: not exported, `'EXIT'`). What C cannot express: a helper shared by two *modules* without being nameable by
everyone (Shop.Internal in the tree above), and `bsc --api` cannot mark it.
Strongest counterargument, as C's proponent: "The only demonstrated consumer is a hazard (agents testing helpers) that F12 already
removed for same-directory helpers. Every rule here is another thing `LANGUAGE.md` must teach, another gate and example under
`check-surface`-style discipline, and CLAUDE.md says one occurrence of a failure gets a sentence, not a construct. Build the
rule when an exemplar needs a cross-module helper, not before."

## Recommendation

**Option A**, with B recorded as the upgrade if a named-group need appears. Reasons: it is the smallest thing that gives the
cross-module helper somewhere to live (the one consumer that survived Finding 7); it needs no grammar, so none of the 22-style
keyword or `index.bs` questions; its refusals are the same ones Go produces on the same tree (executed); it costs 32 lines and
no detectable compile time; emitted code is identical. The spelling (`Internal`, versus another segment) is David's call and is
the live question inside A: the ticket's false-friend rule says survey the word, and the survey is that Go's `internal` means
this (path-prefix rule) while C#'s means assembly-scoped; a reader from C# will misread it.

What would change my mind: (1) an exemplar needing a helper shared by modules that are not under a common ancestor below the
root, which A can only serve by hoisting to a shared prefix: then B. (2) David rejecting spelling-by-directory as invisible
semantics (the A-opponent argument above): then B. (3) Finding no cross-module helper in the next exemplar corpus: then C, and
close the ticket as "no consumer".

## Probe log

- **Surprised me:** Gleam did not refuse (my header claim said refused; the probe header was kept and the claim marked REFUTED
  in the comment). Step 5 of that probe (docs check) was first written without a control, then given one; steps 1-4 unchanged.
  Step 6 (strings of the binary) added after.
- **HEAD bsc is not byte-reproducible** (two HEAD compiles of the same input differ): first `60_beam.sh` compared whole files and
  reported DIFFERENT for HEAD-vs-HEAD. Changed to compare behaviour chunks; the whole-file HEAD-vs-HEAD result is kept in the output.
- `60_proto.sh`: first run had `namespace_import` containing both `Report` and `Sneak`, so Report went red under the patch because
  Sneak is in the same module. Added the `namespace_ok` variant and fixed the header; both variants are in the final output.
- `60_timing.sh`: first run printed FAIL for every compile (relative module path resolved against the wrong cwd, so the timings
  were of failures). Fixed with `cd "$2"`, rerun. `60_build_patched.sh`: first version broke when invoked with a relative path;
  fixed, and all patched probes re-run after. Final timing run was taken under load from other agents (B medians 875-990 ms);
  the earlier quieter run is in the table.
- `60_beam.sh`/`60_unclassified.sh`/`60_elixir.sh`: first versions had shell-quoting or Erlang-term mistakes (no result produced);
  rewritten into escripts. No probe's *claim* was altered after seeing output, except the corrections above.
- `60_check_micro.sh`: header first said "well under a microsecond"; the run gave ~1.9 us under erl_eval, so the header claim was reworded to "microseconds at most" (the refutation threshold, 10 us, was not changed). Also `~.0f` format crash fixed.
- `60_erlang.sh`: the xref `undefined_function_calls` list also shows `lists:sum/1` because stdlib was not added to the xref
  server; noise, not a finding.
- Not run: `gleam publish` (hex blocked); Elm with the real registry; Elixir third-party `boundary` library (not installed);
  a prototype of option B; LSP/tree-sitter effects.

## Probe index

All: `cd /home/user/beam-sharp/artifacts/probes && ./<cmd>` (they `. env.sh` themselves; patched builds take ~1 min).

| Name | Command | Refuting output |
|---|---|---|
| site | `./60_site.sh` | `0b761f6` resolves; `add_module_import` is /5 at 407-425; a visibility keyword hit that is not prose |
| beam | `./60_beam.sh` | `Priv/1` shows an `is_integer`; Erlang call of `RecomputeTotal` raises; behaviour chunks DIFFERENT |
| proto | `./60_proto.sh` | any `[head]` row exit != 0; any patched outsider/sibling row exit 0; patched `ok`/`namespace_ok` exit != 0 |
| timing | `./60_timing.sh` | patched median above HEAD median by more than HEAD run-to-run spread; any `FAIL` line |
| check_micro | `./60_check_micro.sh` | median difference over 10000 ns |
| go | `./60_go.sh` | sibling or outsider build exit 0; `orders` -> own `internal` refused |
| gleam | `./60_gleam.sh` | (already refuted its first claim) importing app exit 0 is the observed result; a refusal text would contradict this brief |
| elm | `./60_elm.sh` | app importing hidden module exits 0; own-package build refuses |
| elixir | `./60_elixir.sh` | a warning on the `Audit` compile in case 1-2; docs not `:hidden` |
| erlang | `./60_erlang.sh` | erlc diagnostics about the cross-module calls; xref `module_use` missing `audit` |
| unclassified | `./60_unclassified.sh` | `RecomputeTotal` in `--api` or beam exports, or callable from Erlang; a classifier hit in src |

Fixtures: `probes/60_shop/{ok,outsider_orders_internal,sibling_orders_internal,outsider_shop_internal,namespace_ok,namespace_import}`,
`probes/60_orders/`, `probes/60_internal.patch`, helper `probes/60_build_patched.sh`, `60_beam_inspect.escript`, `60_elm_registry.py`.
