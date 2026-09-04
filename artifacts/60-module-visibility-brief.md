# Decision brief: Which modules may name this one? (ticket #60, ENG-242)

## Sub-decisions

Extracted from the ticket's "What has to be decided" section, unchanged in substance:

1. **What is the unit** a friend grant is scoped to — a directory subtree (path-scoped, Rust's
   answer), an explicit named list of modules (C#'s `InternalsVisibleTo`'s answer, scoped to one
   assembly-sized unit at a time), or something else.
2. **Which direction the declaration points** — the callee naming who may call it, or the caller
   declaring what it depends on (which `using` already does, per ticket 40/41, and is a different
   question — importing is not a permission grant).
3. **Third visibility marker on the signature, or a separate construct** — `public`/`private` sit
   on a function; a rule about *modules* may belong at the module level instead (F15: the directory
   already is the module).
4. **What it costs the checker** — concretely, at `add_module_import`, in lines and new state.

## Evidence

### Sub-decision 1: what is the unit

- **Probe**: `artifacts/60-probes/rust_pub_in_path/` — claim: "Rust's `pub(in path)` scopes
  visibility to a module **path**, not to a named list of callers and not to the whole crate."
  Command: `cargo build` (clean, `rm -rf target` first)
  Output (`build_output_1_blocked_from_outside.txt`), both a crate-root caller and a **sibling**
  module in the same crate (`billing`, not under `orders`) refused:
  ```
  error[E0603]: function `recompute_total` is private
   --> src/billing/mod.rs:5:30
    |
  5 |     crate::orders::internal::recompute_total();
    |                              ^^^^^^^^^^^^^^^ private function
    |
  note: the function `recompute_total` is defined here
   --> src/orders/internal.rs:3:1
    |
  3 | pub(in crate::orders) fn recompute_total() {
  ```
  Then the positive control — a caller *inside* `crate::orders` (`orders/mod.rs`, a sibling file in
  the same subtree, swapped in over `main.rs`/`billing/mod.rs`) — compiles and runs
  (`build_output_2_allowed_from_inside_path.txt`, `run_output_2.txt`: prints `recomputed`). The
  refusal is provably about *path membership*, not about being a different file or a different
  crate: `billing` is refused despite being in the *same crate* as `orders`, and `orders/mod.rs` is
  allowed despite being a *different file* from `orders/internal.rs`.
- **Survey**: C# `internal` — assembly-scoped, one unit per **assembly** (a compiled output, not a
  source path): "You can access internal types or members only within files in the same assembly"
  (`artifacts/60-probes/csharp_docs/csharp_internal_doc.md`, fetched from
  `dotnet/docs@main:docs/csharp/language-reference/keywords/internal.md`, real HTTP 200 — **not
  executed locally**, no `dotnet`/`csc` on this machine; `which dotnet csc` returns nothing).
  Confirms ticket 22's own false-friend warning: beam-sharp has no assembly, so `internal`'s unit
  does not exist here at all — there is nothing narrower than "the whole compiled program" for it
  to mean.
- **Survey**: C# `[InternalsVisibleTo("Foo")]` — also assembly-scoped, but the callee names a unit
  **by identifier**, not by path: "The attribute is applied at the assembly level... You can use
  the attribute to specify a single friend assembly" and enumerating more than one friend takes
  repeated attributes, one per named assembly
  (`artifacts/60-probes/csharp_docs/csharp_internalsvisibleto_api_doc.xml`, fetched from
  `dotnet/dotnet-api-docs@main`, real HTTP 200, **not executed locally**, same caveat). This is
  C#'s closest real precedent to ticket 60's question, and its unit is "a named list of one
  compiled thing per grant" — no path is involved anywhere in `InternalsVisibleTo`.
- **Survey**: Gleam's `internal_modules` — path-*glob*-scoped (`compiler-core/src/config.rs`,
  `artifacts/60-probes/gleam_source_citations/compiler-core_src_config.rs:202-218`, real source,
  own test asserts `is_internal_module("my_package/internal/wibble/wobble")` is true under the
  default glob `<package>/internal`, `<package>/internal/*`), so the SHAPE of the unit is
  path-like, same idea as Rust's — but the boundary it draws is at the **whole package**, and
  (measured, `artifacts/60-probes/gleam_internal_probe/`) it doesn't function as a compile-time
  caller check at all: a **path** dependency from a separate package still compiles a call into an
  `@internal` function with zero error (`billing_pkg/build_output_2_at_internal_attribute_still_not_blocked_via_path_dep.txt`).
  So Gleam contributes evidence on *shape* (paths, like Rust) but not on *enforcement* — see
  sub-decision 2's evidence for why.
- **Measurement**: `compiler/src/bs_check.erl` — `add_module_import/3` (current file at `1a86b0b`,
  lines 468-477; the ticket's citation, `bs_check.erl:407-425` and arity `/5` at `0b761f6`, has
  drifted on both counts, confirmed by reading the live file) already reads `World`'s per-module
  map keyed by `{exports, private, behaviours}` (`bsc.erl:249`). F15 already makes a directory a
  module, so "the unit is a module" costs nothing new to *represent* — the only remaining question
  is whether a friend grant lists modules by name (cheap: `lists:member/2`) or by path prefix
  (equally cheap: a prefix match over the dotted atom, same complexity class, proven not to be free
  of edge cases by Gleam's own glob-vs-literal-separator subtlety measured in the same probe).

### Sub-decision 2: which direction the declaration points

- **Survey**: every real precedent that narrows *below* public has the **callee** name its
  friends. C#'s `[InternalsVisibleTo("Foo")]` sits in the callee's own assembly and names the
  caller assembly by string. Rust's `pub(in crate::orders)` sits on the callee item and names the
  scope it trusts, from the callee's own perspective (`src/orders.rs`, `pub(in crate::orders) fn
  recompute_total()`) — the caller (`billing`) writes nothing granting itself access; it has no
  way to. Gleam's `internal_modules`/`@internal` (whatever it actually gates — see above) is
  likewise written where the definition lives, never at the call site.
- **Structural argument, not just survey**: a caller-declares-dependency spelling already exists —
  `using` (ticket 40 §1, 41 §2/§5) — and answers a different question ("what do I need in scope"),
  not "who may call me." If the *caller* could also grant itself elevated access by writing
  something in its own file, the check would be provable only by reading every caller in the
  program, which is exactly the whole-aggregate blast-radius ticket 18 §5's function-local
  standing constraint was written to avoid. A callee-side grant is checkable by reading one file:
  the callee's own directory.
- **Consequence for the checker (measured)**: `add_import(L, M, Self, World, Known, Acc)`
  (`bs_check.erl:450`) *already* carries `Self` — the caller's own module atom — one call frame
  above `add_module_import`. The direction the survey and the structural argument both point to
  (callee names friends) is also the direction that costs nothing extra to wire, because the
  caller's identity was already in scope for exactly this reason (F15/41's existing dependency
  resolution). A caller-declares-itself-trusted design would need to invent a NEW way to assert an
  identity claim and have the callee's side verify it — strictly more machinery, not less.

### Sub-decision 3: third visibility marker, or separate construct

- **Prototype**: `artifacts/60-probes/friend-check-prototype/` builds it as a directory-level
  declaration, `friend Shop.Billing`, parsed the same way `using` is
  (`bs_parser.yrl`: `friend_decl -> 'friend' modpath : {friend, line('$1'), modatom('$2')}.`, one
  line beside `using_decl`), not as a marker on `signature`. It sits in `index.bs` (or any file in
  the module's directory — F15 checks the whole directory as one declaration pass, `bs_check.erl`
  comment at `check_dir/3`), once per friend, not once per function.
- **Why not the signature**: ticket 18 §5's own measurement, cited by this ticket, is that
  per-function export control is not cheap on the BEAM — one entry label per function, elision is
  exported-vs-local only. A friend list on *every* `public` signature in a module would repeat the
  same list once per function for no representational gain, since the boundary this ticket is
  drawing is "who may call into this module," a directory-shaped fact, not a function-shaped one.
  None of the three real "narrower than public" precedents surveyed (C#'s two forms, Rust's three
  `pub(...)` variants) attach the grant to an individual member either — C#'s is assembly-level,
  Rust's is on the item but names a *module path*, never a caller-by-caller list per member.

### Sub-decision 4: what it costs the checker

- **Probe**: `artifacts/60-probes/friend-check-prototype/` — claim: "the whole `friend`
  mechanism, as a named-list grant checked once per `using` line, costs on the order of 30 lines
  across the files ticket 60 would touch, is backward compatible with every existing `.bs` file,
  and does NOT (as built) cover the namespace-tier import path."
  A full copy of `compiler/src/` at `1a86b0b`, patched, rebuilt with the project's own `rebar3
  escriptize` (`warnings_as_errors` on, unmodified), run against a copy of the real
  `examples/Shop` tree.
  Real diff, line-counted (`diff/*.diff`, blank/comment lines excluded): **29 lines across 5
  files** — 1 lexer line, 4 parser lines, 15 checker lines (`friends_of/1`, threading `Self`/`L`
  one parameter further into `add_module_import`, the membership check), 1 line in `bsc.erl`'s
  `World1` map literal, 7 lines in `bs_diag.erl` for the new diagnostic.
  Command: `./_build/default/bin/bsc --src-root examples_probe examples_probe/Shop/Reports Restate 3`
  Three real outputs:
  ```
  # (1) No `friend` line anywhere — today's behaviour, unchanged:
  9

  # (2) Ints.bs writes `friend Shop.Billing` only (Shop.Reports excluded):
  examples_probe/Shop/Reports/Totals.bs:15: error: `using Shop.Collections.Ints` is refused — Shop.Collections.Ints does not name Shop.Reports as a friend
    Shop.Collections.Ints only takes calls from a module it names with `friend Shop.Reports`

  # (3) Ints.bs adds `friend Shop.Reports` — same call, same output as (1):
  9
  ```
  (`friend_probe_output_1_blocked.txt`, `friend_probe_output_2_allowed.txt`)
  **Zero existing `.bs` files need to change** — `grep -rn '\bfriend\b' examples --include='*.bs'`
  is 0 hits today, so `friends_of/1` returns the sentinel `open` (no restriction) for every module
  in the repo unless it opts in, the same backward-compatibility shape ticket 40 §3 measured for
  `public`/`private` before F12 shipped (that one *did* need all 29 `.bs` files rewritten, because
  the marker was briefly mandatory; this one never is).
- **Real gap found, not estimated**: `add_namespace_import/3` (ticket 41 §5's other import tier)
  is untouched by the patch. Measured in `namespace_bypass_check/`: the same excluded caller
  (`Shop.Reports`, with `Ints.bs` writing `friend Shop.Billing` only) reaches the *same* function
  through `using Shop.Collections` (namespace tier) instead of `using Shop.Collections.Ints`
  (module tier) and is **not** refused:
  ```
  $ ./_build/default/bin/bsc --src-root namespace_bypass_check namespace_bypass_check/Shop/Reports Counted 3
  2
  ```
  (`namespace_bypass_output.txt`). A real implementation needs the same check taught to both
  import tiers — call it roughly double the measured 29 lines, though the second half was not
  built or measured here, only shown to be necessary.

## Options

### Option A: named friend list, callee-side, module-level declaration — what was built and measured

```csharp
// examples/Shop/Collections/Ints/Ints.bs
module Shop.Collections.Ints

friend Shop.Reports
friend Shop.Billing

public int Length(list<int> xs)
Length(xs) -> Length(xs, 0)
```

A caller not named — say a new `Shop.Analytics` module an agent writes to poke at internals for a
test — gets, at the `using` line:
```
Shop/Analytics/probe.bs:3: error: `using Shop.Collections.Ints` is refused — Shop.Collections.Ints does not name Shop.Analytics as a friend
  Shop.Collections.Ints only takes calls from a module it names with `friend Shop.Analytics`
```

- **Evidence for**: this is the shape actually built, measured at 29 lines, backward compatible by
  construction (no `.bs` file changes unless a module opts in), and matches C#
  `[InternalsVisibleTo]`'s direction and unit exactly (named list, callee-side) — the closest real
  precedent surveyed to what ticket 60 is asking.
- **Strongest counterargument**: an explicit list must be maintained by hand as the friend set
  grows or shifts — ticket 24 §2's `RecomputeTotal`-shaped helper, if it wants "every module inside
  the `Orders` aggregate," needs one `friend` line per current AND future sibling module, where a
  path scope would need none.

### Option B: path-scoped grant, Rust's shape

```csharp
// examples/Shop/Orders/order.bs
module Shop.Orders

friend in Shop.Orders   // anything under this path, present or future

private int RecomputeTotal(Order o)
RecomputeTotal(o) -> ...
```

- **Evidence for**: Rust's `pub(in path)` is the strongest real precedent surveyed (central
  evidence above) and F15 already makes a directory subtree the natural, cheap unit — ticket 60's
  own text names this "the cheap answer and may be the right one." A path scope also does not need
  updating every time a new module is added under an already-trusted subtree, which the demoed
  `Shop.Orders` aggregate case (ticket 60's own motivating `RecomputeTotal` example) is shaped
  exactly for: whatever else lives under `Shop.Orders` should probably see it, permanently, without
  a maintained list.
- **Strongest counterargument**: it is a strictly *coarser* grant than Option A when a module wants
  to trust one specific outside caller rather than "everything in my own subtree" — which is
  already true today with no mechanism at all, since intra-directory calls are unrestricted (F15).
  A path scope answers "who else besides myself" only by drawing a bigger circle around myself, not
  by naming a specific outside friend the way ticket 60's title ("which modules may name this one")
  most literally asks. It is also a materially different check to implement — a prefix match on
  the dotted module path rather than list membership — not built or measured in this run's
  prototype, so its cost is estimated by analogy (same call site, same shape of check) rather than
  measured.

### Option C: no compiler mechanism — convention and tooling only

- **What it looks like**: nothing new in the grammar or checker. A directory naming convention
  (e.g. `_internal/` the way Gleam's *default* glob already reads `internal/` specially) plus a
  lint script under `bin/`, matching this project's existing `check-*.sh` gate pattern, that greps
  `using` lines against a hand-maintained allow-list — the same shape as Elixir's ecosystem answer.
- **Evidence for**: this is what Elixir actually does — `defp` (module-binary, measured: a
  cross-module call is a **warning** at compile time and an `UndefinedFunctionError` at run time,
  not a refusal — `artifacts/60-probes/elixir_visibility/`) is the only compiler-level word, and
  anything narrower (Phoenix contexts, the `Boundary` Hex package) is a separate static-analysis
  tool, not part of `elixir`/`erlc`. This is a fifth, real data point: on the BEAM today, "which
  modules may call this one" is a **tooling** answer everywhere it exists at all, never a compiler
  answer — until Gleam's `internal_modules`, which (measured) does not actually enforce a call
  boundary against source either.
- **Strongest counterargument**: ticket 21's own standing finding, which this project has already
  relied on repeatedly (22, 24) — "an attribute [or convention] is worth something only if the
  beam-sharp compiler reads it... checked by a separate analyser is Code Contracts again, and Code
  Contracts is archived." Ticket 60's own motivating case is agent authorship drift (an agent
  targets `unclassified` helpers because they're the easiest thing to test) — a lint a human must
  remember to run is precisely the enforcement shape ticket 21 found does not survive contact with
  an unsupervised author.

## Recommendation

Option A (named friend list, callee-side, on a module-level `friend` declaration) is the
concrete, measured, backward-compatible answer, and it directly answers all four sub-decisions the
same way the survey does: the unit is the module (F15's cheap answer), the callee names its
friends (the only direction any real precedent uses, and the only one that doesn't need new
machinery beyond what `add_import` already threads), it is a separate module-level construct
rather than a third signature marker (matching ticket 18 §5's per-function cost finding), and its
cost is a real, small, measured 29-line patch with zero migration cost for the 130 `.bs` files that
exist today. Its one real weakness — hand-maintaining a list for a subtree-shaped friend group, and
the namespace-tier bypass this run found and did not close — argues for treating Option B's
path-scoped spelling as a **second, later form of the same construct** (`friend Mod` for a single
name, `friend in Path` for a subtree) rather than a competing design, once a real exemplar shows
the subtree shape is common enough to want; the grammar and World-threading changes needed to add
it are the same shape and the same call site, not a rearchitecture. Option C should be rejected on
this project's own precedent (ticket 21) unless David judges the ticket's own "not owed a decision
soon" framing to mean the guardrail case is not worth building at all right now — which is a
question about timing, not about which mechanism is best.

## Verification

**No Agent/Task tool for spawning a subagent was available in this run's toolset** (checked via
tool search for `Task`/`Agent`/`SpawnAgent`/`SubAgent` — none matched; this session's own system
prompt confirms it is itself the leaf worker for this ticket and should not "re-delegate the entire
assignment to another single subagent," which a verifier spawn is not, but no such tool existed to
call regardless). Rather than skip the verification step or fabricate a subagent's report, I ran
the independent re-verification pass myself, from clean state, treating my own draft brief the same
way a separate verifier's instructions describe: re-run don't re-read, and diff the reproduction
against the stored output rather than eyeballing it.

**What was independently re-checked, after the brief above was already drafted:**
- `rust_pub_in_path`: `rm -rf target`, rebuilt both variants fresh. The two-caller refusal
  (`E0603` at both `main.rs` and `billing/mod.rs`) and the positive control (prints `recomputed`)
  both reproduced verbatim; the checked-in tree was restored to the blocked variant afterward.
- `friend-check-prototype`: `rm -rf _build`, ran `rebar3 escriptize` fresh (still
  `warnings_as_errors`, unmodified) — clean build reproduced. Re-ran the "no friend line" (open),
  the blocked, the allowed, and the namespace-tier-bypass scenarios by diffing live output against
  each stored `.txt` file (`diff <(bsc ...) friend_probe_output_1_blocked.txt`, etc.) — all four
  matched byte-for-byte. **This caught a real mistake of my own**: my first attempt at
  independently re-deriving the "blocked" scenario reused a copy of `Ints.bs` that (from earlier
  work building the *allowed* scenario) already had both `friend Shop.Billing` and `friend
  Shop.Reports` written, so it printed `9` instead of the expected refusal — not a flaw in the
  mechanism, a stale fixture in my own check. Rebuilding the file with only `friend Shop.Billing`
  and rerunning produced the correct refusal, matching the stored output exactly; this is recorded
  here rather than silently fixed, per the ticket's own norm of correcting a citation in place
  rather than quietly redoing it.
- Independently re-derived the line count from a fresh `diff -u` against
  `/home/user/beam-sharp/compiler/src/` (not by re-reading `diff/*.diff`) — reproduced **29**
  total, but the per-file split came out 15/7 for `bs_check.erl`/`bs_diag.erl` where the brief's
  first draft said 16/8 (an off-by-one in which comment line got filtered, in opposite directions
  that canceled in the total). Both files' tables are corrected to 15/7 above.
- Re-ran the Elixir probe (`elixirc` + `elixir -e`) from scratch — the warning and the runtime
  `UndefinedFunctionError` both reproduced verbatim.
- Re-ran `gleam build` in both the single-package probe and the two-package (`path` dependency)
  probe, the latter with `@internal` still present on `recompute_total` — the "Unknown module
  value" refusal and the path-dependency non-refusal both reproduced verbatim.

**What this pass could not do that a genuinely separate verifier would add**: catch a blind spot in
my own reasoning that a second, fresh reader would see immediately (the stale-fixture mistake above
is the shape of error self-review is worst at, and it happened once already). The C#
citations are flagged not-locally-executed everywhere they appear (checked by grep over this file
for every C# claim); the Gleam `internal_modules` reading was checked line-by-line against the
fetched source before writing sub-decision 1 rather than after, so there was no separate pass
looking for daylight between the claim and the source it cites. Both are weaker guarantees than an
independent second party would give, and are named here rather than silently assumed.
