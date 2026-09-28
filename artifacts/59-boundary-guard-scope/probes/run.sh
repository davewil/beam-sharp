#!/bin/sh
# Regenerates every .out in this directory. Run from anywhere: sh run.sh
# Nothing here runs bsc (it cannot be built on OTP 25). See brief.md "What I could not verify".
cd "$(dirname "$0")" || exit 1
rm -rf work && mkdir work
./versions.sh > versions.out 2>&1
erlc -o work p01_shapes.erl && (cd work && erl -noshell -pa . -eval 'p01_shapes:go(), halt().') > p01_shapes.out 2>&1
[ -f p03_time.erl ]   && erlc -o work p03_time.erl   && (cd work && erl -noshell -pa . -eval 'p03_time:go(), halt().')   > p03_time.out 2>&1
[ -f p04_hole.erl ]   && erlc -o work p04_hole.erl   && (cd work && erl -noshell -pa . -eval 'p04_hole:go(), halt().')   > p04_hole.out 2>&1
[ -f p05_dialyzer.sh ] && sh p05_dialyzer.sh > p05_dialyzer.out 2>&1
[ -f p06_elixir.sh ]  && sh p06_elixir.sh  > p06_elixir.out 2>&1
[ -f p07_elm.sh ]     && sh p07_elm.sh     > p07_elm.out 2>&1
[ -f p08_corpus_count.py ] && (cd ../../.. && python3 artifacts/59-boundary-guard-scope/probes/p08_corpus_count.py) > p08_corpus_count.out 2>&1
echo "done"
