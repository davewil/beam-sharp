#!/usr/bin/env bash
# Variants of the SAME programs differing in ONE compile option, timed together in the shuffled harness.
#   erl / bs          : defaults (bsc compiles with [from_abstr, debug_info])
#   *+inline          : add `inline` (what Gleam's generated .erl declares on line 2)
#   *+no_type_opt     : switch the compiler's type-based optimisation OFF (removes {tr,...} annotations)
R=/home/user/beam-sharp; B=$R/artifacts/39/build; O=$B/var; rm -rf $O; mkdir -p $O/{erl,erl_inl,erl_not,bs,bs_inl,bs_not}
A=$B/day01/Day01.abstr
mk_erl(){ # dir suffix opts  (module renamed so all can be loaded together)
  sed "s/-module(bench_erl)/-module(bench_erl_$2)/" $R/aoc/bench/bench_erl.erl > $O/bench_erl_$2.erl
  erlc $3 -o $O/$1 $O/bench_erl_$2.erl; }
mk_bs(){ # abstr module renamed Day01 -> Day01_<suffix>
  sed "s/'Day01'/'Day01_$2'/g" $A > $O/Day01_$2.abstr
  erl -noshell -eval 'compile:file("'$O'/Day01_'$2'.abstr",[from_abstr,debug_info,{outdir,"'$O'/'$1'"}'"$3"']),halt().' >/dev/null; }
mk_erl erl erl ""; mk_erl erl_inl erli "+inline"; mk_erl erl_not erlnot "+no_type_opt"
mk_bs bs bs ""; mk_bs bs_inl bsi ",inline"; mk_bs bs_not bsnot ",no_type_opt"
P=""; for d in erl erl_inl erl_not bs bs_inl bs_not; do P="$P -pa $O/$d"; done
erlc -o $O $R/artifacts/39/probes/bench2.erl
erl -noshell $P -pa $O -pa $B/day01 -run bench2 main $R/aoc/2025/Day01/input.txt 150 \
  bench_erl_erl:part_two bench_erl_erli:part_two bench_erl_erlnot:part_two \
  "Day01_bs:PartTwo" "Day01_bsi:PartTwo" "Day01_bsnot:PartTwo" bench_gleam:part_two
