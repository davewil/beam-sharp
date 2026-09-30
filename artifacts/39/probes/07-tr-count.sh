#!/usr/bin/env bash
# Does +no_type_opt really remove the {tr,...} annotations / var_info? Count them; also count instructions in Spin+Wrap+Hit.
R=/home/user/beam-sharp; B=$R/artifacts/39/build; O=$B/trc; mkdir -p $O; cp $R/aoc/bench/bench_erl.erl $O/
for o in "" "+no_type_opt" "+inline"; do
  n=$(echo "$o" | tr -d '+ '); [ -z "$n" ] && n=default
  erlc $o -S -o $O/ $O/bench_erl.erl && mv $O/bench_erl.S $O/erl_$n.S
  echo "erlc $o: {tr,=$(grep -o '{tr,' $O/erl_$n.S | wc -l)  var_info=$(grep -c var_info $O/erl_$n.S)  gc_bif=$(grep -c gc_bif $O/erl_$n.S)  calls=$(grep -c '{call' $O/erl_$n.S)"
done
echo "--- spin under +inline:"; awk '/^\{function, spin/,/^\{function, sign/' $O/erl_inline.S | grep -v '^$'
