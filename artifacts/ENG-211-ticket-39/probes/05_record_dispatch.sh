#!/usr/bin/env bash
# ticket 39 §4 "records and dispatch unmeasured". Hypothesis H5: the record tag test bsc emits on every
# call of a PRIVATE function (ticket 59's asymmetry) costs >=10% in a record-passing hot loop.
# Falsified if "with tag test" vs "no tag test" rel-min stays within the no-guard/no-guard noise control.
# bsc side = shimmed bsc (00_build_shim_bsc.sh) over RecLoop/RecLoop.bs, REAL emitted code; Erlang sides hand-written.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
W=/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/bsc39; O=$W/v05; rm -rf $O; mkdir -p $O
erl -noshell -pa $W/ebin -eval 'bsc:main(["-o","'$O'","'$HERE'/RecLoop"]),halt().'
erlc -o $O "$HERE/recloop_erl.erl" "$HERE/bench_rec.erl"
(cd $O && erlc +from_abstr -S RecLoop.abstr && echo "tag tests in bsc Spin: $(sed -n "/function, 'Spin'/,/^\$/p" RecLoop.S | grep -c "atom,'RecLoop.Acc'}\]")  beam bytes: $(stat -c%s RecLoop.beam)")
erl -noshell -pa $O -s bench_rec main
