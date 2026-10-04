#!/usr/bin/env bash
# Survey (what do neighbours EMIT to get the optimiser to do its job?) and compile-time/size measurements.
. "$(dirname "$0")/env.sh"; B=$REPO/aoc/bench
G=$W/gleam/build/dev/erlang/bench_gleam/_gleam_artefacts/bench_gleam.erl
echo "### Gleam $(/tmp/tc/gleam --version): generated Erlang header (full file saved as probes/16_gleam_generated.erl)"; cp $G $A/probes/16_gleam_generated.erl
sed -n 1,5p $G; echo "...  every fn has: $(grep -c '^-spec' $G) -spec lines; inline attribute present: $(grep -c 'inline' $G)"
echo; echo "### Elixir 1.14 (OTP25): attributes in generated forms (work/ex_forms.term)"; grep -n "{attribute,1,compile\|inline" $W/ex_forms.term | head -3; echo "spec forms in Elixir output: $(grep -c "{attribute,1,spec" $W/ex_forms.term) (that one is __info__/1, Elixir adds no spec for defp)"
echo; echo "### compile time, 7 reps each, wall seconds (min / median)"
t() { for i in 1 2 3 4 5 6 7; do s=$(date +%s%N); "$@" >/dev/null 2>&1; e=$(date +%s%N); echo $(( (e-s)/1000000 )); done | sort -n | awk '{a[NR]=$1} END{print a[1]" ms min, "a[int(NR/2)+1]" ms median"}'; }
mkdir -p $W/p16
echo -n "erlc bench_erl.erl                 : "; t erlc -o $W/p16 $B/bench_erl.erl
echo -n "erlc +from_abstr Day01.abstr       : "; t erlc +from_abstr -o $W/p16 $W/ebin/Day01.abstr
echo -n "erlc +from_abstr +inline           : "; t erlc +from_abstr +inline -o $W/p16 $W/ebin/Day01.abstr
echo -n "bsc -o (parse+check+emit+erlc)     : "; t $BSC -o $W/p16 $B/Day01
echo -n "erl VM boot alone (baseline)       : "; t erl -noshell -eval 'halt().'
echo; echo "### beam bytes"; ls -l $W/ebin/{bench_erl,bench_gleam,Day01,Elixir.BenchEx}.beam | awk '{print $5, $9}'
