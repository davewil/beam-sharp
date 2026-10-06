# Decision brief: ticket 60, which modules may name this one? (ENG-242)

Ticket: `wayfinder/issues/60-which-modules-may-name-this-one.md`, grilling, open since 2026-08-23.
Compiler measured: `bsc` built from `compiler/src` at `712b9e9`. Nothing under `wayfinder/`,
`compiler/` or the docs was edited; every prototype below was built from a scratch copy of
`compiler/src` (`artifacts/probes/60/build_proto.sh`).

## What the ticket asks

A B# module controls **what** it exposes (`public`, private by default, F12). It cannot say **who**
may name it. Ticket 22 split that out, and 60 inherits four questions: the unit, which way the
declaration points, whether it is a third visibility marker, and what it costs the checker.

## Three things in the ticket that are stale or false against the current tree

1. **The call site moved and its arity is wrong.** The ticket cites `add_module_import/5` at
   `bs_check.erl:407-425`. Today it is `add_module_import/3` at `bs_check.erl:511`, called from
   `add_import/7` at `:497` (F32 already says `/3`). Lines 407-425 are now `qualify_refs`.
2. **The consumer paragraph is mostly gone.** Tickets 22 and 24 §2 say `RecomputeTotal/1` lands
   `unclassified` because visibility was undecided. F12 made private the default. An unmarked
   `RecomputeTotal` is now absent from `bsc --api` and refused as a callee from any other module
   (`60j` J1, J2; control: marking it `public` makes it appear). The `boundary/callbacks/unclassified`
   manifest 24 §2 sketched was never built, and `--api` prints only public functions. What survives
   is the **public function that exists for one sibling module** (`60j` J3: `ForBilling` looks like
   `Total` in `--api`). That is the residue 60 can still serve, and it is a smaller case than the
   ticket states.
3. **"Per-function export control is not cheaply available on the BEAM" is true but incomplete.**
   The BEAM has *no* caller-scoped export at all, per module or per function. `60a`: the exported
   function is callable from any module by direct call, by `apply/3` with a run-time atom, by a
   computed atom, by `fun M:F/A`, and by `erlang:make_fun/3`. Only a local-only function is refused
   (`undef`, the control). So the rule can only be a compile-time check on B# source, and
   `60i` confirms the check emits nothing (below).

## Sub-decisions and what gates what

1. **Who writes the rule: the module being named, or the module naming it?** *Gates everything.*
2. If the named module writes it: **a declaration, or the module's path?**
3. **The unit.** Subtree of the directory tree (F15) or exact module; whether a list is allowed.
4. **Where it sits:** module level (`index.bs`) or on a signature, as a third visibility marker.
5. **Checker cost.** Answered by measurement below, not asked.

**Only 1 is for David now.** 2 to 4 are stated so the shape of the follow-up is visible; each is
decided by reading the code under the answer to 1, and none is asked until 1 is answered.

## What no option can do (shared by all of them)

Any option is a check on B# source at `using`. It does not make a function unreachable.

- **`60b` B3.** A module reaches `Lab.Core.Sum` with no `using Lab.Core` through
  `:erlang.apply(m, f, [..])`: it compiles, runs and prints `4`. The module atom arrives at run time.
- **`60b` B4.** `private` is already porous to function values: `Core.Leak()` returns its private
  `Hidden/1` as a value, and a stranger calls it (`100`). This is F46 working as designed.
- **`60e`.** OTP's own `xref` reports a module that reaches `callee` only through `apply(M, ..)` as
  an *unresolved call* and leaves it out of `{module_use, callee}`; `xref.erl:53` says unresolved
  calls "make module data incomplete".

The honest sentence for the spec is ticket 22's: *compile-time visibility over beam-sharp source
only* (the BEAM has no visibility modifiers; ticket 06).

## Neighbours, from installed sources and real runs

| Language | What it has | Refuses a caller? | Evidence |
|---|---|---|---|
| Go 1.24.7 | path rule: an `internal` element makes a package importable only from the tree rooted at its parent | **Yes**, at `go build` | `60l`: `lab/core/sub` builds, `lab/web` refused with `use of internal package ... not allowed`, control `web2` builds. Rule text at `/usr/local/go/src/cmd/go/internal/load/pkg.go:1473-1475`; error at `:1574` |
| Gleam 1.18.1 (path dependency only; `gleam build`; no hex dependency; language server untested) | `internal_modules` in `gleam.toml`; `@internal` on a definition | **No** | `60c`: importing `liba/internal/helper`, importing a module listed in `internal_modules`, and calling an `@internal pub fn` from a dependent package all build, exit 0. Control: calling a non-`pub` function is refused (exit 1). The binary carries a publish-time check, "These modules leak internal types in their public API and cannot be published", which is about types leaking, not callers. Compiler *sources* are not installed (conda binary only), so behaviour is cited from output and `strings`. Also observed: `gleam docs build` still generates and links pages for the internal modules locally |
| Elixir 1.20.4 | `@moduledoc false`, `@doc false`; `mix xref callers` | **No** | `60d`: a caller of a `@moduledoc false` module compiles with no warning; `Code.fetch_docs` says `:hidden`. Installed docs for `@moduledoc`: "`@moduledoc false` will make the module invisible to documentation extraction tools". `mix xref callers Lab.Core --fail-above 0` is a CI gate (exit 1 when a literal caller exists) and stays green (exit 0) when the only caller uses `apply(m, :sum, ..)`. Control: a `defp` named from another module is a *warning* (compile exit 0) and raises at run time |
| Erlang/OTP 28 | `-export`; `xref`; EDoc `@private`/`@hidden` | **No** | `60e`: `xref` lists `caller_bad` and `caller_ok` as users of `callee` and omits the `apply` caller. EDoc: `edoc_tags.erl:93-95` declare `hidden`/`private` tags; `edoc_data.erl:165` `hidden_filter` is a doc filter. `-ignore_xref` appears in no OTP 28 source (`60e` X4, with a control grep that does find "Unresolved calls") |
| Elm 0.19.3 | `exposing` (what, not who) | not probed | `elm install` fails: `package.elm-lang.org` returns proxy 403 (`ProxyConnectException`), so no project compiles. I assert nothing about Elm's behaviour |
| Boundary (Elixir library) | caller-side `use Boundary, deps: [...]` | not probed | not installed |

Two readings. Only Go refuses, and it does it by *path* with the parent's subtree as the unit, which
is exactly the unit the ticket guessed from F15. The caller-side shape (Boundary, xref gates) exists
only as tooling bolted on, and it carries the same dynamic hole.

## Sub-decision 1 (the question for David): who writes the rule?

The two programs differ in one place. The same three modules compile under one answer and one of them
is refused under the other. Prototypes: `proto_patch.py` (named module writes) and
`proto_patch_caller.py` (naming module writes).

**Answer A: the named module writes who may name it.**

```csharp
// Lab/Grp/Core/index.bs
module Lab.Grp.Core
visible_to Lab.Billing          // placeholder spelling; spelling is a later question

// Lab/Billing/Bill.bs          using Lab.Grp.Core  ->  compiles
// Lab/Billing/Deep/Deep.bs     using Lab.Grp.Core  ->  compiles (a subtree of Lab.Billing)
// Lab/Web/Web.bs               using Lab.Grp.Core  ->  refused:
//   Lab/Web/Web.bs:2:1: error: Lab.Web may not name Lab.Grp.Core
//     Lab.Grp.Core declares `visible_to` Lab.Billing; Lab.Web is not under any of them.
// Lab/Web2/Web2.bs   (a module written next week, says nothing)  ->  refused as well
```

Run: `60f` V1 to V6 (V1 is the control: pristine bsc, same sources minus the one line, compiles
`Lab.Web` at exit 0; V5 shows `using Lab.Grp` namespace import is refused too; V6 shows a call that
skips `using` is already refused by `module_not_imported`, so `using` is the one choke point).

Compiler delta, measured on the prototype:

- lexer: one keyword. parser: one `decl` production returning `{visible_to, Line, Module}` (+4/-2 lines, verifier-measured).
- `bsc.erl:227` `build/4`: one new field in the `World` entry, `visible_to => [V || {visible_to,_,V} <- Decls]` (+1 line).
- `bs_check.erl` `add_import/7` and the namespace branch: a predicate over the callee's list in
  strict mode (+24 lines, about 11 of them the namespace branch duplicated; factorable).
- `bs_diag.erl`: one `built` and one `message` clause (+7 lines).
- **Nothing emitted.** `60i`: the callee's `.abstr` is byte-identical with and without the
  declaration, the compared beam chunks are identical (`abstract_code`, `attributes`, `Code`, atoms,
  exports, `StrT`, `ImpT`, `ExpT`: none differ) and both `.beam` files are 980 bytes. Control: changing one
  function body makes `abstract_code`, `attributes` and `Code` differ. (Raw file hashes differ even
  for identical input, so the probe compares chunks, not files.)

Strongest counterargument: **layering cannot be written.** "Nothing under `Lab.Web` may touch
`Lab.Db`" is one line on the caller side, and on the callee side `Lab.Db` must list every module
allowed to name it and be edited whenever a legitimate new caller appears. A callee that is widely
used (a `Collections.List`) needs no rule and pays nothing; a callee that is narrowly used pays once.

**Answer C: the naming module writes what it may not name.** Closer to what `using` already does.

```csharp
// Lab/Web/Web.bs
module Lab.Web
forbids Lab.Grp                 // placeholder spelling
using Lab.Grp.Core              // refused: Lab.Web `forbids` Lab.Grp.Core, which it names
// Lab/Billing/Billing.bs       using Lab.Grp.Core  ->  compiles (says nothing)
// Lab/Web2/Web2.bs             using Lab.Grp.Core  ->  COMPILES. Written next week, forgot the line.
```

Run: `60k` K1 refused, K2 (control) and K3 compile. K3 (`Web2` compiles) is an illustration of the
design (the naming module writes the rule, so a module that says nothing is admitted), not a
measured finding of the prototype; no pristine arm exists for 60k because pristine cannot parse
`forbids`. Delta: lexer + parser as above, and **five lines in
`import_env`**, which already holds the importer's `Decls` and `Self`. No `World` field, no `bsc.erl`
change, no new data crossing modules, and no ordering concern: it is the cheaper of the two by about
20 lines.

Strongest counterargument: **the callee cannot protect itself.** `Lab.Grp.Core`'s author wrote
nothing that holds when someone else writes a new module (K3). The rule is only as strong as every
caller's willingness to opt in, which is the failure agent authorship produces (the ticket's
consumer: the loop that writes the easiest thing to test). C protects a *layer*; A protects a
*module*.

**Recommendation: A.** The ticket's motivating case (a helper that must not be named by test and
stranger modules) is a callee asserting its own boundary, and only A makes `Web2` fail. C is worth
having *as well* if layering turns up, and it is the cheaper to add later (five lines, no `World`
field), so choosing A now forecloses nothing. The question for David is the one-line form of this:
*when a module nobody has written yet names `Lab.Grp.Core`, should it be refused or allowed?*

## Sub-decision 2 (follow-up, not asked): declaration or path?

Only meaningful once 1 is A. The path form needs no new syntax at all.

```csharp
// Lab/Core/Internal/Pricing/Pricing.bs
module Lab.Core.Internal.Pricing     // an `Internal` segment: visible only under Lab.Core
// Lab.Core, Lab.Core.Sub  using Lab.Core.Internal.Pricing  ->  compile
// Lab.Web                 using Lab.Core.Internal.Pricing  ->  refused:
//   Lab/Web/Web.bs:2:1: error: Lab.Web may not name Lab.Core.Internal.Pricing
//     an `Internal` module is visible only under Lab.Core.
```

Run: `60m` (the *same sources* compile in full under pristine bsc; M5 control shows only the segment
triggers it). Delta: no lexer, parser or `World` change; one function in `bs_check.erl` called from
the two import sites (+18 lines) and the diag clauses (+7). It is Go's rule (`60l`) and the one
neighbour that refuses callers.

Strongest counterargument: **visibility becomes part of the module's name, and the name is the atom
and the record tag** (ticket 40 §1, 26 §1, F3). `60n`: the same record is `'Lab.Core.Pricing.Order'`
before and `'Lab.Core.Internal.Pricing.Order'` after the move, a wire-visible change (N1 holds by
construction: the tag derives from the module name, and no real move was run), and an Erlang
caller of `'Lab.Core.Pricing':'New'` breaks (no probe backs this; the verifier's accidental N2 run
with the wrong build gave `undef` for the missing module, which agrees). Under the declaration form the tag does not change when
`visible_to` is added (N2; `PATCHED` must be the `--patch` build, since the `--patch-path` build makes N2 fail with `undef`; the probe's header does not say so). It also cannot express a *lateral* grant (a sibling `Lab.Billing` that is
not under `Lab.Core`). The word is a false friend of C#'s `internal` (assembly scope); Go's meaning
(subtree of the parent) is the semantics here, and ticket 22 says to refuse the spelling or borrow
the semantics.

Leaning: declaration, because lateral grants and stable atoms are likely to matter, and the path
form is a cheap convention to add later on top of the same check.

## Sub-decision 3 (follow-up): the unit

F15 makes a directory a module, and a `using Lab.Billing` already names a path. With the declaration
form, a name followed by its dots is the natural unit: `visible_to Lab.Billing` admits `Lab.Billing`
and everything under it (`60f` V3; `Lab.Billing.Deep` compiles). An explicit list is several lines
(the prototype's `Allowed` is a list; the check is `lists:any`). A named group has no existing
construct to hang on and nothing here needs it.

Strongest counterargument to subtree: **a module added under the subtree later is silently
admitted** (V3 is the same fact). Exact-module matching would make each new caller a visible edit in
the callee. With one-function-per-file the number of caller *modules* is small, so exact is cheap.

Leaning: subtree, as the ticket guessed, plus repeated lines for a list; exact-only if David wants
every new caller to be a reviewable edit.

## Sub-decision 4 (follow-up): module level or on the signature

Module level is `index.bs`, where F15 already puts `using`, `type`, `record` and `behaviour` and
forbids functions; it is what `60f` built. A signature form would read:

```csharp
public(Lab.Billing) int ForBilling(int n)   // not prototyped
ForBilling(n) -> n + 1
```

This reaches the case `60j` J3 leaves open (a function public only for one sibling, beside
`Total/1` which is public for everyone), where a module-level rule forces moving `ForBilling` into
its own directory. That move changes its module atom for every caller. Estimated delta, by reading
`private_callee/3` at `bs_check.erl:4268` and `private_table/1` at `:554`: the `visibility`
production grows an argument; `World` entries carry `restricted => #{{N,A} => [Mods]}`; and
`import_env` moves a function from `exports` into `privates` *for importers outside the list*,
so the existing call-site checks at `:3653` and `:4196` and the "declares `private`" diagnostic
would fire unchanged (the message would say `private` where `visible_to` is meant, a wording
problem). Not prototyped and not measured.

Strongest counterargument to module level: the case that survived the staleness check (J3) is a
function-granularity case. Strongest counterargument to the signature: it puts a *module* rule on a
function (the ticket's own worry) and every signature gains an optional argument.

Leaning: module level first. It is the smaller delta, the signature form can be added without
breaking it, and no exemplar in the repo has yet shown the J3 shape (I did not search the exemplars
for one: see Not verified).

## Sub-decision 5: what it costs the checker (measured, not asked)

Method: generate 201 modules (one directory each, 3 `using` edges each, 595 edges in all); compile
the closure from the top module with a fresh `erl` per run, 9 runs per variant, wall time including
VM boot (`60g`).

| Variant | min | median | max |
|---|---|---|---|
| (a) pristine bsc | 1186 ms | 1615 ms | 1843 ms |
| (b) patched, no `visible_to` anywhere | 1391 ms | 1614 ms | 1896 ms |
| (c) patched, `visible_to Gen` on every module | 1406 ms | 1619 ms | 2980 ms |
| (a') pristine again (noise floor) | 1456 ms | 2351 ms | 3446 ms |

The deltas are inside run-to-run noise (row a' is as far from row a as any variant is), so the
whole-build number is "not detectable". To bound it I isolated the predicate (`60h`): the exact
per-edge body, 595 edges, 1000 repetitions in one VM, includes the loop overhead. A 1-entry list
costs about 1.3 to 3.3 ms per project (2.0 ms captured), 4 entries 3.4 to 7.6 ms (5.1 captured), 16
entries 10.7 to 21.6 ms (17.2 captured); these reproduce only to about 2x, so quote the range (control: a non-matching list
accepts 0 of 595, so the loop does evaluate the predicate). Against a ~1.6 s build that is about
0.1% at the realistic list size. The check runs once per `using` edge, in strict mode only; `--api`
and the lenient queries skip it in the prototype. The verifier confirmed the skip (with an
offending `using` and `visible_to Lab.Web`, `bsc --api` on `Lab.Billing` exits 0 and prints the
module) but no captured probe in `artifacts/probes/60/` backs it. Likewise "an Erlang caller of the
old module name breaks" (sub-decision 2) has no probe. Caller-side (C) is the same
order of cost: a list scan per import against the importer's own list, no `World` field.

## Recommendation

1. Ask David sub-decision 1 alone, in the one-line form: *should a module nobody has written yet be
   able to name `Lab.Grp.Core` if `Lab.Grp.Core` says nothing about it?* Recommend refusal: answer A.
2. Do not open 2 to 4 until 1 is answered. Leanings: declaration over path (stable atoms, lateral
   grants), subtree as the unit, module level first.
3. Record in the ticket, when it resolves, that the check is source-level (60b B3/B4), and correct the
   ticket's `add_module_import/5`/`:407-425` and its `unclassified` paragraph (60j).
4. If A is chosen, F-file scenarios already visible from the probes: accepted, refused, subtree,
   namespace import refused, no-`using` refused by the existing rule, nothing emitted, dynamic hole
   documented. Gate and failing test come before the implementation, per CLAUDE.md.

## Probe index

Run from the repo root after `source .../scratchpad/env.sh`. Prototype probes need
`build_proto.sh <dir> [--patch|--patch-caller|--patch-path]` first (patched builds are scratch copies).

| Probe (`artifacts/probes/60/`) | Claim | Result | Control |
|---|---|---|---|
| `60a_beam_cannot_restrict_callers.sh` | BEAM enforces what, not who; apply/make_fun/computed atoms evade a form-reading check | exported fn callable from the "unauthorised" module by 5 routes; checker sees direct and `fun M:F/A` only | local-only fn across modules gives `undef` |
| `60b_bsharp_today_has_no_who.sh` | bsc has no who; `private` is porous to fn values; `:erlang.apply` bypasses `using` | Friend, Stranger, Sneak compile, run (`2`, `3`, `100`, `4`) | Peek naming a private function is refused, exit 1 |
| `60c_gleam_internal_modules.sh` | Gleam `internal_modules`/`@internal` do not refuse an importer | G1 to G3 exit 0 | G4 non-`pub` call exit 1 |
| `60d_elixir_moduledoc_false_and_xref.sh` | `@moduledoc false` is docs only; xref gate misses `apply` | compile clean, `:hidden`; xref gate exit 1 then 0 | `defp` across modules: warning + run-time raise |
| `60e_erlang_xref_caller_check.sh` | xref is a static caller check; unresolved calls are not in `module_use`; no `-ignore_xref` in OTP 28 | `[caller_bad,caller_ok]` only; `caller_dyn` in UC | direct caller present; grep control finds "Unresolved calls" |
| `60f_prototype_visible_to.sh` | callee-side subtree check: accept, refuse, subtree, namespace, no-using, dynamic hole | V1 to V7 as listed | V1 pristine compiles the refused module |
| `60g_checker_cost.sh` | whole-build cost of the check | inside noise (table above) | row (a') noise floor |
| `60h_predicate_microbench.sh` | cost of the predicate alone | 1.3 to 3.3 / 3.4 to 7.6 / 10.7 to 21.6 ms per 595 edges (2.0 / 5.1 / 17.2 captured; reproducible to about 2x) | non-matching list accepts 0 |
| `60i_nothing_emitted.sh` | check emits nothing | `.abstr` identical; compared chunks none differ; 980 vs 980 bytes | body change makes 3 chunks differ |
| `60j_api_is_already_the_client_surface.sh` | ticket's `unclassified` premise is stale | unmarked helper absent from `--api`, refused as callee | marking it `public` makes it appear |
| `60k_prototype_caller_declares.sh` | caller-side variant protects only opt-in callers | K1 refused; K3 `Web2` compiles (illustration of the design, not a finding) | K2 no declaration compiles |
| `60l_go_internal.sh` | Go `internal` refuses outside the parent's tree | `lab/web` exit 1 with message | `web2` (non-internal) exit 0 |
| `60m_prototype_internal_segment.sh` | path rule with no syntax | Web refused; Core, Core.Sub accepted | pristine accepts all; WebOk compiles |
| `60n_moving_into_internal_renames_the_module.sh` | path rule changes the record tag | tag differs after the move (`PATCHED` must be the `--patch` build, not `--patch-path`) | declaration form keeps the tag |

Support files: `build_proto.sh`, `proto_patch.py` (callee-side), `proto_patch_caller.py`,
`proto_patch_path.py`. Each `.out` is the captured run.

## Not verified

- **Elm**: no run (package server returns 403). Boundary (Elixir): not installed.
- **Gleam compiler source**: not installed. The `strings` observation is evidence of a publish-time
  type-leak check, not of its exact rule. I did not test publishing, only `gleam build` and `gleam docs build`.
- **Go across modules** (a dependency in another `go.mod`) and Go's `vendor` cases: only the single-module case ran.
- **The signature-level form** (sub-decision 4) is a code reading, not a build.
- **Prototype scope**: checks only `strict` mode imports. Not tried: `bsc --api` (lenient), the
  REPL `ibs`, the LSP, and whether a type name crossing `using` (F44) is covered (it shares the same
  `using` choke point, but I did not compile a type-only importer).
- **The eunit suite and the gates were not run against any prototype.** The prototypes are
  exploratory copies, not mergeable patches (the namespace branch is duplicated, the messages are placeholders).
- **Spelling** (`visible_to`, `forbids`, `Internal`) is a placeholder throughout.
- **Whether any exemplar needs the J3 shape** (a public function for exactly one sibling): not searched.
- **`--api` and lenient skipping the check, and "an Erlang caller of the old module name breaks"**: no captured probe (see sub-decisions 5 and 2).
- **Timing** is from a shared container with high run-to-run noise (row a'); the `60h` figure is an
  upper bound including loop overhead. Not a benchmark of a quiet machine.

## Verification

Independent re-run: [`60-which-modules-may-name-this-one.verification.md`](60-which-modules-may-name-this-one.verification.md).
Overall verdict: VALID-WITH-CAVEATS. Every probe reran and matched its captured `.out` (timing
within noise), none is circular, and the recommendation (A) is unchanged. Corrections 1 to 7 of the
verifier's list were applied above: 1 header commit `712b9e9`; 2 the 60h numbers quoted as ranges;
3 `--api`/lenient skipping and the Erlang-caller claim stated as having no captured probe; 4 the 60n
`--patch` build requirement; 5 60k K3 described as an illustration; 6 the Gleam row qualified
(path dependency, `gleam build` 1.18.1, language server untested); 7 parser delta +4/-2 and
namespace branch about 11 lines. Also from the verifier: 60g's ordering carries no signal (its rerun
flipped it; keep "not detectable"); 60i's chunk comparison is stronger than the eight chunks listed
(only `CInf` differs) but shows only that the prototype emits nothing by construction, not that a
production implementation could not emit metadata; 60a's walker returns `[]` for dynamic forms by
construction (the run-time results are real); 60n N1 holds by construction.
