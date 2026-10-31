# Decision brief: ticket 60 (ENG-242), which modules may name this one?

Prepared as input for review. The ticket file and Linear are untouched. Nothing here is decided.
Probes: `artifacts/60-which-modules-may-name-this-one/probes/` (`./run_all.sh` runs all;
each has a documented command in its header and a saved `.out`). Environment: OTP 25, Elixir 1.14.0.
`bsc` could not be built here (needs OTP 27+ leex), so **no probe runs B# source**. Every "compiler
delta" below is read from `compiler/src` and sized by a prototype in Erlang, not by building it.

## 1. The four sub-decisions are not independent

The ticket lists four (unit, direction, marker-vs-construct, checker cost). They chain:

1. **Direction gates everything.** If the *callee* names who may call it, the unit is a set of
   callers and the check needs a field on the callee's World entry. If the *caller* lists what it
   may name, the unit is a set of callees and nothing on the callee changes. Ask this first.
2. **Unit follows from direction.** Under callee-declared, F15 makes the module path
   (`Shop.Orders.Total` is declared `module Shop.Orders`) the only thing the checker holds about a
   caller, so the unit is a path prefix. This is Rust's `pub(in path)` / Scala's `private[pkg]`
   (UNPROBED, cited from the Rust Reference "Visibility and privacy" and the Scala spec), not C#'s
   `internal` (assembly-scoped, UNPROBED, cited from the C# language reference).
3. **Marker-vs-construct follows from the unit.** A path-prefix rule is a property of one name, so
   it can sit on a signature (F12's placement) or on the module. This is the only genuinely open
   spelling question once 1 and 2 are answered.
4. **Checker cost is an output, not an input.** It depends on where the check sits (per `using`
   edge or per call site). Probe p4 measures both.

**One finding that changes how much of this is needed (read before the options).** Ticket 24 §2's
`unclassified: RecomputeTotal/1` was written 2026-08-13, four days before F12 made private the
default (2026-08-17). A helper used only inside its own directory-module is *already* closed by
F12, with no new feature. What F12 cannot express is the remaining case: a helper that **sibling
modules** need (say `Shop.Reports` calling `Shop.Orders.RecomputeTotal`), which today must be
`public` and is therefore visible to every module. That is the only consumer this ticket has, and
it is narrower than the ticket's "there is a consumer waiting" suggests. Also `unclassified` as 24
§2's boundary category was never built: `grep unclassified compiler/src` finds only an unrelated
diagnostic tag (`bs_api.erl:280`, `bsc.erl:897`). (Claims table: C20, C21.)

## 2. What the BEAM and the neighbours give today

- **The BEAM enforces export-or-not and nothing about the caller.** Observed (p1): an unexported
  function is `undef` remotely; an exported one is callable from an unrelated, separately compiled
  module; a `-friend([stranger])` attribute compiles without warning, is stored in the beam
  `attributes` chunk, and the loader ignores it. A grep of 263 OTP compiler/stdlib/kernel/tools/
  syntax_tools source files for `visible_to|-friend|internal_to|-restrict` found one hit, in a
  comment about "optimization-friendly" code, so no mechanism exists in OTP 25.
- **xref is a post-hoc auditor, not a compile gate.** p2: with `debug_info` beams, the query
  `ME || (Mod) core` lists the callers of a module (`||` is the target-restriction operator,
  `xref_parser.erl:34`). Combined with a prefix filter it recovered all planted violations at
  N=100, 1000 and 3000 modules. Cost at N=3000: `add_directory` 446 ms, query 46 ms (erlc of the
  same 3300 files: 4.9 s). Two caveats: beams without `debug_info` give zero edges (p2b; xref prints
  a "Skipping" line only when warnings are on, and p2 turned them off), and it is a separate tool in
  the build, the shape ticket 21 recorded as the one that gets skipped (INHERITED from 21 via 22,
  not re-executed). xref is the only thing that could police *Erlang and Elixir callers* of a B#
  module, which a `bsc` check cannot see.
- **Elixir:** `defp` is a link-time wall; `@moduledoc false` / `@doc false` hide from docs by
  convention. p3: a stranger module calling an `@moduledoc false` function compiled with no
  diagnostic at all and ran. (That `@doc false` removes the entry from generated docs is UNPROBED:
  the probe's modules were compiled in memory, so `Code.fetch_docs` returned `:module_not_found`.
  Elixir sources are not installed, only beams, so there is no file:line to cite.)
- **Gleam:** `@internal` / `internal_modules` in `gleam.toml`. UNPROBED (cited from the Gleam
  language tour and the package-interface docs); my recollection is that it hides the item from the
  package's documented API and flags use from *other packages*, not within the package. Treat as a
  lead, not a fact.
- **Elm:** `exposed-modules` vs `other-modules` in `elm.json`; package-level only, and the module
  list is in the build file, not the source. UNPROBED (cited from the Elm package docs).
- **Java 9:** `module-info` `exports p to m1, m2;` is a **callee-side friend list**, the closest
  precedent for a named list (UNPROBED, cited from the JLS §7.7).
- **C# `internal`:** assembly-scoped; `InternalsVisibleTo` is the friend list. UNPROBED. This is
  the false friend ticket 22 warned about.

## 3. The options

All three keep the **checking in `bsc`, over B# source, at compile time**. Ticket 06's limit
(INHERITED: "no way to publish a function to your own compiler but not to `erl`") applies to every
option: the function stays exported on the BEAM (p1), so Erlang, Elixir and dynamic callers are
outside the guarantee.

### Option A: callee-declared, per function, subtree of an ancestor path (recommended)

```csharp
// Shop/Orders/RecomputeTotal.bs
module Shop.Orders

public(in Shop) money RecomputeTotal(Order o)
RecomputeTotal(o) -> Sum(o.Lines)
```

```csharp
// Shop/Reports/Totals.bs        module Shop.Reports : inside Shop
using Shop.Orders
public money Restate(Order o)
Restate(o) -> RecomputeTotal(o)                       // compiles

// Billing/Invoice.bs            module Billing.Invoice : outside Shop
using Shop.Orders
public money Bill(Order o)
Bill(o) -> Shop.Orders.RecomputeTotal(o)
//          ^ error: RecomputeTotal/1 is public(in Shop); Billing.Invoice is not inside Shop
```

Rule: `public(in P)` is callable from module `M` iff `M == P` or `M` starts with `P.`, matched on
segment boundaries. `P` must be an ancestor-or-self of the declaring module, else
`{scope_not_ancestor, P, Declaring}` (this keeps the feature from turning into a free-form friend
list; the friend list would be a different decision).

What the compiler must gain (all read from the current source):
- **Parser:** `visibility -> 'public' | 'private'` (`bs_parser.yrl:262-268` per F12) gains a third
  value, e.g. `{public_in, ModPath}`. A new token is not needed if `in` stays contextual.
- **Export filter:** `exports_of/2` must export it (a `public_in` function is on the BEAM export
  list; one entry label per function, ticket 18 §5, INHERITED). F12's amendment records that its five
  readers test `=:= public`, so a new value falls through as **private** by construction. That is
  the safe direction: forgetting a reader yields "not exported", which the first test catches,
  rather than silently exporting too much.
- **World entry** (`bsc.erl:227-239`): add `restricted => #{{N,A} => ModPath}` beside `private`,
  from a new `restricted_of(Decls)` shaped like `private_of/1` (`bs_check.erl:475-479`).
- **Import env** (`import_env/4`, `bs_check.erl:~490`): `Self` is already in scope at `add_import/7`
  (`:494-497`). Build a `restricted` table keyed like `private_table/1` but **filtered by caller**:
  an entry whose prefix does not contain `Self` goes into `privates` instead. Then the two existing
  call-site refusals (`bs_check.erl:3850` for unqualified, `:4391` for qualified, via
  `private_callee/3` at `:4470`) fire unchanged, and only the *message* needs a new term
  `{restricted_function, M, Name, Arity, ModPath}` so the diagnostic says "inside Shop" rather
  than "private".
- **Diagnostic wording:** one new `resolve_error` clause; `--api` lenient mode (which skips unknown
  imports) needs a decision on whether it reports the refusal.
- **Gate/test:** a `Shopify` / `Shop.G10`-vs-`Shop.G1` pair is the failing test to write first (see
  evidence).

Evidence:
- Segment-boundary matching is load-bearing, not pedantry: p4's mutant (plain string-prefix) is
  wrong on the generated tree because `Shop.G10.M1` is "inside" `Shop.G1` as strings and
  `ShopX.G0.Spy` is "inside" `Shop`. The correct implementation matched an independent
  token-list oracle on all three sizes.
- Cost, per call site against a prefix table: the p4 SITE variant walks the abstract forms
  separately: 3.8 s for 400,040 call sites (10,001 modules). This **overstates** the real cost,
  because the checker already visits every call at `private_callee/3`; the marginal work there is
  one map lookup plus a binary compare. I did not measure that marginal cost, and no claim is made
  for it beyond the upper bound.
- Persisting to the beam for precompiled dependents (needed only when callee and caller are built
  in different invocations; `import_env` today only sees modules checked in this invocation per
  its own comment, `bs_check.erl:~482`): p5, +248 bytes per beam when all 10 functions are marked
  (+32 bytes for one module-level marker) on a ~800-byte beam; reading it back 8 µs per beam.

**Strongest counterargument.** It makes `public` a family. A reader who sees `public` can no
longer tell whether the world can call it, which is the exact ambiguity `public`/`private` (F12)
removed, and the deliverable is a feature whose only demonstrated consumer is one helper class
that F12 already partly closed. If nothing in the exemplar corpus today wants "sibling-only", this
is speculative: grep `compiler/examples` for a `public` function that only a sibling calls before
building it (I did not run that audit; the ticket asked for no exemplar evidence either).

### Option B: callee-declared, per module, in `index.bs`

```csharp
// Shop/Orders/index.bs
module Shop.Orders
within Shop                    // every function of Shop.Orders is nameable only inside Shop
using Shop.Collections
record Order { ... }
```

Compiler delta: one `{within, L, ModPath}` decl (parser), `within => ModPath` on the World entry,
and one check **per `using` edge** in `add_import/7` after the `maps:is_key(M, World)` branch
(`bs_check.erl:497`), plus filtering `children(M, Known)` in the namespace branch. No change to the
two call-site refusals. A refused `using` reports the `using` line, which is the earlier and
arguably clearer place.

Evidence: p4 EDGE variant, 0.28 s for 51,045 edges (10,001 modules), against 3.8 s for the
separate site walk; 2.4 ms at 100 modules. Beam cost +32 bytes per module (p5), only if persisted.

**Strongest counterargument.** It restricts the whole module, so a module cannot have a public
face and a sibling-only helper: the exact `RecomputeTotal` case from 24 §2 is unreachable (the
module must be either entirely public or entirely restricted), and the workaround is splitting a
directory in two, which is architecture driven by the visibility feature. It also moves the
decision into `index.bs`, away from the function an agent is editing under F15's
one-function-per-file `write_scope`. That distance can be argued either way: it makes widening
visibility a reviewable edit in a different file (a feature), but it also means a function file
carries no sign of who may call it (a cost).

### Option C: caller-declared allow-list

```csharp
// Shop/Reports/index.bs
module Shop.Reports
uses only Shop.Collections, Shop.Orders      // closed set; any other `using` is refused
using Shop.Collections
using Shop.Orders
```

Compiler delta: one decl on the caller; check every `using` edge's target against the list in
`add_import/7`. No World change and no beam change.

Evidence: structurally the cheapest (same per-edge shape as B, no callee data). The cost is
authoring: `uses only` duplicates the `using` lines already in the file (ticket 41 §1: `using`
"declares what it depends on"; INHERITED), so every new dependency edits two places.

**Strongest counterargument.** It protects nobody: the caller chooses its own allow-list, so the
agent that wants to call `RecomputeTotal` adds one word to its own `uses only` line. Ticket 22's
whole argument for the *who* half was that the callee's owner needs a say, and this gives the
callee none. Useful as architecture lint (a layering rule such as "domain does not use infra"), but
that is a different feature than the one this ticket's consumer needs.

## 4. Recommendation

Ask the gating question alone first: **who holds the declaration, the callee or the caller?** The
only consumer on record (24 §2's unclassified helper) needs the callee, so Option C answers a
different question and should leave this ticket. Between A and B, I recommend **A** on one
sentence: the helper that sibling modules need sits next to public siblings in the same module, so
the marker must be at function granularity or the consumer is not served. B is the cheaper
fallback if David judges the consumer to be speculative, because it costs one decl and a per-edge
check.

Two build-order notes. The failing test and gate come first per CLAUDE.md; the `Shopify` / `G1` vs
`G10` pair above is that test. And xref remains the only tool that could police Erlang/Elixir
callers; whether to ship an `xref` recipe is a tooling-layer question this ticket should not own.

## 5. Claims table

| # | Claim | Basis |
|---|---|---|
| C1 | Unexported fn is `undef` remotely; exported fn callable from any module; `-friend` attribute compiles silently and is ignored by the loader | `p1_beam_has_no_caller_restriction.escript` / `.out` |
| C2 | No friend/visible-to mechanism in OTP 25 compiler/stdlib/kernel/tools/syntax_tools sources (263 files; 1 false-positive hit in a comment) | p1 (regex scan; absence is bounded by the regex used) |
| C3 | xref restricts by callee module with `||`; recovers planted violations at N=100/1000/3000 | `p2_xref_caller_restriction.escript` / `.out` |
| C4 | xref cost at N=3000: add 446 ms, query 46 ms; erlc of same 4.9 s | p2 (single run each, one machine; not repeated for variance) |
| C5 | xref reports zero edges for beams without `debug_info` | `p2b_xref_needs_debug_info.escript` / `.out` |
| C6 | Elixir stranger calling `@moduledoc false` fn: no diagnostic, runs | `p3_elixir_privacy.exs` / `.out` |
| C7 | `defp` is not remotely callable in Elixir | p3 |
| C8 | `@doc false` actually drops docs entries | UNPROBED (probe modules in memory had no docs chunk) |
| C9 | Segment-boundary prefix match is required; naive string prefix is wrong | `p4_subtree_check_prototype.escript` (mutant must disagree with oracle) |
| C10 | Per-edge check 0.28 s / 51,045 edges; per-site walk 3.8 s / 400,040 sites (upper bound, separate walk) | p4 `.out` |
| C11 | Marginal per-site cost inside the existing checker | NOT MEASURED |
| C12 | Beam size: +32 B module attr, +248 B for 10 per-fn entries; 8 µs read-back | `p5_beam_size_and_attr_read.escript` / `.out` |
| C13 | Runtime caller check is blind to tail callers; ~2.7x call cost via `process_info` | `p6_runtime_caller_check.escript` / `.out` (the 2.7x is measured inside an interpreted escript loop; indicative only) |
| C14 | Elision / one entry label per function; function must be exported to be nameable by siblings | INHERITED from ticket 18 §5, not re-executed |
| C15 | "No way to publish to your compiler but not to `erl`" | INHERITED from ticket 06, not re-executed (but consistent with C1) |
| C16 | `add_import/7` has `Self` and the module path in scope; `private_callee/3` serves both call-site refusals | read at `bs_check.erl:494-509`, `:3850`, `:4391`, `:4470` |
| C17 | World entry fields (`exports`, `private`, ...) built at `bsc.erl:227-239`; `private_of/1` at `bs_check.erl:475-479` | read |
| C18 | F12's five readers test `=:= public` so a new value defaults closed | INHERITED from `F12-public-and-private.md` amendment, not re-executed |
| C19 | Qualified calls are legal only where reachable via `using` | INHERITED from ticket 41 §5 / `examples/Shop/Billing/Billing.bs` comment; not executed (no `bsc`) |
| C20 | 24 §2 predates F12's private-by-default (2026-08-13 vs 2026-08-17) | dates in the two files |
| C21 | `unclassified` boundary category never built; only an unrelated diagnostic tag exists | `grep` of `compiler/src` |
| C22 | Rust `pub(in path)`, Scala `private[pkg]`, Java `exports ... to`, C# `internal`/`InternalsVisibleTo`, Gleam `@internal`, Elm `exposed-modules` semantics | UNPROBED (cited from each language's reference; none installed) |
| C23 | xref being skipped in builds as the precedent that tools outside the compiler get dropped | INHERITED from ticket 21 via ticket 22, not re-executed |

## 6. Limitations

- No B# was compiled. The compiler deltas are sized from reading `bs_check.erl` / `bsc.erl` /
  F12 / F15, and the cost numbers are from an Erlang prototype of the checks over generated trees
  (random seeded edges, 40 identical-shape calls per module), not from the real checker or a real
  corpus. Real `using` fan-out is probably lower than 5 edges per module.
- Timings are single runs on one machine and are for ordering, not absolute budgets.
- Spellings (`public(in Shop)`, `within`, `uses only`) are placeholders, not proposals to bike-shed.
- I did not check how tests are named relative to the module they test, which decides whether a
  test module sits inside a restricted subtree. If tests live under the module they test, Option A
  hands them the helper and the `unclassified` concern from 24 is not closed; if outside, it is.
  This is a one-grep fact that needs 24's test-layout answer.

---

## Decision left open for human review

1. **Gating question:** is the declaration the callee's or the caller's? (Brief recommends callee.)
2. If callee: **function-level (A) or module-level (B)?** Do sibling-only helpers exist in the
   exemplar corpus today, or is A speculative?
3. **Spelling.** Whether to borrow neither `internal` nor `friend`, and what `P` must be (ancestor of
   the declaring module, as proposed, or any path).
4. **Whether `--api` lenient mode reports the refusal.**
5. **Test layout** (limitation above): are tests inside or outside the subtree of the module they test?

Nothing here has been resolved, committed, or written to Linear.
