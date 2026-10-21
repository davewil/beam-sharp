#!/bin/sh
export BSC=/home/user/beam-sharp/compiler/_build/default/bin/bsc; . /home/user/beam-sharp/artifacts/probes/env.sh
W=$(mktemp -d); STD=$GLEAM_STDLIB
mkdir -p $W/g/src/gleam && cd $W/g
cat > gleam.toml <<T
name = "g"
version = "1.0.0"
[dependencies]
gleam_stdlib = { path = "$STD" }
T
cat > src/gleam/list.gleam <<'G'
pub fn length(_x: List(a)) -> Int { 99 }
pub fn mine() -> Int { 1 }
G
cat > src/g.gleam <<'G'
import gleam/list
pub fn main() { list.length([1, 2, 3]) }
G
gleam build 2>&1 | tail -5; echo "gleam-build-exit=$?"
echo "--- beams named gleam@list"; find build -name 'gleam@list*' | sort
echo "--- sizes/md5"; find build -name 'gleam@list.beam' -exec md5sum {} \;
echo "--- g.erl call"; grep -n "list" build/dev/erlang/g/_gleam_artefacts/g.erl | head -5
for order in "g gleam_stdlib" "gleam_stdlib g"; do
  set -- $order
  P=""; for p in $order; do P="$P build/dev/erlang/$p/ebin"; done
  printf 'code path order [%s]: ' "$order"
  erl -noshell -pa $P -eval 'io:format("~p ~p~n",[g:main(), code:which(gleam@list)]),halt().'
done
echo "--- gleam_stdlib/ebin also has gleam@list.beam?"; ls build/dev/erlang/*/ebin | grep -c 'gleam@list.beam'
echo "--- does gleam test/run use which path order?"
gleam run 2>&1 | tail -3
echo "--- what does stdlib's own code do (e.g. gleam@list:length vs gleam@string using list)"
erl -noshell -pa build/dev/erlang/g/ebin build/dev/erlang/gleam_stdlib/ebin -eval 'io:format("string.join: ~p~n",[catch gleam@string:join([<<"a">>,<<"b">>],<<",">>)]), halt().'
erl -noshell -pa build/dev/erlang/gleam_stdlib/ebin build/dev/erlang/g/ebin -eval 'io:format("string.join (stdlib first): ~p~n",[catch gleam@string:join([<<"a">>,<<"b">>],<<",">>)]), halt().'
