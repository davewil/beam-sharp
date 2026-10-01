# Decision brief — ticket 60 (ENG-242): which modules may name this one?

Prepared 2026-10-01 by a scheduled run. **Nothing is resolved.** The ticket says it is *"not owed a
decision soon"*; this brief makes the decision cheap to take when it is owed. Probes and the prototype
patch are under `artifacts/probes/60/`. `bsc` from HEAD `0dddf8b`, OTP 27.3.4; Gleam 1.18.1; Go 1.24.7.
Elm is not measured (cannot build a project offline); Elixir and Gleam have no installed sources, so
they are cited by behaviour.

## Sub-decisions (the ticket's four, in the order that gates)

1. **The unit**: a path subtree, a named group, an explicit list.
2. **Direction**: the callee says who may call it, or the caller says what it depends on.
3. **Spelling**: a third visibility marker, or something that is not on a signature.
4. **Checker cost**: the site is `add_import/7` (`bs_check.erl:490`), which already receives the
   importer (`Self`), the imported module (`M`) and the line (`L`); `add_module_import/3` (`:504`)
   reads only the callee's export set.

## Neighbour survey (every row run)

| language | mechanism | enforced by the compiler? | evidence |
|---|---|---|---|
| **Gleam** 1.18.1 | `internal_modules = [...]` in `gleam.toml`, `@internal` | **No.** A consumer package that imports an "internal" module compiles clean, exit 0, no warning. The setting only removes the module from `gleam export package-interface`. | `p1`, `p2`: the same `lib/hidden` module built twice, listed and not listed: interface `['lib']` vs `['lib','lib/hidden']`; consumer exit 0 in both. `@internal` on a function: consumer compiles exit 0. |
| **Elixir** 1.14 | `@moduledoc false` (convention), `defp` | No: `Lib.Internal.helper()` from another module compiles with no output. | `p1` (b) |
| **Erlang** | `-export` only | Per function, nothing per caller. | `p1` (c) |
| **Go** 1.24.7 | an `internal/` path element | **Yes, at compile time, by subtree**: the importer must sit under the *parent* of `internal`. | `p3`: `shop/pricing` and `shop/pricing/sub` build; `shop/reports` fails with `use of internal package ex.com/app/shop/pricing/internal/rates not allowed`, exit 1 |
| **Elm** | `exposed-modules` in a *package's* `elm.json` | not measured | |

So the one neighbour with a *word* for this, Gleam's `internal`, does not enforce it, which is the
ticket's own false-friend warning (§"What 22 established") made concrete: the name exists, the
who-may-name-this semantics do not. The only enforced precedent is Go's directory-subtree rule, and it
takes the **callee-side, path-derived** shape: the declaration is a path segment, no new syntax.

## Prototype (`variant_internal_segment.patch`: 2 files, +31 −2)

`internal_ok/3` and `internal_allowed/2` in `bs_check.erl` called from `add_import/7`; one diagnostic
(`internal_module`) in `bs_diag.erl`. Rule: a module whose path has an `Internal` segment may be named
only from a module whose path begins with that segment's parent. Four importers of
`Shop.Pricing.Internal.Rates` (`p4_internal_prototype.sh`, `prog/`):

| importer | HEAD (control) | prototype |
|---|---|---|
| `Shop.Pricing` (the parent) | compiles | compiles, `Charge :standard 2` returns `200` |
| `Shop.Pricing.Sub` (a descendant) | compiles | compiles |
| `Shop.Reports` (unrelated) | compiles | **`Shop.Pricing.Internal.Rates is internal to Shop.Pricing and cannot be named from Shop.Reports`** |
| `Shop.Vians`, via `using Shop.Pricing.Internal` (the namespace form) | compiles | refused, **but with the wrong sentence** |

Two findings from building it. **First, a namespace import is a bypass**: my first cut checked only the
module-tier `using`, and `using Shop.Pricing.Internal` plus `Rates.Rate(..)` walked straight past it;
closing it meant filtering `add_namespace_import`'s children. **Second, the diagnostic for that form is
poor**: the namespace import silently drops the child, so the user sees *"`Rates` is called but never
imported, add `using Rates`"*, which sends them back to the thing that is refused. A real
implementation owes a dedicated message there. Compile-time cost not measured: the check is
O(path segments) per `using`.

`rebar3 eunit` on this patch: see the appended note (run after the report was drafted).

## Options

**A. Path rule: an `Internal` segment (Go).** No new keyword, no signature change.
```csharp
module Shop.Pricing.Internal.Rates      // nameable only from Shop.Pricing and below
using Shop.Pricing.Internal.Rates       // from Shop.Reports: error
```
Compiler delta: the +31 lines above, plus the namespace-form diagnostic. *Strongest counterargument:*
the word `Internal` becomes reserved in module paths (ticket 65's policy question), the unit is fixed
at "parent subtree" so a sibling that *should* be allowed has to be moved, and it protects whole
modules, not functions.

**B. An explicit friend list on the callee.**
```csharp
module Shop.Pricing.Rates visible_to Shop.Pricing, Shop.Billing     // spelling hypothetical
```
Compiler delta (**estimated, not prototyped**): a new clause on the `module` line in `bs_parser.yrl`,
the list threaded into the `World` entry that `add_import` reads, one check there. *Strongest
counterargument:* a list of names goes stale when a module is renamed, and it is a fifth place a
module's identity is written; Go chose paths precisely to avoid that.

**C. Do nothing; keep `public`/`private` as the whole story.** Compiler delta: none. *Strongest
counterargument:* Gleam shows what "a convention nobody enforces" gives you (no one is stopped), and
the consumer the ticket cites (agents writing tests) is the kind of author that follows the
cheapest path.

## A mismatch the ticket should see

The ticket's waiting consumer is ticket 24 §2's `unclassified` remainder: a helper like
`RecomputeTotal/1` *within one module*. **None of A, B, or C classifies a function inside a module**;
all three are module-level, which is what the ticket's own section 3 asks ("may not belong on a
function at all"). If that consumer is the reason to build this, it needs a function-level answer,
not a who-may-name-this-module rule, and those are different tickets.

## Recommendation

**A, if and when David wants the module-level half; otherwise C.** A is the only enforced precedent,
needs no syntax, and I measured its shape working (31 lines) with one real trap (the namespace form).
Do not build it *for* the 24 §2 consumer: it does not reach it. Reserve `Internal` explicitly (ticket
65) when it lands.

## Caveats

- Prototype only; no B# test, no `LANGUAGE.md` text, per the task.
- Option B is estimated, not built. Elm unmeasured. OTP 27, not 28.

## Verification

See "Verifier result" appended below by the independent verifier run.
