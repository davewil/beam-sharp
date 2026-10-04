#!/bin/sh
# Cost of the compile-time check, warm (inside one VM) and cold (first call in a fresh VM, which is
# what `bsc` pays: one VM per invocation), against bsc's own wall time on the same program.
. "$(dirname "$0")/env.sh"
here=$(cd "$(dirname "$0")" && pwd)
erlc -o $W $here/prov.erl $here/prov_check.erl
LIBS=$W/greeter_build/dev/lib:$W/rlib_src/_build/default/lib:$W/glib_src/build/dev/erlang
# a synthetic 500-application path, to see how a miss scales with path length
rm -rf $W/big && mkdir -p $W/big && for i in $(seq 1 500); do mkdir -p $W/big/app$i-1.0.0/ebin; done
echo "== warm, inside one VM (microseconds per call)"
for L in "$LIBS" "$LIBS:$W/big"; do
  echo "-- ERL_LIBS entries: $(echo $L | tr ':' '\n' | wc -l) lib dirs; code path length reported below"
  ERL_LIBS=$L erl -noshell -pa $W -eval '
    io:format("  code:get_path() length = ~p~n", [length(code:get_path())]),
    G = '"'"'Elixir.Greeter'"'"', N = 2000,
    prov:bench("code:lib_dir(greeter)  hit", N, fun() -> code:lib_dir(greeter) end),
    prov:bench("code:lib_dir(req)      miss", N, fun() -> code:lib_dir(req) end),
    prov:bench("code:which(Greeter)    hit", N, fun() -> code:which(G) end),
    prov:bench("code:which(Greeter.Nope) miss", N, fun() -> code:which('"'"'Elixir.Greeter.Nope'"'"') end),
    prov:bench("prov:check(greeter, Greeter) (option A, per block)", N, fun() -> prov:check(greeter, G) end),
    prov:bench("prov:app_of(Greeter)  path shape", N, fun() -> prov:app_of(G) end),
    prov:bench("file:consult greeter.app + read vsn/applications", 500, fun() -> prov:app_modules(greeter) end),
    prov:bench("application:load+unload(greeter)", 500, fun() -> application:load(greeter), application:unload(greeter) end),
    prov:bench("prov_check:closure(greeter) transitive apps", 500, fun() -> prov_check:closure(greeter) end),
    io:format("  closure(greeter) = ~p~n", [prov_check:closure(greeter)]),
    halt().'
done
echo "== closure when elixir is NOT on the path (what a transitive check would flag)"
ERL_LIBS=$LIBS erl -noshell -pa $W -eval 'io:format("  closure(greeter) = ~p~n", [prov_check:closure(greeter)]), halt().'
echo "== closure when Elixir 1.14 IS on the path"
ERL_LIBS=$LIBS:/usr/lib/elixir/lib erl -noshell -pa $W -eval 'io:format("  closure(greeter) = ~p~n", [prov_check:closure(greeter)]), halt().'
echo "== cold: first call in a fresh VM (median of 15 VMs, microseconds), 3 using-blocks worth"
cat > $W/cold.erl <<'E'
-module(cold).
-export([go/0]).
go() ->
    T0 = erlang:monotonic_time(nanosecond),
    [begin code:lib_dir(A), code:which(M) end || {A, M} <- [{greeter,'Elixir.Greeter'},{greeter,'Elixir.Greeter.Extra'},{rlib,rlib}]],
    T1 = erlang:monotonic_time(nanosecond),
    io:format("~p~n", [(T1 - T0) / 1000]), halt().
E
erlc -o $W $W/cold.erl
for i in $(seq 1 15); do ERL_LIBS=$LIBS erl -noshell -pa $W -eval 'cold:go().'; done | sort -n | sed -n 8p | sed 's/^/  3 blocks, cold first call, median: /'
for i in $(seq 1 15); do ERL_LIBS=$LIBS:$W/big erl -noshell -pa $W -eval 'cold:go().'; done | sort -n | sed -n 8p | sed 's/^/  3 blocks, cold, +500-entry path, median: /'
echo "== bsc wall time for the Greet program (compile+run), ms, median of 15"
cd $W/greet
for i in $(seq 1 15); do s=$(date +%s%N); ERL_LIBS=$LIBS $BSC -o out Greet Hi '"bob"' >/dev/null 2>&1; e=$(date +%s%N); echo $(( (e - s) / 1000000 )); done | sort -n | sed -n 8p | sed 's/^/  bsc end to end: /'
for i in $(seq 1 15); do s=$(date +%s%N); ERL_LIBS=$LIBS $BSC -o out Greet >/dev/null 2>&1; e=$(date +%s%N); echo $(( (e - s) / 1000000 )); done | sort -n | sed -n 8p | sed 's/^/  bsc compile only: /'
