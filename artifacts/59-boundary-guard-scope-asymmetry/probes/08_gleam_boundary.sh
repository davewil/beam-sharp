#!/bin/bash
# Probe 08 (survey): Gleam 1.12.0 (tickets measured 1.18.1). Build a project with a pub/private/opaque
# mix, show the generated Erlang has NO runtime guard on pub, private or opaque, then drive
# it with the same forged values as probe 02. Needs no hex deps (gleam.toml has none).
cd "$(dirname "$0")"; . ./lib.sh
G=/tmp/tc/gleam; W=$(mktemp -d); cd $W; $G new gp >/dev/null 2>&1; cd gp
printf 'name = "gp"\nversion = "1.0.0"\n[dependencies]\n' > gleam.toml; rm -rf test
cat > src/gp.gleam <<'GL'
pub type Order { Order(id: Int, total: Int) }
pub opaque type Token { Token(n: Int) }
pub type Cart { Cart(item: Order, qty: Int) }
fn inner(o: Order) -> Int { o.total }
fn scale(n: Int) -> Int { n * 2 }
fn big(n: Int) -> Bool { n >= 100 }
pub fn direct(o: Order) -> Int { inner(o) }
pub fn nested(c: Cart) -> Int { inner(c.item) }
pub fn field(c: Cart) -> Int { scale(c.qty) }
pub fn is_big(c: Cart) -> Bool { big(c.qty) }
pub fn make(n: Int) -> Token { Token(n) }
pub fn unwrap(t: Token) -> Int { t.n }
pub fn add(a: Int, b: Int) -> Int { a + b }
GL
$G build --target erlang 2>&1 | grep -v "^ *$"
echo "=== generated Erlang (the whole module body) ==="
grep -v '^-file\|^$' build/dev/erlang/gp/_gleam_artefacts/gp.erl
echo "=== guard count (when / is_integer / is_map / map_get) in generated code ==="
grep -c 'when\|is_integer\|is_map\|map_get' build/dev/erlang/gp/_gleam_artefacts/gp.erl
echo "=== forged calls from Erlang ==="
cat > drv.erl <<'ERL'
-module(drv).
-export([main/0]).
r(L,F) -> V = try {ok,F()} catch C:E:St -> [{M,Fn,A,_}|_] = St, {C,E,{in,M,Fn,A}} end, io:format("~-40s ~p~n",[L,V]).
main() ->
  r("direct({order,1,7}) good",          fun() -> gp:direct({order,1,7}) end),
  r("direct(#{k=>v}) forged",            fun() -> gp:direct(#{k=>v}) end),
  r("nested({cart,#{},3}) forged item",  fun() -> gp:nested({cart,#{},3}) end),
  r("field({cart,_,1.5}) forged qty",    fun() -> gp:field({cart,{order,1,7},1.5}) end),
  r("is_big({cart,_,foo}) forged qty",   fun() -> gp:is_big({cart,{order,1,7},foo}) end),
  r("add(1.5,2.5)",                      fun() -> gp:add(1.5,2.5) end),
  r("unwrap(#{}) on an opaque Token",    fun() -> gp:unwrap(#{}) end).
ERL
erlc drv.erl && erl -noshell -pa build/dev/erlang/gp/ebin -pa . -eval 'drv:main(), halt().'
