# Decision brief: ticket 60 (ENG-242), "Which modules may name this one?"

Repo HEAD when measured: `580cc6e` (the ticket measured at `0b761f6`). Compiler under test: `/tmp/bsbuild/ebin`, a scratch build on OTP 25 with a lexer shim (diagnostic columns wrong, semantics unchanged; the checker, parser and emitter sources are byte-identical to `compiler/src`, checked with `diff -rq`). Three patched copies: `/tmp/bsb_60_a`, `_b`, `_c`; their diffs against `compiler/src` are `artifacts/probes/60/opt{A,B,C}.diff`. Every number and diagnostic below comes from a `*.out` beside its `*.sh` in `artifacts/probes/60/`. Nothing in `wayfinder/`, `compiler/` or Linear was touched.

## The question

A module controls *what* it exposes (`public`/`private`, F12). Nothing lets it say *who* may name it. Do we add that, and if so, with what unit, direction and spelling?

## Recommendation first: defer, and say what would un-defer it

The ticket says "Not owed a decision soon". The evidence agrees, on three independent grounds.

1. **The consumer the ticket cites is already served.** Ticket 24 §2 says "every function in an aggregate is exported today" and parks `RecomputeTotal/1` as `unclassified`. That went stale on 2026-08-17 when F12 made private the default. A test module that names an unmarked helper is refused today (`p1_current.out`, case `A_unm`: "Go calls Unmarked/1, which B declares `private`"). The agent-tests-the-easy-function drift is closed by `private`.
2. **The corpus shows no demand.** `p10_corpus_demand.out`: 138 modules, 9 dotted, 5 cross-module `using` edges in total. The only edge where every importer sits inside the callee's own subtree is `Shop` <- `Shop.Billing`. Zero modules have an `Internal` path segment. The residual need, a helper shared across two modules of one subtree that must not be global API, has no instance in the repo.
3. **No option is a boundary.** Every caller-side check is a lint over the static call graph, and it was bypassed three ways in executed probes (see Bypass). That fits ticket 22's own framing ("compile-time visibility over beam-sharp source only"), but it means the feature is a drift guardrail, not enforcement, and it should be priced as one.

**What would change this.** A second multi-module aggregate in an exemplar, or an observed case, where a helper needed by two modules of one subtree is made `public` only to be shared and then gets named from outside it. That is the "second occurrence" test CLAUDE.md applies to new checks. If you want to decide now anyway, answer the gating question below. Option A is the cheapest and the only one with an executed precedent.

## Stale or corrected premises

| Premise (where) | Status now | Evidence |
|---|---|---|
| `add_module_import/5` at `bs_check.erl:407-425` (ticket 60, 22) | Drifted. It is `add_module_import/3` at `bs_check.erl:511`, called from `add_import/7` at `:497`. | grep |
| "reads only the callee's export set" | Partly stale. It also folds the callee's `types` (F44). Privacy is not checked there at all. F12 checks it at the call site: `private_callee` (`:4276`), `call/6` (`:4200`), `fname_type` (`:3657`), fed by `private_table` (`:554`). | read |
| "no `internal`/`friend`/`sealed`/`visible_to` in the checker" | Still true. The only grep hits are `erl_internal` and prose. | grep over `compiler/src` |
| Ticket 41 §5 draws `Orders/Internal/` as a "SUB-MODULE, source-only (ticket 13)" | **Superseded by F15.11.** A nested directory holding `.bs` files is its own module with its own beam. | `p11_submodule_premise.out`: compiling `Acme/Orders` emits `Acme.Orders.beam` and `Acme.Orders.Internal.Pricing.beam`, each exporting only its own functions |
| Ticket 24 §2: "every function in an aggregate is exported today" | Stale since F12's amendment (private is the default). The consumer is largely served. | `p1_current.out` |
| "Per-function control can't lean on the emitter" (18 §5, `18-boundary-defence.md:439-440`) | Confirmed for a restricted-but-exported function. | `p5_optB.out`: `Recompute/1` is in the `.beam` export list and `erlang:apply` reaches it |

Two surprises unrelated to the options but found on the way:

- **B# source can reach another module with no `using` line.** `:erlang.apply(:'B', :'Pub', [n])` compiles and runs, and `using B` is absent. 41 §1's "a file's `using` lines are its dependency list" is therefore not total. (`p2_current_foreign.out`, case b printed `6`.)
- **A dependency that fails to parse is reported as "`using X` names no module and no namespace".** The message hides the cause (`p6_optC.out`, unpatched run against a callee using the new keyword).

## Sub-decisions and what gates what

1. **GATING: does the restriction need a declaration at all, or can the path alone carry it?** F15 already makes the directory the module, and 41 §5 already drew `Internal/`. If the path can carry it, there is no syntax, no marker-versus-construct question, and the unit is the path prefix. If it must be declared, the other three decisions open.
2. **Unit** (subtree, named group, explicit list). It follows from (1): path-only forces the subtree.
3. **Marker versus construct.** A function marker cannot name a unit. It has to derive one, so (2) comes first.
4. **Direction** (callee names who, or caller declares what it depends on). The caller already declares its dependencies with `using`. A restriction declared by the caller restrains only the party that writes it, so it cannot protect a callee. It is a layering rule held in project configuration, and CLAUDE.md puts that outside the language ("a gate guards the language or the handoff"). I did not prototype it; this is argument, not measurement. The three options below are all callee-side.
5. **Checker cost.** Measured below, and not a differentiator.

**The gating question as code.** `Acme.Billing` writes `using Acme.Orders.Internal.Pricing`. Should that compile?

```csharp
module Acme.Billing
using Acme.Orders.Internal.Pricing     // refused if the answer is "the path carries meaning"

public int Due(int n)
Due(n) -> Compute(n)
```

## Option A: the path decides (Go's `internal/` rule)

A module whose path has an `Internal` segment may be named only by modules at or below the segments before it. No new syntax.

```csharp
module Acme.Orders.Internal.Pricing          // file: Acme/Orders/Internal/Pricing/Pricing.bs
public int Compute(int n)
Compute(n) -> n * 2

module Acme.Orders                           // ok: it is the parent
using Acme.Orders.Internal.Pricing
public int Total(int n)
Total(n) -> Compute(n) + 1

module Acme.Billing                          // refused
using Acme.Orders.Internal.Pricing
```

Executed (`p4_optA.out`):

```
Acme/Orders, Acme/Orders/Sub, Acme/Billing_ok   accepted
Acme/Billing_bad   REFUSED  error: `using Acme.Orders.Internal.Pricing` names an internal module
                            a module under an `Internal` segment is visible only to Acme.Orders and the modules beneath it.
```

The unpatched compiler accepts all four. Run result for the allowed callers: `11`.

**Compiler delta** (`optA.diff`, 27 lines added, 2 changed, 2 files):

- One function, `internal_ok(Self, M)`, called in `add_import` (explicit `using`) and in the namespace branch (`add_namespace_import`, filtering children).
- One diagnostic term and its `bs_diag` message.
- No parser, lexer, emitter or `bsc.erl` change, and no new metadata.

**Not built in the prototype:**

- the F-file, tests and the gate;
- `LANGUAGE.md`, the editor grammar and the `--api` output;
- the JSON schema entry for the new tag.

**Precedent, executed** (`s4_go.out`, Go 1.24.7): `go build` accepts `orders` and `orders/sub` and refuses `billing` with "use of internal package example.com/acme/orders/internal/pricing not allowed". The rule is stated at `/usr/local/go/src/cmd/go/alldocs.go:2742-2745` and implemented at `cmd/go/internal/load/pkg.go:1472`. Go's `internal` and C#'s `internal` mean different things, which is ticket 22's false-friend warning applied to a second language. C#'s meaning I did not execute; it comes from ticket 22 `:435`.

**Strongest counterargument.** It grants the whole module or nothing. `RecomputeTotal`, the ticket's own example, sits in the aggregate's directory today. Making it internal means moving it into a different module. That module has its own beam, its own record tag namespace (`Acme.Orders.Internal.Totals.X`, not `Acme.Orders.X`), and its function must be `public` (so it is exported on the BEAM anyway). That cuts across "one beam per aggregate" (ticket 13 §3). Two smaller costs. A directory name now has compiler meaning, where 41 §5 prided itself on "no marker file, no keyword". And the namespace-import path gives a misleading error (`p4_optA.out`): a caller who writes `using Acme` and then `Orders.Internal.Pricing.Compute(n)` is told "is called but never imported; add `using Orders.Internal.Pricing`", and following that advice then trips the refusal.

Side effect worth knowing: `using Acme` on a namespace compiles every module under `Acme`. A refused sibling therefore masked an unrelated caller's result in my first run, until I removed it.

## Option B: a third marker, `internal`, on the signature

`private` stays module-only, `public` stays global, `internal` is exported but callable only from the callee module's own subtree (the module and modules beneath it). In this prototype it uses the module's subtree, not the parent's, so it points the opposite way to A: descendants see an ancestor's helpers.

```csharp
module Acme.Orders
internal int Recompute(int n)
Recompute(n) -> n * 2
public int Total(int n)
Total(n) -> Recompute(n) + 1

module Acme.Orders.Tests   // ok: beneath Acme.Orders
module Acme.Billing        // refused: Due calls Acme.Orders.Recompute/1, which Acme.Orders declares `internal`
```

Executed (`p5_optB.out`):

```
Acme/Orders, Acme/Orders/Tests, Acme/Billing_pub   accepted
Acme/Billing_unq   REFUSED  Due calls Recompute/1, which Acme.Orders declares `internal`
Acme/Billing_qual  REFUSED  Due calls Acme.Orders.Recompute/1, which Acme.Orders declares `internal`
                            an internal function is visible only to Acme.Orders and the modules beneath it.
Acme/Billing_fun   accepted (see Bypass)
```

Unpatched, the callee file itself is a syntax error.

**Compiler delta** (`optB.diff`, 53 lines added, 13 changed, 6 files):

- lexer token and parser `visibility` rule;
- `internal_of/1` and a `view/2` that moves internal names from `exports` to `private` for out-of-subtree callers, so the existing `private_callee` path reports them;
- the readers of the visibility field: `exports_of` (`:358`), `private_of` (`:476`), `private_callback` (`:297`) and `bs_emit:is_public` (`:141`);
- one new `World` field in `bsc.erl:239`;
- the diagnostic.

Also owed and not built: `polys_of` (internal polymorphic functions are not handled), and `bs_api.erl:152,158`, which pattern-match `public` and so would not list internal operations.

**Strongest counterargument.** This spends C#'s `internal` word on a different meaning, which ticket 22 says not to do. It also makes the marker three-valued where F12's amendment deliberately made it a two-valued default whose readers test `=:= public`, so every future reader must remember a third state. It restricts functions only. A record or type in the same module stays nameable by anyone (`p12_types_and_blast.out`: Billing named `Order` from a module whose only function was `internal`, accepted). The exported function keeps its entry-point cost, because the prototype's `is_public` change gives it the boundary guard; I did not measure that guard here.

## Option C: the callee lists its friends

```csharp
module Acme.Pricing
friend Acme.Orders           // Acme.Orders and the modules beneath it may `using` this
public int Compute(int n)
Compute(n) -> n * 2
```

Executed (`p6_optC.out`):

```
control, unpatched, tree without the friend line:   all four callers accepted
Acme/Orders, Acme/Orders/Sub   accepted
Acme/Billing, Acme/Reports     REFUSED  `using Acme.Pricing` is not allowed here
                                        Acme.Pricing names its friends: Acme.Orders (and the modules beneath them).
after adding `friend Acme.Reports` to the CALLEE:   Reports accepted, Billing still refused
typo `friend Acme.Ordres`:     Orders now REFUSED, message names "Acme.Ordres"
```

**Compiler delta** (`optC.diff`, 31 lines added, 3 changed, 5 files): lexer token, one `decl` rule, `friends_of/1` carried in the `World` entry (`bsc.erl:239`), `friend_ok/3` in `add_import`, the diagnostic.

**Strongest counterargument.** It is a second list that must agree with the first, which is the drift 40 §3 cited when it took `public` on the signature instead of an `-export` list. Every new legitimate caller means editing the callee (`Reports` above). Nothing checks that a named friend exists, so a stale entry is silent and a typo fails closed with a message that is correct but unhelpful. And the callee now knows its callers, which inverts the dependency direction `using` expresses.

## Bypass: can a compile-time caller-side check be circumvented on the BEAM?

Yes, three ways, all executed. These apply to all three options and to F12's `private` today.

| Route | Evidence | Result |
|---|---|---|
| A public function hands a protected function out as a `fun` | `p3_bypass.out` (private `Priv`, via `Handout()`); `p5_optB.out` (`Billing_fun` accepted) | `7` and `10`. The static refusal still fires for direct naming, and fires in value position too (`p3`, control 2). |
| Erlang or Elixir callers | `p3_bypass.out`, `p5_optB.out` | The beam exports `Recompute/1` (B) or `Compute/1` (A, C). `erlang:apply(Mod, Fn, [5])` returns `10`. Today's `private` is the only one actually enforced at run time (`{undef,...}`), because it is not exported. |
| B# source itself via `:erlang.apply(:'B', :'Pub', [n])` | `p2_current_foreign.out` case (b) | Compiles and prints `6` with no `using B`. The same call on the private function gives `crashed: error:undef`. |

A foreign declaration `using :'B' { int Pub(int n) }` does not work: foreign names must be lowercase (`syntax error before: 'Pub'`), and B# function names are PascalCase. So direct naming has no loophole, only the dynamic routes above.

## Neighbours

- **Erlang** (`s1_erlang_xref.out`): `-export` is the only hiding, and `erlc` accepted `billing -> pricing:compute/1` with no caller restriction. `xref` answers "who uses this" as an after-the-fact query (`{module_use,pricing}` returned `[billing,orders]`) and only if the beams carry `debug_info`; without it, my control run failed with `unknown_constant`. Analyses available are listed at `/usr/lib/erlang/lib/tools-3.5.3/src/xref.erl:606-617`. There is nothing like a callers restriction in OTP 25's compiler or xref.
- **Elixir 1.14.0** (`s2_elixir.out`): `@moduledoc false` and `@doc false` are documentation-only. `Code.fetch_docs` reports `:hidden`, yet `Acme.Billing` calls the module (`10`), `apply` works, and the exports list includes it. Calling a `defp` from another module is a **warning**, "undefined or private", with `elixirc` exit 0 and a run-time `UndefinedFunctionError`. `defp` is enforced by the export list, not by a compile error.
- **Go 1.24.7** (`s4_go.out`): the executed `internal/` precedent, exactly Option A's rule. Not in your list; I ran it because it was installed.
- **Elm** (`s3_elm.out`): blocked, `package.elm-lang.org` returned 403, so `exposed-modules` behaviour is **UNVERIFIED-NOT-EXECUTED**.
- **Gleam**: **UNVERIFIED-NOT-EXECUTED.** A grep of `wayfinder/` and `compiler/features/` for `@internal`, `internal_modules` and Gleam-with-visibility returns no hit, so the repo has no source I can cite. I assert nothing about it.

## Checker cost and metadata size

**Compile time** (`p7_cost.out` whole process, `p7b_cost_invm.out` in one VM, synthetic trees of 50 and 200 modules, about 2 imports per member, interleaved runs).

| Config | N=50 in-VM median (ms) | N=200 in-VM median (ms) |
|---|---|---|
| baseline, A-shaped tree | 220 (IQR 20) | 1082 (IQR 310) |
| A | 211 (16) | 1210 (321) |
| baseline, B-shaped tree | 248 (39) | 1374 (279) |
| B | 242 (40) | 1331 (342) |
| baseline, C-shaped tree | 208 (14) | 1121 (272) |
| C | 234 (40) | 1029 (117) |

Each cell is 24 runs (12 per VM, 2 VMs). **The result is "not resolvable".** The two baseline rows are the identical configuration run in different slots, and they differ by 6% (N=50) and 4% (N=200); C comes out *faster* than its baseline at N=200, which a real cost cannot do. The noise floor is about 10%. The whole-process runs, 15 each, tell the same story, and VM boot itself drifted between blocks (188 ms versus 283 ms).

**Micro-benchmarks** of the check bodies, copied verbatim from the diffs (`p9_check_micro.out`):

| Check | Cost |
|---|---|
| A `internal_ok` | 3.7 µs refused, 1.2 µs accepted, per import |
| C `friend_ok` | 2.2 µs refused, 75 ns when the callee names no friends |
| B `view/2` over a 200-module World | 105 µs, once per compiled module in the prototype |

For 200 modules that is under 2 ms for A and C. B's is about 21 ms, roughly 2% of a ~1.1 s build. B's figure is the naive prototype, quadratic in module count, and a per-import filter would be linear.

**Metadata term size** (`p8_metadata_size.out`). Baseline `World` entry for `Shop` (8 exports): 18,688 heap bytes, 8,996 as `term_to_binary`.

| Option | Extra metadata |
|---|---|
| A | none (derived from the name) |
| B | 72 bytes heap for 1 internal function, 832 for 20 |
| C | 16 bytes for 1 friend, 160 for 10 |

The entry lives only in compiler memory (`bsc.erl:204-209`, "No artefact"). No option adds an attribute or chunk to the `.beam`; B only adds names to an export list the beam already has.

**Reserved words.** `internal` and `friend` appear as tokens in 0 of 424 `.bs` files outside comments. `Internal` as a module-path segment: 0 files.

## Not measured, or could not run

- Elm and Gleam, as above. C#'s `internal` semantics were not executed (taken from ticket 22).
- Caller-declared direction: argued only, no prototype.
- Whether B's exported `internal` function pays F24's boundary guard: implied by the prototype's `is_public` change, not observed in emitted code.
- The prototypes have no tests, F-file, gate, `--api` or editor-grammar work. The gate-first rule in CLAUDE.md means the real cost of any option is higher than the line counts here.
- Timing was on OTP 25 with the lexer shim and a shared, noisy machine; absolute numbers will differ on OTP 28. Diagnostic columns in all outputs are wrong by the shim.
- Other dynamic reach (hot code upgrade, `sys:replace_state`) was not probed; the three bypasses above already establish the limit.
- Parser conflicts: the patched grammars report the same "6 shift/reduce" as the unpatched `bs_parser.yrl`; I did not examine whether any of them involve the new tokens.
