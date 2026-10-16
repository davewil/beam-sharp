# Decision brief — ticket 60: which modules may name this one?

**Linear**: [ENG-242](https://linear.app/davewil/issue/ENG-242) · **Ticket file**: `wayfinder/issues/60-which-modules-may-name-this-one.md`
**State**: OPEN. This brief resolves nothing. **Independent verification**: `artifacts/verification/60-verifier.md`.

## The question, as a program

`Shop.Billing` needs `RecomputeTotal`, which must be `public` for a sibling module to call it, but is not client API.
Today nothing stops `Other` from naming it:

```csharp
// Shop/Internal/Rows/Rows.bs
module Shop.Internal.Rows
public int RecomputeTotal(int n)
RecomputeTotal(n) -> n * 2

// Other/Other.bs                      accepted today
module Other
using Shop.Internal.Rows
public int Poke(int n)
Poke(n) -> RecomputeTotal(n)
```

This is ticket 24 §2's `unclassified` helper. `private` is per-function and per-module; nothing says "this subtree only".

## Sub-decisions (the ticket's four)

1. The unit: directory subtree, named group, explicit list.
2. Direction: callee names who may call, or caller declares dependencies.
3. A third visibility marker on the signature, or a separate construct.
4. Cost to the checker.

## Findings

- **Choke point**: `using` is the only way to name another module; a fully qualified call without it fails `module_not_imported`
  (`bs_diag.erl:664`, verified by the verifier on both compilers). The place is `add_import/7` (`bs_check.erl:498`), which already has both the importer (`Self`)
  and the imported module (`M`). The ticket's citation `bs_check.erl:407-425` has drifted (that is `qualify_refs` now);
  `add_module_import` is at `:512` and takes 3 arguments, not 5. Commit `0b761f6` is not in this repository.
- **No existing mechanism**: grep of `compiler/src` for friend/sealed/internal/visible_to finds none (re-confirmed by the verifier).
- **A direct `using` check is not enough**: a *namespace* `using Shop.Internal` imports its children through a second branch of `add_import`.
  My first prototype missed this and the verifier found the same bypass independently; the patch now filters invisible children
  (`tree_result.txt`, row `Other2`). Any real design must cover both branches. This is the real checker cost.

## Survey (executed unless marked)

| language | mechanism | enforced? | evidence |
|---|---|---|---|
| **Go** | a path segment `internal/` : importable only from the tree rooted at its parent | **yes, by the compiler** | `probes/60/go_internal`: `go build ./shop/...` OK; `go build ./other` → `use of internal package example.com/proj/shop/internal/rows not allowed` (go 1.24.7) |
| **Rust** | callee-side path scope, per item: `pub(in crate::shop)` | **yes** | `probes/60/rust_pub_in_path.rs`: `error[E0603]: function recompute is private` (rustc 1.97.0) |
| **Gleam** | `internal_modules` glob, default `<pkg>/internal`, plus `@internal` | **no**, documentation only | `probes/60/gleam_internal_not_enforced`: package `appb` imports `liba/internal/secret` and calls an `@internal` fn, `gleam build` 1.12.0 compiles with no warning. Source: `compiler-core/src/config.rs:259-278` (`is_internal_module`), used to downgrade *type* publicity at `analyse.rs:1255` |
| **Elixir** | `@moduledoc false` / `@doc false` | **no** | `probes/60/elixir_moduledoc_false.ex`: `P60.Outsider.poke()` → `42` |
| **Erlang** | export list only | no per-caller control | (language fact) |
| **Elm** | package `exposed-modules` | package granularity (source read: `builder/src/Elm/Outline.hs`; **not executed**, registry unreachable) | |

The two languages that *enforce* use a path position (Go) or a callee-side path scope (Rust); the two that rely on a naming
convention without enforcement (Gleam, Elixir) are the evidence for what "convention only" yields. C#'s `internal` is assembly-scoped, and B# has no assembly (the ticket's false-friend point stands).

## Options

### Option 1 — the path says it: a module with an `Internal` segment is nameable only from the subtree above it (Go)

No grammar, no declaration. Compiler delta (patch `artifacts/patches/60-E-internal-segment.diff`, 24 changed lines):
a `visible/2` predicate; `add_import` errors on a direct module, and filters invisible children out of a namespace import; one
diagnostic tag `not_visible` in `bs_diag.erl`.
Measured (`probes/60/tree_result.txt`): `Shop.Billing` accepted; `Other` refused (`Other may not name Shop.Internal.Rows`);
`Other2` (`using Shop.Internal`) refused (but the message is the generic *"names no module and no namespace"*, which would need its own wording).
Verifier's extra cases: `Shop2.Billing` refused, `Shop.D` using `Shop.A.Internal.B` refused, `Shop.A.C` using `Shop.A.Internal.B` accepted,
`Shop` itself accepted, `Shop.InternalX` not treated as internal.
Decides the sub-decisions: unit = directory subtree; direction = the callee, by where its name sits; not a marker; checker cost one function.

*Strongest counterargument.* It spends a word of the module namespace (`Internal`), which ticket 65 (reserved names) and
85 may want to own; visibility lives in a directory name, which an agent can rename away; and it is all-or-nothing per module: it cannot say
"only `Shop.Billing`, not all of `Shop`". It also makes a refactor that moves a module a visibility change.

### Option 2 — the module declares it (Rust's `pub(in path)` shape, at module granularity)

```csharp
module Shop.Rows
visible Shop                       // only modules under Shop may `using` this
public int RecomputeTotal(int n)
```

Compiler delta (**not prototyped**): a new module-level declaration (grammar + `bs_parser.yrl`), the World entry in `bs_check` gains a
`visible` prefix list, and the same two-branch check at `add_import` as Option 1. Evidence for the shape is Rust's executed probe
(per-item scope works and names exactly the subtree).

*Strongest counterargument.* A new keyword in a language that treats its keyword count as budget (ticket 22: "the sixteenth keyword is not spent"),
plus the grammar and a decision on whether it is per file or per directory-module. Everything Option 1 costs at `add_import` it also costs, and then more.

### Option 3 — leave it; `private` plus convention

No change. The ticket says "not owed a decision soon". Evidence of what convention-only does: Gleam's default `internal` directory and Elixir's
`@moduledoc false` both compile and run when violated (probes above), and ticket 24's concern is an agent in a loop targeting `unclassified` helpers.

*Strongest counterargument.* That is the ticket's own consumer; the two enforcing neighbours (Go, Rust) show enforcement is cheap, and
this repo's CLAUDE.md says structural drift is the characteristic failure of agent authorship.

## Recommendation

**Option 1 as the first step, because it is the only option with both an executed enforcing precedent (Go) and a working prototype here,
and it costs no grammar.** It is reversible: if David later wants Option 2's per-module list, `Internal` can stay as the default rule. Before building,
two things need a decision: the segment's spelling (`Internal` is a guess) and whether the name is reserved for this meaning (ticket 65).

## Caveats

- The prototype was built on OTP 28.0, repo pins 28.5. The Gleam probe is a path dependency; hex was unreachable, nothing else was needed.
- Not measured: compile-time cost of the check (it is a string split per import); I expect it to be negligible but did not time it.

## Verifier (independent re-run; full report `verification/60-verifier.md`)

**CIRCULAR: partial.** Everything reproduces (tree, Go, Rust, Gleam, Elixir; the patch matches the literal segment `Internal`, not probe names; `Shop.InternalX`, top-level `Internal.X` and `Shop` itself behave sensibly).
The "partial" was a real flaw in the first version of patch E: it checked only the direct-module branch of `add_import`, so a namespace `using Shop.Internal` (or `using Shop.A` then `Internal.B.Bf(n)`) bypassed it
and compiled and ran on E exactly as on the unpatched compiler. I had found the same bypass independently while the verifier ran; the patch in `artifacts/patches/` now filters invisible children of a namespace import
and `probes/60/tree_result.txt` contains the `Other2` row. **The verifier's report predates that fix**; I re-ran the three tree rows against the rebuilt patch myself (accepted / refused / refused) but the verifier's new
bypass probes were not re-run against the fixed patch. One more known residue: the refusal for a namespace import prints the generic "names no module and no namespace".
