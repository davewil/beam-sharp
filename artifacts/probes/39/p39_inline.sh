#!/usr/bin/env bash
# Ticket 39 §3.2/3.3. One factor at a time: add or strip `-compile(inline)` and nothing else; each variant in its own VM,
# interleaved over ROUNDS rounds so drift hits every variant equally. Prints min-of-min and median-of-min per variant.
# usage: p39_inline.sh VARDIR INPUT [ROUNDS]
. "$(dirname "$0")/../env.sh"
V=$1; IN=$2; R=${3:-8}; H="$(dirname "$0")"
declare -A MOD=([erl]=bench_erl:part_two [erl_inline]=bench_erl:part_two [bs]=Day01:PartTwo [bs_inline]=Day01:PartTwo [gleam]=bench_gleam:part_two [gleam_noinline]=bench_gleam:part_two)
ORDER="erl erl_inline bs bs_inline gleam gleam_noinline"
for r in $(seq $R); do for v in $ORDER; do
  m=${MOD[$v]%%:*}; f=${MOD[$v]##*:}
  echo "$v $("$H/time_one.escript" "$V/$v" "$m" "$f" "$IN")"
done; done | python3 -I -c '
import sys,collections,statistics
d=collections.defaultdict(list); ans=set()
for l in sys.stdin:
    v,a,mn,md=l.split(); d[v].append(float(mn)); ans.add(a)
print("answers seen:",ans)
base=min(statistics.median(x) for x in d.values())
for v in ["erl","erl_inline","bs","bs_inline","gleam","gleam_noinline"]:
    x=d[v]; print("%-16s min-of-min %.2f  median-of-min %.2f  spread %.2f  rel %.3f"%(v,min(x),statistics.median(x),max(x)-min(x),statistics.median(x)/base))
'
