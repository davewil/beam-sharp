#!/usr/bin/env bash
# P05: what does Gleam 1.18.1 actually transform when it emits to the BEAM?  (ticket 10 §7 claim:
# "PascalCase to snake_case"; ticket 62: "Gleam downcases PascalCase to snake_case when it emits".)
# No gleam compiler sources exist locally, so every statement below is read off GENERATED .erl or the
# compiler's own error text. No dependencies (hex.pm is blocked): gleam.toml is written by hand.
# CLAIM A (ticket 62 option-2 precedent): Gleam turns PascalCase *function names* into snake_case.
#   REFUTED IF: Gleam accepts a PascalCase function name (we try it) or the generated .erl has a snake alias of a Pascal fn.
# CLAIM B (ticket 10 §7): custom-type constructors lower PascalCase -> snake_case atoms.
#   REFUTED IF: the generated .erl keeps `'Red'` / `{'Circle', ..}` Pascal-cased.
# CLAIM C (62 §1): `@external(erlang,"Shop","New")` works. REFUTED IF the call at run time is undef/badarg.
. "$(dirname "$0")/lib.sh"
G="$SCRATCH/p05"; rm -rf "$G"; mkdir -p "$G/src/a" "$G/ebin"
cat > "$G/gleam.toml" <<'T'
name = "p05"
version = "1.0.0"
T
cat > "$G/src/p05.gleam" <<'GL'
pub type Colour { Red HTTPGet ToJSON }
pub type Shape { Circle(radius: Float) RightTriangle(Int, Int) }
pub type Order { Order(id: Int, total: Int) }
pub fn colours() -> List(Colour) { [Red, HTTPGet, ToJSON] }
pub fn shapes() -> List(Shape) { [Circle(1.5), RightTriangle(3, 4)] }
pub fn an_order() -> Order { Order(7, 0) }
pub fn is_ok_ctor() { Ok(1) }
GL
cat > "$G/src/a/b.gleam" <<'GL'
pub fn deep() -> Int { 1 }
GL
cat > "$G/src/ext.gleam" <<'GL'
// the ticket's Gleam claim, run for real: a PascalCase foreign function named by a string
@external(erlang, "Shop", "New")
pub fn shop_new(id: Int) -> a

pub fn make(id: Int) -> a { shop_new(id) }
GL
echo "=== build (no deps)"; (cd "$G" && gleam build 2>&1 | sed 's/^/  /')
E=$G/build/dev/erlang/p05/_gleam_artefacts
echo "=== generated files"; ls $E | sed 's/^/  /'
echo "=== p05.erl: -export, constructors"; grep -n "export\|^-spec\|Red\|red\|dark\|http\|to_j\|circle\|right_tri\|order\|ok" $E/p05.erl | sed 's/^/  /'
echo "=== a@b.erl"; sed -n 1,12p $E/a@b.erl | sed 's/^/  /'
echo "=== ext.erl (how @external is lowered)"; cat $E/ext.erl | sed 's/^/  /'

echo "=== PascalCase FUNCTION name: does Gleam permit it?"
mkdir -p "$G/neg/src"; cat > "$G/neg/gleam.toml" <<'T'
name = "neg"
version = "1.0.0"
T
cat > "$G/neg/src/neg.gleam" <<'GL'
pub fn New(id: Int) -> Int { id }
GL
(cd "$G/neg" && gleam build 2>&1 | sed 's/^/  /' | head -20)
echo "=== PascalCase MODULE file name (src/Shop.gleam)"
mkdir -p "$G/neg2/src"; cat > "$G/neg2/gleam.toml" <<'T'
name = "neg2"
version = "1.0.0"
T
echo 'pub fn f() -> Int { 1 }' > "$G/neg2/src/Shop.gleam"
(cd "$G/neg2" && gleam build 2>&1 | sed 's/^/  /' | head -20)
echo "=== PascalCase variable / constant / underscore-Pascal function"
mkdir -p "$G/neg3/src"; cat > "$G/neg3/gleam.toml" <<'T'
name = "neg3"
version = "1.0.0"
T
echo 'pub fn Foo_bar() -> Int { 1 }' > "$G/neg3/src/neg3.gleam"
(cd "$G/neg3" && gleam build 2>&1 | sed 's/^/  /' | head -12)
echo 'pub fn fooBar() -> Int { 1 }' > "$G/neg3/src/neg3.gleam"
(cd "$G/neg3" && gleam build 2>&1 | sed 's/^/  /' | head -12)

echo "=== PascalCase variant containing an underscore (Dark_Green)"
mkdir -p "$G/neg4/src"; printf 'name = "neg4"\nversion = "1.0.0"\n' > "$G/neg4/gleam.toml"
echo 'pub type C { Dark_Green }' > "$G/neg4/src/neg4.gleam"
(cd "$G/neg4" && gleam build 2>&1 | sed 's/^/  /' | head -12)
echo "=== two variants whose names differ only in case-folding (collision test): HttpGet vs HTTPGet"
mkdir -p "$G/neg5/src"; printf 'name = "neg5"\nversion = "1.0.0"\n' > "$G/neg5/gleam.toml"
echo 'pub type C { HttpGet HTTPGet }
pub fn f() { [HttpGet, HTTPGet] }' > "$G/neg5/src/neg5.gleam"
(cd "$G/neg5" && gleam build 2>&1 | sed 's/^/  /' | head -12); grep -n "http" "$G"/neg5/build/dev/erlang/neg5/_gleam_artefacts/neg5.erl | sed 's/^/  /'
echo "=== run Gleam's @external against a compiled bsc module (claim C)"
"$BSC" --src-root "$REPO/compiler/examples" -o "$G/ebin" "$REPO/compiler/examples/Shop" >/dev/null 2>&1
cd "$SCRATCH" && erl -noshell -pa "$G/ebin" -pa "$G"/build/dev/erlang/p05/ebin -eval '
  io:format("ext:make(3) -> ~p~n", [ext:make(3)]),
  io:format("p05:colours() -> ~p~n", [p05:colours()]),
  io:format("p05:shapes() -> ~p~n", [p05:shapes()]),
  io:format("p05:an_order() -> ~p~n", [p05:an_order()]),
  io:format("a@b:deep() -> ~p~n", [a@b:deep()]),
  halt(0).' 2>&1 | sed 's/^/  /'
