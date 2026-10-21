# Decision brief: ticket 60, which modules may name this one

Linear: ENG-242. Repo ticket: `wayfinder/issues/60-which-modules-may-name-this-one.md`.
Status after this brief: **still open**. The ticket itself says "not owed a decision soon". This brief makes the cost of deciding it concrete, and says what I could not measure.

Probes: `artifacts/probes/p60_internal.sh`, `p60_neighbours.sh`, `src60/`. Prototype: `patches/60a-internal-marker.patch`.
Toolchain: OTP 28, Elixir 1.20.4, Gleam 1.19.1. C# and Elm were not available to run (no `dotnet`; Elm's registry is blocked), so nothing here is measured about either.

## The one question

What is the unit that "who may name this" is written in? The ticket lists a directory subtree, a named group and an explicit list. The other three questions (direction, marker or separate construct, checker cost) depend on it. I asked only this one, and I built only the subtree.

## What I measured

**Where the check would go.** `bs_check.erl` `import_env/4` builds the qualified-call table from the whole world with no regard to the caller (`qual_table(World)`), and `add_module_import/3` reads only the callee's export set. `Self`, the calling module's name, is already an argument of `import_env/4`. So a "who" rule needs no new plumbing to find the caller. It needs the callee's entry in the world to carry a scope, and `import_env` to drop what the caller may not name. That is what the prototype does.

**Prototype 60a: `internal` as a third visibility marker, scope is the callee module's first name segment.** about 34 changed lines over five files (lexer 1, parser 3, `bs_check.erl` 27, `bsc.erl` 1, `bs_emit.erl` 2; the verifier counts 34 without blank lines and 38 with them). The probe:

```csharp
module Shop.Orders
public int Place(int qty)
Place(q) -> RecomputeTotal(q)
internal int RecomputeTotal(int q)
RecomputeTotal(q) -> q * 100
```

`Shop.Billing` calls `Orders.RecomputeTotal(q)`: accepted. `Other` (outside `Shop`) calls it: refused. Control: the unmodified compiler refuses the file at `internal` with a syntax error, so the accept is the patch's doing (`p60_internal.sh base`, then `v60a`).

Three things the prototype showed that the ticket did not say:

1. **The enforcement is compile-time only.** For `internal` to be callable from `Shop.Billing`, the emitter has to export it, and an export is open to everyone. `Shop.Orders:RecomputeTotal(3)` called from plain Erlang returns `300`. This is what 18 §5 predicted ("a compile-time check on the caller, or it is nothing"), now measured.
2. **The refusal text is wrong for `internal`.** I reused the `private_function` diagnostic and it prints "which Shop.Orders declares `private`". A real build needs its own message.
3. **`internal` becomes a reserved word.** No `.bs` file in the repo uses it as an identifier, and the 22 example modules compile to the same guards (82) before and after, but any user program with a variable called `internal` breaks.

**What the neighbours do** (`p60_neighbours.sh`, run, not recalled):

- Gleam 1.19.1 has `internal_modules` in `gleam.toml`. I made a package `lib` with `internal_modules = ["lib/internal", "lib/internal/*"]` and a second package `app` that depends on it by path and imports `lib/internal/helper`. It built with no warning, exit 0, and `app:main()` returned `42`. So on this version the setting did not stop the import. It may drive docs and editor completion; I did not test those.
- Elixir 1.20.4: a module with `@moduledoc false` and a function with `@doc false` was called from another module with no warning, result `42`.
- Erlang has no equivalent; `-export` is all-or-nothing, which is the BEAM fact 18 §5 already cites.
- C#'s `internal` is assembly-scoped (from ticket 22, not measured here).

No neighbour I could run enforces a "who" rule at compile time.

## The three programs

**A. `internal` on the signature, scope is a name prefix** (what I built). Source above. Compiler work: the ~34 lines, plus a real diagnostic, plus a decision on which prefix (first segment, parent namespace, or the callee's own namespace).
Strongest counterargument: it enforces nothing at run time, and the only prior art I could run (Gleam) does not enforce it at compile time either, so there is no evidence from a working neighbour that a hard rule is wanted. (The verifier found Gleam does treat the marker differently in two places: `gleam docs build` omits the internal module, and `gleam export package-interface` lists only `lib`. It enforces nothing at compile time. A function marked `@internal` also builds and runs from another package.) The prefix choice is also arbitrary for trees deeper than two levels: the verifier confirmed the scope is the callee's first segment, so a three-segment module cannot restrict callers to its own parent namespace. Matching is on whole segments (`ShopX.Billing` is refused).

**B. The callee lists its callers, or the caller lists its dependencies.**

```csharp
module Shop.Orders
friends Shop.Billing, Shop.Reports
```

Not built. The check site is the same one A uses; only the data in the world entry changes, from a prefix to a list. It also answers the ticket's direction question differently: a caller-side `uses` list would be closer to what `using` already is.
Strongest counterargument: lists rot. F15 makes a directory a module, so a rename of a module silently invalidates every `friends` line that names it, and the compiler then has to decide whether an unmatched name is an error.

**C. No new rule. Solve the consumer's problem a different way.** The ticket's one named consumer is the test-writing agent that lands on `unclassified` functions (ticket 24 §2). That problem is "which functions are targets", not "who may call". It could be a diagnostic on a public function that is neither a callback nor client API, no marker at all.
Strongest counterargument: it leaves the *who* half of ticket 22's split unbuilt, and the ticket exists because 22 said the half was probably worth having.

## Recommendation

Do not build A yet. The prototype shows the checker work is small (the caller is already in hand at `import_env`) and the unit question is the whole cost, so deciding the unit costs nothing to defer. Ask the unit question alone when the test-agent consumer actually fails on a missing marker. If asked to pick today, A with the scope fixed to the callee module's parent namespace, because a directory is a module and the parent directory is the natural neighbour. I would not accept A without its own diagnostic text and without stating in the spec that it is a compile-time courtesy.

## Limits

- One prototype, one unit. B and C are described, not built.
- I did not measure how many public functions in the corpus would become `internal`; that needs a call graph I did not build.
- The verifier confirmed the enforcement is real and not an accident of `using Shop`: a module differing only in name (`Zed.Billing`) is refused, `Shop.Deep.Inner` is accepted, `Zed.Deep.Inner` is refused (`verification/60-extra.sh`). Under base, Billing and Other fail only because `using Shop` finds no `Orders`, so they are not independent controls; the syntax error on Orders is the real control.
- The prototype was not run through the full test suite (5 files changed including the lexer). It was run over the 22 example modules only.
