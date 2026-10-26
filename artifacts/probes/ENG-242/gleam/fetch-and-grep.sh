#!/usr/bin/env bash
# Gleam is NOT installed. This reads Gleam compiler SOURCE as text only (never executed), from
# the public repo's main branch via raw.githubusercontent.com, into a fresh empty directory.
# Evidence is therefore "source at fetch time", not behaviour; the commit is not pinned.
D=$(mktemp -d)
for f in compiler-core/src/config.rs compiler-core/src/analyse.rs compiler-core/src/docs.rs \
         compiler-core/src/type_/environment.rs compiler-core/src/type_/error.rs; do
  curl -sS -m 60 -o "$D/$(echo $f | tr / _)" "https://raw.githubusercontent.com/gleam-lang/gleam/main/$f" || echo "fetch failed: $f"
done
cd "$D"
echo "== config.rs: where internal_modules is declared and what is_internal_module says it is for"
grep -n 'pub internal_modules' compiler-core_src_config.rs
sed -n '/Determines whether the given module should be hidden/,/pub fn is_internal_module/p' compiler-core_src_config.rs
echo "== analyse.rs: what the compiler does with an internal module"
grep -n 'is_internal_module' compiler-core_src_analyse.rs
sed -n '/We check is the type comes from an internal module/,/^        };/p' compiler-core_src_analyse.rs | head -14
echo "== docs.rs: the other consumer"
grep -n 'is_internal_module' compiler-core_src_docs.rs
echo "== type_/error.rs: any error variant that rejects an import from an internal module?"
grep -n -i 'internal' compiler-core_src_type__error.rs
