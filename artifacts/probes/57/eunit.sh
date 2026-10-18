#!/bin/bash
# Runs compiler/test eunit modules against a variant build ($1 = c | c57_checker | c57_parser).
. "$(dirname "$0")/../env.sh"
v=${1:-c}; T=$S/eu_$v; rm -rf $T; mkdir -p $T
cp -r $S/$v/ebin/* $T/
R=$(cd "$(dirname "$0")/../../.." && pwd)
erlc -o $T +debug_info $R/compiler/test/*.erl 2>&1 | grep -i 'error' | head -3
cd $R/compiler   # tests find examples/ relative to compiler/
erl -noshell +pc unicode -pa $T -eval '
Ms=[list_to_atom(filename:basename(F,".beam")) || F <- filelib:wildcard("'$T'/*_tests.beam")],
R=eunit:test(Ms,[verbose]), io:format("RESULT ~p over ~p test modules~n",[R,length(Ms)]), halt().' 2>&1 | tail -${EU_TAIL:-15}
