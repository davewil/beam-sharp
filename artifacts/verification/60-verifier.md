# Ticket 60 verifier report (independent re-run, 2026-10-16)

Verdict: CIRCULAR: partial. The stored results are real and reproduce exactly. The prototype is not name-special-cased.
But E has a real bypass that the stored evidence does not mention (pure-namespace `using Shop.Internal`), so the ticket's
"E enforces the internal rule" is only true for `using` of a path that is itself a module.

## 1. Re-runs (all from copies in /tmp/claude-0/verify60/, artifacts/ untouched)
E rebuilt with `artifacts/build-variant.sh patches/60-E-internal-segment.diff /tmp/claude-0/verify60/E` (patch applied clean, not /tmp/claude-0/proto60).
Invocation: `bsc -o OUT --src-root . <dir>` (bare `bsc <dir>` without --src-root prints usage).

tree/ (Shop.Internal.Rows, Shop.Billing, Other):
- unpatched: Shop/Billing OK, Other OK (no output)
- E: Shop/Billing OK; Other -> `Other/Other.bs:3:1: error: Other may not name Shop.Internal.Rows / a module path with an `Internal` segment is visible only under the path before it.`
- Matches tree_result.txt (only cosmetic diff: stored text prints `tree/Other/Other.bs`, I ran with --src-root so path is `Other/Other.bs`). No divergence.
- Also: `--api` and `--diagnostics json` on E both give the error (`"tag":"not_visible"`), so lenient mode does not skip it.

Go (GOFLAGS=-mod=mod GOTOOLCHAIN=local): `go build ./...` -> `package example.com/proj/other / other/o.go:2:8: use of internal package example.com/proj/shop/internal/rows not allowed`; `go build ./shop/...` clean. CONFIRMED.
Rust: `rustc --edition 2021 rust_pub_in_path.rs` -> `error[E0603]: function `recompute` is private` at line 5 (`other::poke`); billing (inside crate::shop) fine. CONFIRMED.
Gleam: `cd appb && gleam run` -> `Compiling liba / Compiling appb / Compiled in 0.45s / Running appb.main`; no warning, no error, although appb imports `liba/internal/secret` and calls `@internal` `liba.attr_internal()` across a path-dependency package boundary. CONFIRMED (also a stronger claim than stored: no warning at all).
Elixir (PATH=/usr/bin:/bin elixirc): zero diagnostics; running `P60.Outsider.poke()` prints 42. CONFIRMED.

## 2. Reading patch E
- Check is only in `add_import`'s `maps:is_key(M, World) == true` branch (module branch). Name test is the literal segment `"Internal"` split on "."; no probe names (Shop, Other, Rows) appear. Not special-cased.
- Prefix test: segments are compared whole, so `Shop.InternalX` is not internal (tested: compiles on E). Allowed iff prefix empty, importer == prefix, or importer starts with `prefix.`; so `Shop2.Billing` is correctly refused (not a textual prefix match), module `Shop` itself may name `Shop.Internal.Rows`, and the importer `Shop.Internal.Rows` / its siblings `Shop.Internal.Sib` may name it.
- Design quirk: top-level `Internal.X` (empty prefix) is visible to everyone (Go-like root-internal would arguably mean "whole tree" so same, but worth stating). Module literally named `Shop.Internal` (segment at end) is also restricted to Shop.* (UsesInt refused).
- Fully qualified call without `using` is NOT a bypass: both unpatched and E reject `Shop.Internal.Rows.RecomputeTotal(n)` with `Shop.Internal.Rows is called but never imported` (bs_check.erl:4431 module_not_imported).
- BYPASS FOUND: the check is not applied in the namespace branch (`add_namespace_import`). If `Shop.Internal` is a pure namespace (no module file at that path, the normal case: tree/ has none), then in any module:
  `using Shop.Internal` + `P(n) -> Rows.RecomputeTotal(n)` compiles on E and RUNS: `bsc --src-root . BypassNs P 21` -> `42` on both E and unpatched. Same for `using Shop.A.Internal` + `B.Bf(n)` (BypassD, E: compiles, no error) and `using Shop.A` + `Internal.B.Bf(n)` (BypassNs4, E: compiles). So any outsider reaches every internal module by importing the parent namespace. E's own diagnostic text ("visible only under the path before it") is therefore not true. Fix is small (filter children of the namespace through the same predicate, or refuse namespaces whose children are internal) but it is not in the patch and not tested by tree/.
  (If `Shop/Internal/Internal.bs` exists, `using Shop.Internal` hits the module branch and IS refused, so the bypass depends on layout; stored tree/ has no such file.)

## 3. New probes (all in /tmp/claude-0/verify60/v2, unpatched vs E)
| probe | unpatched | E |
|---|---|---|
| Shop.Internal.Sib using Shop.Internal.Rows (sibling) | ok | ok |
| module Shop using Shop.Internal.Rows | ok | ok |
| Shop2.Billing using Shop.Internal.Rows | ok | REFUSED `Shop2.Billing may not name Shop.Internal.Rows` |
| Shop.InternalX used from UsesX | ok | ok (not treated as internal) |
| Shop.A.C using Shop.A.Internal.B | ok | ok |
| Shop.D using Shop.A.Internal.B | ok | REFUSED `Shop.D may not name Shop.A.Internal.B` |
| Internal.Top used from UsesTop | ok | ok (empty prefix = public) |
| UsesInt using module Shop.Internal | ok | REFUSED |
| BypassNs: `using Shop.Internal` (namespace) + Rows.RecomputeTotal | ok (42) | ok (42) BYPASS |
| BypassD: `using Shop.A.Internal` + B.Bf | ok | ok BYPASS |
| BypassNs4: `using Shop.A` + Internal.B.Bf | ok | ok BYPASS |
| BypassFq: fully qualified call, no using | module_not_imported | module_not_imported (not a bypass) |
Note: the first run of my probe layout accidentally contained `Shop/Internal/Internal.bs`, which made BypassNs refused; I removed it to model tree/'s pure-namespace layout. Both outcomes reported above.

## 4. Existing visibility mechanism / citation
- `grep -rniE "friend|sealed|visible_to|internal|visib" compiler/src` (excl. generated parser): no friend/sealed/visible_to anywhere; "internal" hits are comments or erl_internal:guard_bif; visibility hits are the public/private signature marker only. Claim "none exists" CONFIRMED.
- Citation DRIFTED: bs_check.erl:407-425 is now `qualify_refs/2` (type renaming). Current: `import_env/4` ~line 485, `add_import/7` line 498, `add_module_import/3` line 512 (arity is 3, ticket says /5), `add_namespace_import/3` ~524. Current last commit on bs_check.erl is 0f4859a (2026-10-11). Commit `0b761f6` named in the ticket does not exist in this repo (`git show` fatal: invalid object name), so the "measured at" line cannot be reproduced as written.

## Circularity assessment
- Not circular in the sense of fitted names or hand-written expected output: the tree result reproduces from a fresh build, and generalizes correctly to the new probes (Shop2, Shop.D, InternalX, siblings).
- Partial: the tree probe is arranged so that the only route to Shop.Internal.Rows is a direct module `using`, which is exactly what the patch guards; it never exercises the namespace import path, which the patch leaves open. The stored "E accepts Billing, refuses Other" is true but overstates what E enforces. Any ticket text saying E "enforces" the rule should say "for module-path usings; namespace usings bypass it" or the patch should be extended and tree/ given a `using Shop.Internal` case.
