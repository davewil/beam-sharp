# Ticket 60 (ENG-242): which modules may name this one?

**State: open. Nothing here resolves it.** Written 2026-10-25 from `artifacts/probes/60/`; the verifier's report is `artifacts/verification/ENG-242.md`. The ticket says it is "not owed a decision soon"; the brief does not argue otherwise.

## The question, asked alone

What is the unit that may name a module: **a subtree of the module namespace**, or **an explicit list of modules**? The ticket's other three questions (direction, marker versus construct, checker cost) are answered or cheap once the unit is chosen, as below.

## What the probes established

Today (`p60_who.sh`, unpatched compiler, tree `Shop.Pricing` / `Shop.Reports` / `Other`):

| caller | `Recompute` is `public` | `Recompute` is `private` |
|---|---|---|
| `Shop.Reports`, `using Shop.Pricing`, unqualified call | compiles | refused, F12 message |
| `Other`, `using Shop.Pricing`, unqualified call | **compiles** | refused |
| `Other2`, qualified call `Shop.Pricing.Recompute(n)`, **no** `using` | refused: `Shop.Pricing is called but never imported` | same |
| `Other3`, `using` plus the qualified call | **compiles** | refused |

Two facts the ticket did not have:

1. **A qualified call cannot bypass `using`**, so there is one choke point, not two. The ticket cites `add_module_import/5` at `bs_check.erl:407-425`; the function is `add_module_import/3` at `bs_check.erl:512` now, and the place that sees both the importer and the callee's exports is `import_env/4` (`bs_check.erl:489`), which builds `qual_table` and `private_table` for every import.
2. **The machinery for "known but not callable by you" already exists.** F12's `private` refusal (`private_callee/3`, `bs_check.erl:4481`) is exactly the shape an access rule needs; only the question "private to whom" is new.

## Options

### 1. An `internal` marker; the unit is the subtree under the declarer's parent namespace

```csharp
module Shop.Pricing

public int Total(int n)
Total(n) -> Recompute(n) + 1

internal int Recompute(int n)        // callable from Shop.*, refused elsewhere
Recompute(n) -> n * 2
```

Rule as prototyped: the root is the declarer's parent (`Shop` for `Shop.Pricing`; the module itself if it has no parent); a caller is inside if its name is the root or starts with `Root.`.

Compiler delta (patch `v60-P`, 34 changed lines over 5 files):
- `bs_lexer.xrl` one token; `bs_parser.yrl` the terminal and `visibility -> 'internal'`.
- `bs_check.erl`: `exports_of/3` exports `internal` signatures; a new `internal_of/1` beside `private_of/1` (`:477`); `restrict/2`, about 15 lines, called first in `import_env/4`, which moves a module's internals from `exports` to `private` for every importer outside the subtree.
- `bsc.erl:239` carries `internal => ...` in the World entry beside `private`.
- `bs_emit.erl:141` `is_public/1` must treat `internal` as exported (the BEAM has no finer discriminator; ticket 18 §5).

Measured:

| caller | with `internal` |
|---|---|
| `Shop.Reports` | compiles |
| `Other` (unqualified) | refused |
| `Other3` (`using` + qualified) | refused |

`compiler/test`: 1494 passed, 4 failed, the unpatched baseline. Checker cost (`p60_scale.sh`, chain of N modules each using the previous one): 592 / 1113 / 2406 ms unpatched against 558 / 1157 / 2476 ms patched at N = 50 / 200 / 400, so about +3% at 400, inside the noise; `restrict/2` walks the World on each of the four `import_env` calls per module and the unpatched time itself roughly doubles per doubling of N. Caveat from the verifier: every function in that chain is `public`, so `restrict/2` takes its cheap clause; the branch that does `maps:without` was not run at scale.

**What the prototype gets wrong, and what it does not do:**
- The refusal reuses the `private` text, whose advice is `Mark it public in Shop.Pricing`. That is the wrong advice for an internal function; a message of its own is part of the work.
- `bs_api.erl:152,158` list only `public` operations, so `bsc --api` would not show internals. Not touched.
- Enforcement is compile-time only. `Recompute` is exported from the `.beam`, so Erlang or Elixir code can call it, as it can call any B# export today.

**Strongest counterargument.** The word. Ticket 22 says not to borrow `internal` without its semantics, and C#'s `internal` is assembly-scoped; this is name-prefix-scoped. A reader who knows C# will expect something else. Separately, the rule reads module *names*, so renaming `Shop.Pricing` to `Pricing` silently changes who may call `Recompute`; nothing flags it until an importer breaks.

### 2. An explicit list of callers on the callee

```csharp
public(Shop.Reports, Shop.Billing) int Recompute(int n)
```

(Spelling illustrative; not prototyped.) The same choke point and the same `restrict/2` shape with list membership in place of a prefix test, so the checker cost measured above carries over; nothing else about it was measured.

**Strongest counterargument.** The list must be edited whenever a legitimate caller is added, so the *callee* changes for a decision that belongs to the *caller*. For the consumer the ticket names (ticket 24: tests over `unclassified` helpers), the list is the wrong granularity. It does remove the rename hazard of option 1.

### 3. Add nothing

Keep `public` / `private`; use directory layout and review as the convention. Today any module that `using`s `Shop.Pricing` can name every public function in it (table above), so the third-category helper like `RecomputeTotal/1` has to be either `public` or `private`.

**Strongest counterargument.** The ticket's own consumer argument (built on ticket 24 §2): an agent writing tests targets `unclassified` functions because they are the easiest to test. That is the ticket's prediction; it was not measured here, and no program in the repo has failed because of it.

## About the "direction" question

The caller-side reading (the caller declares what it depends on) cannot restrict anyone else, because the callee has no say. It is a different feature, a narrowed import list, and it does not give ticket 24 what it needs. The probes bear on this only by showing `using` today gives the callee no say (first table).

Not probed: records, types and protocols from an internal module, single-segment module names, and a module whose directory disagrees with its name.

## Recommendation

**Option 1, when ticket 24's test classification is next built; until then option 3 costs nothing.** The prototype is 34 lines, the checker cost is not measurable, and it reuses the F12 refusal. Two things should be settled by David before any build: the spelling (the false-friend objection above), and whether the subtree root is the declarer's parent or something the author states.

## Neighbours (executed; `p60_neighbours.sh`)

| language | mechanism | enforced? |
|---|---|---|
| Gleam | `internal_modules = ["dep/internal", "dep/internal/*"]` in `gleam.toml`; `@internal` on a `pub fn` | **No.** An app depending by path imported `dep/internal/h` and called an `@internal` function; `gleam build` exit 0, no warning, both times |
| Elixir | `@moduledoc false`, `@doc false` | **No.** Calling the hidden function from another module printed 42. `defp` called from outside is a compile *warning* (`undefined or private`, exit 0) and then a run-time error |
| Erlang | `-export` | The only visibility; any exported function is callable by every module |
| Elm | `exposed-modules` in `elm.json` (package-scoped) | not executed: `package.elm-lang.org` is blocked |

No BEAM neighbour enforces "who may name this module". Option 1 would be the first, which is a reason for care and not an argument against.
