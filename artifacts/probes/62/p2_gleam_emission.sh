#!/usr/bin/env bash
# Ticket 62: ticket 10 §7 says "Gleam downcases when it emits to the BEAM - PascalCase becomes snake_case".
# Test what Gleam actually does to (a) a function, (b) a type constructor, (c) a module with PascalCase
# in its name, (d) an @external naming a PascalCase foreign function. Needs gleam on PATH.
set -u
export PATH=/tmp/tools:$PATH
W=$(mktemp -d); cd "$W"
mkdir -p proj/src && cd proj
cat > gleam.toml <<'EOF'
name = "shop"
version = "1.0.0"
target = "erlang"
EOF
cat > src/shop.gleam <<'EOF'
pub type Order {
  Order(id: Int, total: Int)
  NoOrder
}
pub fn new_order(id: Int) -> Order { Order(id, 0) }
@external(erlang, "Shop", "New")
pub fn foreign_new(id: Int) -> Order
EOF
gleam build 2>&1 | tail -5
B=$(find build -name 'shop.beam' | head -1); echo "beam: $B"
erl -noshell -eval '{ok,{_,[{exports,E}]}} = beam_lib:chunks("'"$B"'", [exports]), io:format("exports: ~p~n",[E]),
  io:format("constructor value: ~p~n",[(list_to_atom("shop")):new_order(7)]), halt().' -pa "$(dirname "$B")"
echo "--- a module whose file name is PascalCase / a path:"
mkdir -p src/deep && cat > src/deep/nested.gleam <<'EOF'
pub fn f() -> Int { 1 }
EOF
gleam build 2>&1 | tail -2; find build -name '*.beam' | sed 's|.*/||'
echo "--- Gleam rejects a PascalCase module file name?"
cp src/shop.gleam src/Shop2.gleam; gleam build 2>&1 | grep -i -E 'error|invalid|module name' | head -3; rm src/Shop2.gleam
echo "--- run the @external call into a PascalCase Erlang export (ticket 62 only measured that it compiles)"
mkdir -p ext && cat > ext/Shop.erl <<'EOF'
-module('Shop').
-export(['New'/1]).
'New'(Id) -> #{'Kind' => 'Shop.Order', 'Id' => Id, 'Total' => 0}.
EOF
erlc -o ext ext/Shop.erl
erl -noshell -pa ext -pa "$(dirname "$B")" -eval 'io:format("shop:foreign_new(3) = ~p~n",[shop:foreign_new(3)]), halt().'
