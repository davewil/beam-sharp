# Decision brief — ticket 60 (ENG-242): which modules may name this one?

Status of the ticket: **left open** (it says itself it is "not owed a decision soon"). Evidence: `artifacts/probes/results/60-*.txt`, patch `v60a`. Limits: `artifacts/README.md`.

## The one question David decides (it gates the other three)

What is the **unit** a module can be restricted to? The other sub-decisions (direction, marker vs construct, checker cost) follow from it.
Under a subtree unit this compiles for `Shop.Orders` and is refused for `Other`:

```csharp
// Shop/Internal/Rate/Rate.bs
module Shop.Internal.Rate          // nameable only from inside Shop.**
public int Rate(int n)
Rate(n) -> n * 2

// Other/Other.bs
module Other
using Shop.Internal.Rate           // refused
```

## Sub-decisions

1. Unit: a directory subtree, a named group, or an explicit module list.
2. Direction: the callee names who may call it, or the caller declares what it may depend on.
3. A third visibility marker on a signature, or a module-level construct.
4. What it costs the checker.

## What was measured

- **Today nothing restricts naming** (`60-subtree-prototype.txt`, baseline): `Shop.Orders`, `Other` (`using Shop.Internal.Rate`) and `Other2` (`using Shop`, then `Internal.Rate.Rate(n)`) all compile. A bare qualified call with no `using` (`Other3`) is already refused; but see the next bullet, `using` is not the only gate.
- **A subtree rule is a small checker change** (`patches/v60a`, 13 added lines in `bs_check:import_env/4`): drop from the world any module with an `Internal` segment unless the importer's name starts with the segment's prefix. Result: `Shop.Orders` compiles; `Other` and `Other2` are refused. eunit failing set identical to baseline.
- **The prototype is leaky (verifier probes, `artifacts/verification/60.md`).** The filter covers only the world given to `import_env`; `imported_types` (`bs_check.erl:1264,1309`) uses the unfiltered one. An outsider with `using Shop.Orders` can write `Sz(Shop.Internal.Rate.Quote q)` and a hidden refined type, and pass `Shop.Orders.Quoted(n)` into it, and it compiles and runs. `bsc --api Shopify` (lenient mode) prints the signature while the normal compile is refused. So my earlier sentence that `using` is the only naming gate to guard is **wrong**: types are a second gate, and `--api` a third. Segment comparison is correct (`Shopify` is refused, sibling `Shop.Pay` admitted).
- **The diagnostics it produces are also wrong, which is the real compiler work.** `Other` gets "`using Shop.Internal.Rate` names no module and no namespace", false because the module exists.
  `Other2` gets "Internal.Rate is called but never imported: add `using Internal.Rate`", and following that advice fails with the first message.
  A real implementation needs a `not_visible` error and a clause in `bs_diag` (`message/1` has no catch-all, per the F35 comment in `compiler/rebar.config`), and it must separate hidden from absent.
- **Filtering the whole world is the wrong shape.** `60-predicate-cost.txt`: about **10 µs per module, ~10 ms per compiled module over a 1,001-module world**. Testing only the modules a file actually names (its `using` lines and namespace children) is proportional to the imports, not the world.
- **A callee-side declaration costs the grammar nothing.** Adding `module Shop.Rate for Shop.Orders, Shop.Billing` (reusing the `for` terminal) or `... visible_to ...` (a new terminal) to `bs_parser.yrl` leaves yecc at **6 shift/reduce, 0 reduce/reduce**, identical to baseline (`60-grammar-conflicts.txt`). The two grammars were only parsed by yecc, not wired to the checker.

## Neighbours (executed)

- **Elixir 1.14:** `@moduledoc false` on `A` and on the installed `Kernel.Utils` (`Code.fetch_docs` returns `:hidden`) removes documentation only; both are called successfully from outside (`60-elixir-hidden-is-callable.txt`). So the neighbour's "internal" is a convention, not a check.
- C#'s `internal` is assembly-scoped; the ticket's false-friend warning stands and I found nothing in the installed OTP/Elixir that contradicts it. Gleam and Elm are **not installed**; no claim made about their internal-module features.

## Options

### A. A subtree, spelled by a reserved path segment (`Internal`), `v60a`
Zero new syntax. Needs the type-import path and `--api` covered too. **Strongest counterargument:** visibility by directory name is magic, and moving a directory changes who may call it with no source edit; it also cannot say "Shop.Billing and Shop.Orders but not Shop.Reports".

### B. The callee declares who: a list of modules or subtrees (`module Shop.Rate for Shop.Orders, Shop.Billing`)
Grammar cost measured at zero conflicts; the checker site is the same predicate with a list in place of a prefix.
**Strongest counterargument:** the callee must be edited whenever a new friend appears, and the arrow points opposite to `using` (ticket Q2), so a file's dependencies are no longer all visible in its own `using` lines.

### C. Do nothing yet
The ticket itself says no decision is owed soon. Counter, **unmeasured by me**: ticket 24 §2 says agents write tests against `unclassified` helpers because they are easiest; I did not measure that.

## Recommendation

**B with subtrees as the list's elements**: `module Shop.Rate for Shop` means the module is nameable from `Shop` and everything under it; a single module is a subtree of one. That one construct covers A's case and B's case, keeps the declaration visible in source, and avoids a magic segment. It was not built as one piece: I measured the grammar cost and the prefix predicate separately. Whichever is chosen, budget the diagnostic work first; it is larger than the check.
