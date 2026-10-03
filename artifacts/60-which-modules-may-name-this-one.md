# Decision brief: ticket 60 (ENG-242), which modules may name this one?

Prepared 2026-10-03 at `5133d97`. **Nothing is resolved by this file**; the ticket is David's. Probes are
under `artifacts/probes/60/NN_*/` (each has `run.sh` and a captured `run.out`; failed attempts are kept as
`run.*-attempt.out` with the reason in the script header). Everything not run is marked UNMEASURED.

**The ticket says "Not owed a decision soon" (Notes, last section).** It was opened only so the question has a
home. Nothing in the corpus or in a pending exemplar is blocked on it, and the evidence below supports that.

## Stale facts in the ticket, corrected first

- `add_module_import/5` at `bs_check.erl:407-425` is now **`add_module_import/3` at `bs_check.erl:511`**. Its
  one caller, `add_import/7` (`:497`), already has `Self`. Same reading as the ticket: it reads only the
  callee's export set.
- Ticket 41 §5's diagram calls `Internal/` inside a module a "SUB-MODULE, source-only". F15.11 superseded that:
  a nested directory holding `.bs` files is its own module with its own `.beam`. Probe 01 and 02 show it
  (`Acme.Billing.Ledger.beam` is separate; `Acme.Billing` exports only `Charge/1`).

## The gating question, asked alone

**Is this a language feature at all, or a check over directory structure?** Both neighbours that restrict *who*
do it as a toolchain rule over paths, not as syntax, and the BEAM gives nothing to lean on.

- The BEAM cannot enforce it (probe 02): the `.beam` has one export table. `Charge/1` is in it, `Round/1` is
  in `locals`. Each function has exactly one entry label (`Charge` 4, `Round` 6). A function exported to
  siblings is exported to every process: `Post/1` was called from a bare shell with no check (`run.out`).
  Ticket 18 §5's claim **holds** (OTP 29, not 28.5). So any "who" rule is a compile-time check on the caller.
- Of five neighbours, only Go enforces it at compile time, as a path rule (probe 11). Gleam, Elixir and Erlang
  compile the offending call with exit 0 (probes 05, 07, 08). Elm is UNMEASURED (probe 06).
- B# already has the caller-side dependency list. A qualified call with no `using` is refused
  (`module_not_imported`, probe 01 B and C: "a file's `using` lines are its dependency list"). So **every**
  cross-module function reference passes through an `add_import` site. A check there is complete for
  functions. It was **not** complete for types (below).

So the answer to the gate is "a checker rule, no new syntax required". That leaves a smaller question, which
is the one to put to David: *should such a rule exist yet*. The other three sub-decisions (unit, direction,
marker versus construct) are conditional on a yes, and are answered below only so a yes has a default.

## What exists today, measured (probe 01, `run.out`)

```
Acme/Billing/{index,Charge}.bs      module Acme.Billing          public Charge, private Round
Acme/Billing/Ledger/{index,Post}.bs module Acme.Billing.Ledger   public Post   (Billing wants this to itself)
Acme/Orders/index.bs                using Acme.Billing.Ledger    Total(c) -> Post(c)
```
- `bsc --src-root src src/Acme/Orders Total 41` prints `42`, exit 0. Nothing stops Orders naming Ledger.
- Cross-module call to a `private` function is `private_function`, not `unknown_callee`:
  `Peek calls Round/1, which Acme.Billing declares private ... Mark it public in Acme.Billing, or move the
  call inside it.` Qualified and unqualified spellings both refuse. That is the *what* half working (F12).
  Its message offers only "make it public", which is the wrong fix for an internal helper. That is a
  second reason a *who* rule would need its own message.
- Probe 09: `bsc --api` prints `int Charge(int)` for Billing and `int Post(int)` for Ledger, so Ledger's
  `Post` reads as a public API with no hint it is internal.

**Ticket 24 §2's consumer is mostly served by F12 already.** `RecomputeTotal/1` was `unclassified` because
"every function is exported today". Since F12 an unmarked helper is private, `--api` omits it (probe 09), and
a one-function-per-file helper stays in the same directory-module, so it is private across files. What *who*
adds is only the case where a helper must be `public` because a **sibling module** needs it. Probe 10 counts
that case in the corpus: 161 `.bs` files, 113 module names, **7 `using` edges, 4 modules named by any other
module** (`Jev`, `Shop`, `Shop.Collections.Ints`, `Support.Triage`). No directory called `Internal` exists.
The corpus cannot show demand for a rule about cross-module naming; it has almost no cross-module naming.

## Option A: an `Internal` path segment (Go's rule). Unit: directory subtree. Direction: callee, by position.

```
src/Acme/Billing/Internal/Ledger/{index,Post}.bs   module Acme.Billing.Internal.Ledger
src/Acme/Billing/{index,Charge}.bs                 using Acme.Billing.Internal.Ledger     accepted
src/Acme/Billing/Reconcile/Run.bs                  using Acme.Billing.Internal.Ledger     accepted (below Billing)
src/Acme/Orders/...                                using Acme.Billing; Charge(c)          accepted (public face)
src/Acme/Peeker/index.bs                           using Acme.Billing.Internal.Ledger     REFUSED
```
Rule: a module whose path has an `Internal` segment may be named only by the module above that segment and
by modules beneath it. No grammar, no keyword, no marker; the 16th keyword is not spent.

**Compiler delta, prototyped on a COPY of `compiler/src` (probe 03; the repo is untouched):**
- `option-a-internal-segment.patch`, +33/-1 lines: `internal_ok/3` called first in `add_import/7`;
  `internal_parent/1` and `internal_visible/2` (about 20 lines of string splitting); namespace imports filter
  their children; one `{internal_module, M, Parent, L}` error with a `bs_diag` clause pair copied from
  `unknown_module`.
- Result (`run.out`, same tree through three builds): base accepts Peeker, Peeker2 (the `using
  Acme.Billing.Internal` namespace route) and Other.Thing; the prototype refuses all three with
  `` `using Acme.Billing.Internal.Ledger` names an internal module / a module under Internal is for
  Acme.Billing and the modules beneath it``. Parent, descendant and public-face programs are accepted by both.
- **Attempt 1 was incomplete, and the probe showed it.** Orders2 named the type qualified
  (`Acme.Billing.Internal.Ledger.Entry`) with **no `using` of that module**, and every build accepted it,
  because `imported_types/2` (`bs_check.erl:1305`) builds its `Full` table from the whole `World`. So the
  `using` site is not the only door. `option-a-v2-type-site.patch` (+6/-3) filters that table; Orders2 is then refused.
  Two sites, not one.
- **The refusals the prototype produces at the second door lie.** The type refusal says
  `Acme.Billing.Internal.Ledger declares no type named Entry` (it does), and a namespace-filtered call says
  `Internal.Store is called but never imported ... add using Internal.Store` (adding it would be refused).
  This is the shape F12 §2 named: filtering at table construction destroys the private-versus-absent
  distinction, so a second table for diagnosis only is owed. That is real work the prototype did not do.
- A public function returning an internal type is accepted for outsiders (`Orders.Opened`, probe 03). Go
  does the same (`billing.Open` returns `ledger.Entry`, probe 11). Gleam's `internal` publish check exists
  for this; B# has no equivalent. Not a defect of A, but a decision it leaves open.

**Cost.** `internal_visible/2` is **1.6 to 1.8 us/call** (`micro.out`). The 201-module tree has 740 `using` lines:
about **1.2 ms** of a ~1.3 s compile, i.e. under 0.1%. Whole-tree wall clock (12 alternating runs each, probe
04) is **below the noise**: median in-VM 1288 ms base, 1322 ms v1, 1378 ms v1+v2, against a 1114-1511 ms spread (base alone).
Read that as "not resolved", not "free". The v2 type filter as written is **O(modules x world)**: 286 us per module
at a 200-module world, 1654 us at a 1000-module world, about 1.7 s per compile at 1001 modules (arithmetic on the
measured per-module figure). It can be made linear by filtering only `Internal` entries; that variant is UNMEASURED.

**Strongest counterargument.** The unit is a subtree and cannot say "Orders yes, Reports no". Probe 03 puts
`Acme.Internal.Shared` under the common ancestor: Orders3 (wanted) and Reports3 (unwanted) are both accepted,
and only code outside `Acme` is refused. To exclude Reports you must move the module under `Acme.Orders`,
which makes it unreachable by the third intended caller. Directory layout then carries a semantic job, and a
directory rename silently changes who may call. Go lives with this, and its rule is stricter than my prototype
in one respect: Go uses the **last** `internal` element (`pkg.go` `findInternal`), the prototype the first.

## Option B: a callee-side declaration in `index.bs`. Unit: explicit list. Direction: callee names who.

```
module Acme.Billing.Ledger
visible_to Acme.Billing, Acme.Orders       // Reports is refused; no directory has to move

record Entry { Amount: int }
```
**Delta (UNMEASURED; not prototyped, estimated by analogy to `using_decl`):** a lexer keyword, a parser
production, a `{visible_to, L, Mods}` declaration, a `visible_to` key in the `World` entry (`bsc.erl:227` builds
it), a check at the same two sites as A plus a check that each listed module exists, and its own diagnostic.
A is 33 lines for one site; B is A plus all of this. **The point of B over A is the one thing probe 03 showed A
cannot do.**

**Strongest counterargument.** It is the Erlang `-export` list in new clothes. F12 rejected that shape in
writing: "a second site that must agree with the definition, which is exactly the drift `bs_emit`'s single
`name/2` funnel was written to prevent" (F12 / ticket 40 §3). A module that lists its callers must be edited
when a caller is added, and a caller added without it fails at the caller's compile, in a file the caller's
author does not own.

## Option C: a third marker on the signature (`internal`). Unit: unspecified. Direction: callee.

```
internal int Post(int cents)       // internal to what?
```
**Delta (grep only, probe 12, UNMEASURED beyond that):** five readers of the visibility value test
`=:= public` or `=/= public` (`bs_check.erl:299, 364, 375, 478`; `bs_emit.erl:141`), and F12 made `none` sort as
private by construction. An `internal` function must be **exported** (siblings call it, probe 02) yet **hidden
from outsiders**, so the one predicate those readers share splits in two: "in the export list" (emit, `--api`
for siblings) and "nameable by this caller" (`exports_of`, `qual_table`). And the marker still has no unit,
so it needs an argument or a convention, which is Option A or B again.

**Strongest counterargument:** none worth the cost. The ticket's own question 3 ("a rule about modules may
not belong on a function at all") is borne out: the function marker cannot say who, and the BEAM cannot keep
the export private. Included so it is a rejected option with a reason, not an unexamined one.

## Neighbours: what each word means, with the run (probes 05 to 08, 11)

| Language | The word or file | What it actually does (run) |
|---|---|---|
| C# | `internal` | Assembly-scoped. UNMEASURED: no `dotnet` or `mcs` here; taken from ticket 22. B# has no assembly. |
| Go 1.24.7 | `internal/` directory | **Enforced at import**: `spy.go:3:8: use of internal package acme/billing/internal/ledger not allowed`; the parent, a descendant, and an outsider using the public face all build. Rule at `/usr/local/go/src/cmd/go/internal/load/pkg.go:1472-1564`, `str.HasPathPrefix(importerPath, parentOfInternal)` at `:1564`. Option A is this. |
| Gleam 1.18.1 | `internal_modules` in `gleam.toml`, `@internal` | **Not enforced at compile**: with a path dependency, `app` importing a module listed in `internal_modules`, and calling an `@internal pub fn`, both print `Compiled`. The effect I could see is documentation: `vault` has no page and `sneaky` no entry in `docs`. A publish-time leak check string exists in the binary (`cannot be published`) but did not fire on a public function returning an `@internal` type: UNMEASURED. Hex dependency also UNMEASURED. |
| Elm 0.19.2 | `exposed-modules` in `elm.json` | UNMEASURED. `elm make` needs `elm/core` from `package.elm-lang.org`, which the session's egress policy refuses (403; not routed around). The binary's own text says the field lists "which modules ... users of the package [may] have access to": a package-boundary rule, not a path rule. |
| Elixir 1.20.4 | `@moduledoc false`, `@doc false`, nested `defmodule` | **Documentation only**: `elixirc --warnings-as-errors` passes with an outsider calling both; runs (`1003`). Docs chunk marks them `:hidden`; the installed `Module` docs (line 186) say `false` "will make the entity invisible to documentation-extraction tools". Nested `defmodule Store` is just `Acme.Pay.Store` plus an alias. A cross-module `defp` call is only a *warning* (`undefined or private`, conflating the two causes F12 split), exit 0. No `.ex` source is installed (only `ebin`), so there is no source line to cite. |
| Erlang/OTP 29 | `-export`, `-moduledoc false`, `-doc false`, `-ignore_xref` | `-export` is the only gate and it is per-function, not per-caller. `-moduledoc false` records `hidden`; `erlc +warnings_as_errors` passes; `orders:peek(1)` is `{error,undef}` at run time. `xref` (a separate tool, needs `+debug_info`) flags `orders:peek/1 -> billing:round_/1` and `-ignore_xref` silences it; it cannot see a hidden-but-exported call. |

Only the languages with a **path convention that the compiler or build tool reads** (Go) enforce. Two BEAM
languages that have the word "private module" in their documentation tooling do not restrict callers at all.

## Recommendation: defer, record a trigger, and if forced take A

1. **Defer** (the ticket's own note). Evidence: no corpus demand (7 edges, probe 10); the ticket 24 consumer is
   served by F12 (probe 09); the BEAM contributes nothing (probe 02); and no neighbour on the BEAM
   restricts callers (probes 05, 07, 08).
2. **Deferring is cheap because A is additive.** It changes no existing program: no directory called
   `Internal` exists in the tree, and every current `using` edge stays legal. The F8 and F12 argument for
   doing it early ("sooner is cheaper", because they rewrote the whole corpus) **does not apply**; the rewrite
   cost of A today is zero files. That is the strongest argument *against* deferring, and it fails on a measured count.
3. **Trigger to reopen:** re-run `probes/60/10_corpus/run.sh`; reopen when a module is named by two or more
   importers **and** an agent-authored program names a module the author did not intend as public. One such
   observed case is the *second occurrence* the repo's own rule asks for before a new check.
4. **If David wants it built regardless, Option A**, with these conditions the prototype exposed: the rule
   must cover the type site as well as `using` (v2), the diagnostics need their own `internal` versus
   `unknown` distinction, and the decision on a public signature that returns an internal type should be
   made with it. Option B only if a real case needs "Orders yes, Reports no".

**The one question to ask first, alone, as a program.** This compiles and runs today (probe 01 A):
```
module Acme.Peeker
using Acme.Billing.Internal.Ledger      // an outsider names a helper Billing keeps to itself
```
Under "yes, build the rule" it is refused with ``names an internal module``; under "not yet" it stays legal
and the ticket remains parked. The unit, direction and marker questions follow only from a yes.

## Evidence index

| Probe | Shows | Run |
|---|---|---|
| `01_tree` | nothing stops X naming Y's public function; `using` is the dependency list; private cross-module error text | `run.sh`, `run.out` (`run.first-attempt.out`) |
| `02_beam` | exported vs local, one entry label, no caller check | `run.sh`, `run.out` (`run.first-attempt.out`) |
| `03_proto` | Option A prototype, two patches, accepted/refused, type-site hole, subtree limit | `build.sh`, `run.sh`, `run.out`, `*.patch`, `run.first..fifth-attempt.out` |
| `04_cost` | 201-module tree, 12 runs x 3 builds; micro cost; quadratic type filter | `run.sh`, `micro.sh`, `run.out`, `micro.out` |
| `05_gleam` | `internal_modules`, `@internal` | `run.sh`, `run.out` |
| `06_elm` | UNMEASURED (egress refused) | `run.sh`, `run.out` |
| `07_elixir` | `@moduledoc false`, `@doc false`, nesting, cross-module `defp` | `run.sh`, `run.out` |
| `08_erlang` | `-export`, `-moduledoc false`, xref, `-ignore_xref` | `run.sh`, `run.out` |
| `09_consumer` | ticket 24 §2's consumer after F12 | `run.sh`, `run.out` |
| `10_corpus` | cross-module naming in the corpus | `run.sh`, `run.out` |
| `11_go` | Go `internal` rule, plus installed source lines | `run.sh`, `run.out` |
| `12_readers` | visibility readers a third marker would touch | `run.sh`, `run.out` |

Repo sources read: `CLAUDE.md`; tickets 60, 22 (Answer, "What NOT building it costs"), 24 §2, 18 §5 (`:852`,
`:440`, `:975`), 40 §3, 41 §2, §4, §5; `F12`, `F15`; `bs_check.erl:244, 497-524, 1244-1315`;
`bs_parser.yrl:308-324`; `bs_emit.erl:139-141`.

## Limits

- **Toolchain:** OTP 29 / Elixir 1.20.4 / Gleam 1.18.1, not the repo's pinned OTP 28.5. The compiler was built
  by hand (rebar3 fails on OTP 29) from `compiler/src` at `5133d97`; the repo's own suite was not run, so the
  prototype was not checked against the existing 1000+ tests. Only my probe trees were run through it.
- **Timing:** one machine, one VM boot per run, noise of +-15%; whole-tree timing cannot resolve the rule's
  cost, only the micro-benchmark can (it times a rebuilt `bs_check` with `+export_all` on the real names).
  Machine and load differ from ticket 39's Apple Silicon numbers; none were copied.
- **UNMEASURED:** C# `internal`; Elm `exposed-modules`; Gleam publish-time leak check and Hex dependencies; a
  linear version of the type filter; Options B and C (estimated, not built); the language server and REPL
  behaviour under Option A; `bsc --api` on a module with an `Internal` segment.
- **Probe history:** attempts 1 to 4 of probe 03 failed on my own B# mistakes (record projection syntax, a
  namespace short name, shell word-splitting); attempt 5 (v1 only) is what exposed the type-site hole and
  produced v2. Expectations never moved to make a probe pass; the corrections are in each script's header.
- **Circularity:** the prototype is judged by the cases I wrote for it. The Go rule is the independent check
  that the cases are the right ones, and the Go run agrees case for case except the first-versus-last
  `internal` element.
- No decision is made here. The ticket, Linear, `wayfinder/` and `compiler/` were not touched.

## Verifier findings (independent re-run, see probes/60/VERIFY.md)

All 12 probes reproduce; no circular probe found (accepted/refused programs differ only in the
property under test; every `*-attempt.out` changed for a syntax or script mistake, not an
expectation). Elm (probe 06) is still blocked by a 403, left unbypassed.

**Correction to the cost claim.** "Below the noise" holds for the `using`-site check only. The v2
type filter is not free: verifier in-VM medians on the same tree were base ~1.27-1.30 s, v1 ~1.36-1.41 s,
v1+v2 ~1.55-1.57 s. The brief's "x201 modules = 57 ms" assumes one `imported_types` call per module,
but `type_env` is reached from four checker sites (`bs_check.erl:326, 371, 384, 1548`), so ~4 x 58 ms
~ 230 ms, matching the measured gap; the "1.7 s at 1001 modules" extrapolation carries the same
undercount. Read the v2 cost as roughly 4x what the Cost section says. Minor: the "second site that
must agree" quote is from ticket 40 lines 298-299, not F12.
