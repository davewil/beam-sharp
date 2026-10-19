# Brief — ticket 60 (ENG-242): which modules may name this one?

Status of the ticket: **open, left open.** The ticket itself says "not owed a decision soon".

## Sub-decisions (the ticket's four, with the gating one first)
1. **What is the unit?** (gates the rest) a subtree of dotted module names, an explicit list, or nothing.
2. Which side declares it: the callee ("only these may call me") or the caller?
3. A third visibility marker on the signature, or a separate construct?
4. What does it cost the checker?

## The program the decision turns on

```csharp
module Shop.Orders                          // Shop/Orders/ on disk

public Order Place(Cart c)                  // part of Shop.Orders' API
internal int RecomputeTotal(Order o)        // proposed marker; spelling not decided here
```
```csharp
module Shop.Reports
using Shop.Orders
Summary(o) -> RecomputeTotal(o)             // sibling: compiles or refused?

module Shop.Orders.Tests
using Shop.Orders
Check(o) -> RecomputeTotal(o)               // descendant: compiles or refused?

module Billing
using Shop.Orders
Pay(o) -> RecomputeTotal(o)                 // unrelated root: refused under every option below
```
Under option A the first two compile (same parent namespace `Shop`) and the third is refused; under B only the callers
the callee lists compile. Today all three compile, because `RecomputeTotal` must be `public` to be reachable from a test.

## Measurements

**Nothing a neighbour ships enforces "who".** Both implemented mechanisms are documentation-only:
- **Gleam 1.12.0** (`probes/60/gl/`): `internal_modules = ["lib/internal", "lib/internal/*"]` in the library's `gleam.toml`
  and an `@internal` item. A second package importing `lib/internal/secret` and calling both the plain and the `@internal`
  function builds with **rc=0 and no warning**. The one effect is on generated docs: `package-interface.json` lists only
  module `lib`; the internal module is absent.
- **Elixir 1.14.0** (`probes/60/probe_elixir.sh`): a `@moduledoc false` / `@doc false` function is **called successfully**
  (`42`); the docs chunk reads `:hidden`. Docs only.
- **Erlang**: `-export` is the whole mechanism; the language has no caller-scoped form. (Not probed; stated from the
  language, and OTP 28's `xref` can *report* but not *refuse*.)
- **Elm**: not measured (package host unreachable); `exposed-modules` in a package's `elm.json` is the mechanism it uses and was not run.

**B#'s own tree** (`compiler/src/bs_check.erl`, HEAD `019533d`; the ticket's cited lines `407-425` have moved):
- `add_module_import/3` at `:512` reads `exports` and nothing else.
- A dotted-prefix test over module names already exists: `children/2` at `:590-592`
  (`lists:prefix(atom_to_list(Prefix) ++ ".", atom_to_list(M))`). It answers "is X under Y" today, with no new data.
- Privacy is checked at a second site: `private_callee/3` at `:4332` reads the `privates` table built at `:557`.
  A qualified call (`Shop.Orders.RecomputeTotal(o)`) reaches `qual_table/1` at `:538` without an import, so **the check
  has to sit at the call site, not only at `using`**.
- The emitter needs nothing: ticket 18 §5 (cited in the ticket) says one entry label per function and `internal` would be
  compile-time only. Run-time cost: 0.

**What the corpus can say** (`probes/60/corpus_edges.py`): 115 B# modules, **7** B#-to-B# `using` edges: 4 between unrelated
roots (`Jev <-> Support.Triage`), 2 sibling/cousin (`Shop.Reports -> Shop.Collections[.Ints]`), 1 to an ancestor
(`Shop.Billing -> Shop`), **0 into the caller's own subtree**. That is too few edges to choose a unit by evidence. It does
say a "descendants only" unit would have refused both sibling edges had those callees been marked.

## Options

**A. Callee-declared, unit = the declaring module's parent namespace** (`internal` on a signature).
- Evidence: reuses `children/2`; no new World data beyond the marker; run-time 0; matches F15's directory-as-module.
- Strongest counterargument: it reads like C#'s `internal` and means something else, which the ticket's own false-friend rule
  forbids borrowing (C# `internal` = assembly; B# has none). A new spelling, or a name that does not collide with that
  meaning, is required. Also the unit is a guess: the corpus has 0 downward edges and 2 sibling edges.

**B. Callee-declared explicit list** (`visible_to Shop.Reports, Shop.Billing`).
- Evidence: unambiguous about intent; needs a new World field and a check at `:512`, `:4332` and the qualified call.
- Strongest counterargument: it points the wrong way for how `using` works (the caller names what it depends on), so every
  new caller edits the callee; the test-writing agent that motivates the ticket would need the list kept current.

**C. Build nothing; the unclassified helper stays `public` and ticket 24's classification absorbs it.**
- Evidence: no neighbour enforces this either (Gleam, Elixir above), so C is the field's norm; zero compiler change.
- Strongest counterargument: it leaves the one consumer the ticket names unserved. An agent "writing tests in a loop"
  still sees `RecomputeTotal/1` as an exported function and targets it.

## Recommendation
**A, but decide the unit by reading the two programs above, not this brief.** It is the only option with an existing
primitive (`children/2`) and no new data; Gleam and Elixir show the field has shipped the *documentation* half and stopped,
so B# would be first to enforce it, which is a reason to keep the first version smallest. Pick the spelling last: it must
not be `internal`. Do not decide before the corpus has a downward edge, or the sibling rule is a guess.

## Not measured
Check timing in `bsc` (the prefix test is O(known modules) per import; not timed); Elm; whether a qualified call through a
namespace alias also needs the check (the `:538` path was read, not exercised).
