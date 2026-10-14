#!/bin/sh
# runeunit.sh VARIANT_DIR : compile repo tests against variant and run eunit (bsc escript-driven tests will fail: no escript built)
V=$1; S=$(cd "$(dirname "$0")" && pwd); T=$S/tests_$(basename $V); rm -rf $T; mkdir -p $T
erlc -I /home/user/beam-sharp/compiler/include -o $T /home/user/beam-sharp/compiler/test/*.erl 2>&1 | grep -c "rror" 
cd /home/user/beam-sharp/compiler && timeout 900 erl -noshell -pa $S/$V/ebin -pa $T -eval 'Ms=[list_to_atom(filename:basename(F,".beam"))||F<-filelib:wildcard("'$T'/*.beam")], R=eunit:test(Ms,[]), io:format("RESULT ~p~n",[R]), halt().' 2>&1 | tail -15
