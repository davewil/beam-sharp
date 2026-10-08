#!/bin/bash
# P7b: in-VM compile time (microseconds via timer:tc around bsc:status/2, VM boot excluded). One VM per (config, round);
# 3 warm-up compiles discarded, then RUNS timed. Rounds interleave the configs so drift hits all of them.
RUNS=${RUNS:-12}; ROUNDS=${ROUNDS:-2}
T=$(mktemp -d); SCR=$(dirname "$(readlink -f "$0")")
for n in 50 200; do for m in base baseB B C; do "$SCR/gen_tree.sh" $m $n $T/$m$n; done; done
cat > $T/drv.erl <<'ERL'
-module(drv).
-export([main/1]).
main([Dir, Runs | Mods]) ->
    ok = file:set_cwd(Dir),
    Args = ["--src-root", "."] ++ Mods,
    [0 = bsc:status(Args, batch) || _ <- lists:seq(1,3)],
    Ts = [begin {T, 0} = timer:tc(fun() -> bsc:status(Args, batch) end), T end
          || _ <- lists:seq(1, list_to_integer(Runs))],
    io:format("~s~n", [string:join([integer_to_list(X div 1000) || X <- Ts], " ")]).
ERL
(cd $T && erlc drv.erl)
dirs() { (cd $1 && find . -name a.bs | xargs -n1 dirname | sed 's#^\./##' | sort | tr '\n' ' '); }
CFG=("baseline-on-A-shaped|base|/tmp/bsbuild/ebin" "A|base|/tmp/bsb_60_a/ebin" "baseline-on-B-shaped|baseB|/tmp/bsbuild/ebin" "B|B|/tmp/bsb_60_b/ebin" "baseline-on-C-shaped|base|/tmp/bsbuild/ebin" "C|C|/tmp/bsb_60_c/ebin")
for n in 50 200; do
  echo "### N=$n modules (in-VM ms per full compile, $RUNS runs x $ROUNDS VMs)"
  declare -A S; S=()
  for ((r=0;r<ROUNDS;r++)); do for c in "${CFG[@]}"; do IFS='|' read lab tree eb <<<"$c"
    d=$T/$tree$n
    S[$lab]+="$(erl -noshell -pa $eb $T -eval 'drv:main(init:get_plain_arguments()), halt(0).' -extra $d $RUNS $(dirs $d) 2>/dev/null | tail -1) "; done; done
  for c in "${CFG[@]}"; do lab=${c%%|*}; python3 -I - "$lab" ${S[$lab]} <<'PY'
import sys,statistics as s
k=sys.argv[1]; v=sorted(map(int,sys.argv[2:]))
print(f"{k:24s} n={len(v)} median={s.median(v):.0f}ms min={v[0]} max={v[-1]} IQR={v[len(v)*3//4]-v[len(v)//4]}")
PY
  done
done
rm -rf $T
