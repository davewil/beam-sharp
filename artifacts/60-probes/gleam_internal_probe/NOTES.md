# Gleam visibility probe

Two things measured, because Gleam turned out to have more than `pub`/private once its compiler
source was actually read (`gleam_lexer_v1.9.1.rs`, `gleam_ast_v1.9.1.rs`, `gleam_imports/config`
under `../gleam_source_citations/`).

## 1. `pub`/private is genuinely binary at the language surface

`visibility_probe/` (single package): `orders/internal.gleam` has a private `fn
recompute_total()`; `billing/caller.gleam` (a different module in the *same* package) tries to
call it. `gleam build` (network-restricted: `gleam.toml` deliberately carries no dependencies so
this builds offline) —

    error: Unknown module value
      ...
      internal.recompute_total()
               ^^^^^^^^^^^^^^^ Did you mean `call_from_same_module`?
    The module `orders/internal` does not have a `recompute_total` value.

Confirmed against the lexer source: `"pub" => Some(Token::Pub)` is the *only* visibility-shaped
keyword in `compiler-core/src/parse/lexer.rs`'s keyword table. No `friend`, `internal` keyword, or
path-scoped `pub(in ...)` exists in the grammar.

## 2. There IS a third publicity tier, `Internal` — but it is package-scoped and docs/interface-only,
   not a per-caller compile check, and (measured) does not survive a local path dependency

`compiler-core/src/ast.rs:608-611` defines `enum Publicity { Public, Private, Internal { .. } }`,
written `@internal` on a definition, or auto-applied to `pub` **types** (not functions — see below)
declared inside a module path matched by `gleam.toml`'s `internal_modules` glob (default:
`<package>/internal`, `<package>/internal/*`, confirmed by `config.rs`'s own test,
`gleam_source_citations/compiler-core_src_config.rs:442-471`). `error.rs`'s own doc comment on
`InternalTypeLeak` says what this is for: "internal types are excluded from documentation,
completions **and the package interface**" — i.e. Hex's published metadata for other packages, not
a call-site check the type checker enforces against source.

Measured directly with `gleam_internal_probe/` (two local packages, `orders_pkg` and `billing_pkg`,
linked with a `path = "../orders_pkg"` dependency so no `repo.hex.pm` access is needed —
`repo.hex.pm` is unreachable from this sandbox, confirmed: `gleam build` on a fresh `gleam new`
project fails with "Unable to determine package versions ... error sending request for url
(https://repo.hex.pm/packages/gleeunit)"):

- `orders_pkg/src/orders_pkg/internal/core.gleam` has `pub fn recompute_total()` under a path
  matched by the *default* `internal_modules` glob.
- `billing_pkg`, a **separate package**, depends on `orders_pkg` and calls
  `core.recompute_total()`.
- `gleam build` in `billing_pkg/` — **compiles clean** (`build_output_1_path_dep_not_blocked.txt`).
  Confirmed this is not merely "functions are exempt from the glob" by also trying it with an
  explicit `@internal` on the same function (`build_output_2_at_internal_attribute_still_not_blocked_via_path_dep.txt`)
  — also compiles clean.

Read against `analyse.rs:1160-1167`, the reason is precise: the `internal_modules` glob's automatic
demotion is applied only when **registering a type** (`Publicity::Public if
is_internal_module(...) => Internal`); `register_value_from_function`
(`analyse.rs:1338` onward) uses the function's own written `publicity` with no such demotion. So
even the glob-based form only ever touches types, not functions, by construction — and whatever
`@internal`/`internal_modules` actually gates (docs, `hex` search/completions, the published
`.gleam.pkg` interface a *hex-installed* dependency reads instead of source) is not something a
`path`-dependency build reads, so it did not fire either way in this probe.

**Net finding, stated carefully because two people reading Gleam docs casually would disagree**:
Gleam has three publicity words, but only two are a compile-time call boundary (`pub` /
implicit-private, module-scoped, binary). The third (`Internal`) is a **published-package-boundary**
feature aimed at Hex documentation/interface generation, not a caller-restriction the type checker
enforces against a caller compiling from source — measured here as still-callable through a path
dependency with the attribute present. This is closer in *shape* (package-wide, not per-friend) to
C#'s `internal`/assembly than to what ticket 60 is asking (naming specific callers), and further
still from Rust's `pub(in path)`.
