#!/usr/bin/env bash
# ticket 39 §3.2. Hypothesis H2: removing the optimizer's {tr,..} type annotations from an otherwise
# identical Erlang loop slows it by >=10% (the ticket's 6.14 vs 5.30). Control d2 == d measures noise. Falsified if the stripped/default
# min-time ratio stays <1.10 on interleaved runs. Variants: default; +no_type_opt; +no_ssa_opt.
# Also counts {tr,..} operands and instructions per variant (so we know the variants differ at all).
set -e
W=/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/bsc39/v02; rm -rf $W; mkdir -p $W/d $W/nt $W/ns
B=/home/user/beam-sharp/aoc/bench
erlc -o $W/d $B/bench_erl.erl; erlc +no_type_opt -o $W/nt $B/bench_erl.erl; erlc +no_ssa_opt -o $W/ns $B/bench_erl.erl
cp -r $W/d $W/d2   # CONTROL: byte-identical to d; its rel-min vs d is the noise floor
for v in d nt ns; do
  case $v in d) o="";; nt) o="+no_type_opt";; ns) o="+no_ssa_opt";; esac
  erlc $o -S -o $W/$v $B/bench_erl.erl
  printf "%-4s %-14s tr-operands=%s var_info=%s instr-lines=%s beam-bytes=%s\n" $v "$o" \
    "$(grep -c '{tr,' $W/$v/bench_erl.S)" "$(grep -c var_info $W/$v/bench_erl.S)" \
    "$(grep -cE '^    \{(gc_bif|test|move|call|call_last|allocate|put_tuple2|return|test_heap|init_yregs|deallocate|call_only)' $W/$v/bench_erl.S)" "$(stat -c%s $W/$v/bench_erl.beam)"
done
cp "$(dirname "$0")/bench_variants.erl" $W/ && erlc -o $W $W/bench_variants.erl
erl -noshell -pa $W -s bench_variants main $W /home/user/beam-sharp/aoc/2025/Day01/input.txt
