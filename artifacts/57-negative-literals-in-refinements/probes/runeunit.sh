#!/usr/bin/env bash
v=$1; S=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad
source $S/env.sh; cd $S/57/tree-$v/_build/test/lib/bsc
mods=$(ls test/*.erl | xargs -n1 basename | sed 's/\.erl$//' | tr '\n' ',' | sed 's/,$//')
timeout 900 erl -noshell -pa ../../../../ebin -pa ../../../../tebin -eval "R = eunit:test([$mods], []), io:format(\"RESULT ~p~n\",[R]), halt()." > $S/57/eunit-$v.log 2>&1 </dev/null
tail -5 $S/57/eunit-$v.log
