#!/bin/bash
# The repo's own eunit modules (compiler/test/*_tests.erl) run against each scratch build.
# Caveats: OTP 25; lexer shim gives every column 1, so column/position-sensitive tests fail on ALL builds;
# the 3 tests that drive the bsc escript fail on ALL builds. The probe is the DIFFERENCE in the failing set vs baseline.
W=${W:-/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/w57}
T=/home/user/beam-sharp/compiler/test
for V in baseline A1 A2 B1 B2 B3; do
  E=$W/v_$V/ebin; [ $V = baseline ] && E=$W/ebin
  O=$W/t_$V; rm -rf $O; mkdir -p $O
  erlc -o $O -I /home/user/beam-sharp/compiler/include -pa $E $T/*.erl >/dev/null 2>$O/compile.err
  cat > $O/run.erl <<'X'
-module(run).
-export([main/1]).
main([Dir]) ->
  Mods = [list_to_atom(filename:basename(F, ".beam")) || F <- filelib:wildcard(Dir ++ "/*_tests.beam")],
  R = [{M, (catch eunit:test(M, []))} || M <- lists:sort(Mods)],
  Bad = [M || {M, X} <- R, X =/= ok],
  io:format("modules=~p failing=~p~n~p~n", [length(Mods), length(Bad), Bad]).
X
  erlc -o $O $O/run.erl
  ( cd $W && timeout 900 erl -noshell -pa $E -pa $O -eval 'run:main(["'$O'"]), halt().' > $O/result.txt 2>&1 )
  echo "== $V"; tail -3 $O/result.txt; echo "test modules not compiled: $(grep -c . $O/compile.err)"
done
