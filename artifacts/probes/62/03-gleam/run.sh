#!/usr/bin/env bash
# Gleam 1.5.0, dependency-free projects (no Hex access needed).
. "$(dirname "$0")/../lib.sh"
GLEAM=${GLEAM:-/tmp/claude-0/gleamx/gleam}
BSC=$(build_bsc plain) || exit 1
compile_shop "$BSC" "$SCRATCH/shop-ebin"
W="$SCRATCH/gleam03"; rm -rf "$W"; mkdir -p "$W"
mk() { mkdir -p "$W/$1/src"; printf 'name = "%s"\nversion = "1.0.0"\ntarget = "erlang"\n[dependencies]\n' "$1" > "$W/$1/gleam.toml"; cat > "$W/$1/src/$1.gleam"; }

echo "=== A. Gleam CALLING a B# module (@external with the PascalCase names); compile AND run"
mk a <<'G'
@external(erlang, "Shop", "New")
fn shop_new(id: Int) -> a
@external(erlang, "Shop", "Which")
fn shop_which(o: a) -> b
pub fn main() { shop_which(shop_new(1)) }
G
(cd "$W/a" && $GLEAM build 2>&1 | tail -2; grep -n "'Shop'" build/dev/erlang/a/_gleam_artefacts/a.erl)
erl -noshell -pa "$SCRATCH/shop-ebin" -pa "$W/a/build/dev/erlang/a/ebin" -eval 'io:format("a:main() -> ~p~n",[a:main()]),halt().'

echo; echo "=== B. Can a Gleam author even WRITE a PascalCase function (the thing B# does)?"
mk b <<'G'
pub fn DoThing() { 1 }
G
(cd "$W/b" && $GLEAM build 2>&1 | head -9)
mk b2 <<'G'
pub fn do__thing_X() { 1 }
G
(cd "$W/b2" && $GLEAM build 2>&1 | head -8)

echo; echo "=== C. What Gleam DOES convert PascalCase->snake_case: constructor names (atoms)"
mk cc <<'G'
pub type T { ABTest XMLHttpRequest Foo2Bar Get2D HTMLElement A AB ABc IOError V8Engine MyOrderLine }
pub fn all() { [ABTest, XMLHttpRequest, Foo2Bar, Get2D, HTMLElement, A, AB, ABc, IOError, V8Engine, MyOrderLine] }
pub fn do_thing_now() { 1 }
G
(cd "$W/cc" && $GLEAM build 2>&1 | tail -1; grep -n -A12 '^-type t()' build/dev/erlang/cc/_gleam_artefacts/cc.erl; grep -n '^-export' build/dev/erlang/cc/_gleam_artefacts/cc.erl)

echo; echo "=== D. Does that derivation rule collide? (ABC vs Abc)"
mk d <<'G'
pub type T { ABC Abc }
pub fn x() { #(ABC, Abc) }
G
(cd "$W/d" && $GLEAM build 2>&1 | tail -1; grep -n '^-type t()' build/dev/erlang/d/_gleam_artefacts/d.erl; sed -n '/^x()/,$p' build/dev/erlang/d/_gleam_artefacts/d.erl)
mk d2 <<'G'
pub type T { Foo_Bar }
G
(cd "$W/d2" && $GLEAM build 2>&1 | head -6)

echo; echo "=== E. module path encoding"
mkdir -p "$W/cc/src/deep"; echo 'pub fn f() { 1 }' > "$W/cc/src/deep/nested.gleam"
(cd "$W/cc" && $GLEAM build 2>&1 | tail -1; ls build/dev/erlang/cc/ebin)
