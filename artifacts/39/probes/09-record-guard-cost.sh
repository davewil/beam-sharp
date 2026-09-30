#!/usr/bin/env bash
# Cost of the exported-boundary guard (ticket 18 / F3.9) on a 3,000,000-iteration loop.
# RecPub: Spin is `public` (guards emitted on every clause, every recursive call). RecPriv: identical but `private`.
# rec_erl: hand-written Erlang with / without the same guard. (No guard test exists in aoc/bench at all: Day01 is all private.)
R=/home/user/beam-sharp/artifacts/39; O=$R/build/rec
for m in RecPub RecPriv; do $R/probes/bsc.sh -o $O $R/probes/$m; done
erlc -o $O $R/probes/rec_erl.erl; erlc -o $O $R/probes/bench3.erl
erl -noshell -pa $O -run bench3 main 3000000 60 RecPub:Run RecPriv:Run "rec_erl:run_noguard" "rec_erl:run_guard"
