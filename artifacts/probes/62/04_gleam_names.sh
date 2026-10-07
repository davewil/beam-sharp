#!/usr/bin/env bash
# What atom does the Gleam compiler actually emit for a PascalCase variant name? (ticket 10 s7 claims
# "PascalCase becomes snake_case"). Read from the emitted .erl, not from memory of gleam's source.
export PATH=$HOME/.nix-profile/bin:$PATH
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; mkdir -p "$W/p/src"
printf 'name = "p"\nversion = "1.0.0"\n' > "$W/p/gleam.toml"
cat > "$W/p/src/p.gleam" <<'G'
pub type T {
  Order(id: Int)
  HTTPGet(id: Int)
  ToJSON(id: Int)
  New2(id: Int)
  FooBar(id: Int)
  Foobar(id: Int)
  ABC(id: Int)
  Abc(id: Int)
  A1B(id: Int)
  XMLHttpRequest2(id: Int)
  IOError(id: Int)
  Get(id: Int)
  Get2(id: Int)
  Get_2(id: Int)
}
pub type U { Ok2 HTTPGetU ToJSONU New2U ABCU AbcU Foo_bar }
pub fn mk() { [Order(1), HTTPGet(1), ToJSON(1), New2(1), FooBar(1), Foobar(1), ABC(1), Abc(1), A1B(1), XMLHttpRequest2(1), IOError(1), Get(1), Get2(1)] }
pub fn mku() { [Ok2, HTTPGetU, ToJSONU, New2U, ABCU, AbcU] }
G
cd "$W/p" && gleam --version
echo "--- phase 1: names with underscores (expected: refused)"
gleam build 2>&1 | grep -A1 "Invalid\|valid type variant" | head -12
# phase 2: drop the refused names
sed -i '/Get_2/d; s/ Foo_bar//' src/p.gleam
echo "--- phase 2: the rest"
gleam build 2>&1 | head
echo "--- the atoms Gleam's compiled beam actually builds (p:mk/0, p:mku/0):"
erl -noshell -pa build/dev/erlang/p/ebin -eval 'io:format("~p~n~p~n",[p:mk(), p:mku()]), halt().'
echo "--- gleam fn names are already snake_case in source; try a PascalCase fn name:"
printf 'pub fn Foo() { 1 }\n' > src/p.gleam; gleam build 2>&1 | head -8
