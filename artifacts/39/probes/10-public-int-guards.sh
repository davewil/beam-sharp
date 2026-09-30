#!/usr/bin/env bash
# Same Day01 program with EVERY function `public` (so each clause carries is_integer guards on each int param).
# Compare to the private build in the shuffled harness, together with handwritten Erlang and Erlang+same guards' equivalent.
R=/home/user/beam-sharp/artifacts/39; B=$R/build; O=$B/d1pub; mkdir -p $O
$R/probes/bsc.sh -o $O $R/probes/Day01Pub
echo "--- Spin/4 guard as emitted (public):"
erl -noshell -eval '{ok,F}=file:consult("'$O'/Day01Pub.abstr"),[io:format("~p~n",[X])||X={function,_,N,_,_}<-F,N=:='"'Spin'"'],halt().' | head -28
erl -noshell -pa $O -pa $B/day01 -run bench2 main /home/user/beam-sharp/aoc/2025/Day01/input.txt 150 bench_erl:part_two "Day01:PartTwo" "Day01Pub:PartTwo"
