#!/usr/bin/env bash
# Probe 4 - what the checker pays. Synthetic tree of N modules, each `using` the previous K; compile the root.
# In-VM timing (timer:tc around bsc:main) so VM boot is excluded. Run: p4_checker_cost.sh BASE_DIR P1_DIR [N] [K]
set -eu
base=$1; p1=$2; N=${3:-120}; K=${4:-6}
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
for i in $(seq 0 $((N-1))); do
  mkdir -p $t/Shop/Billing/Internal/M$i
  { echo "module Shop.Billing.Internal.M$i"; echo
    for j in $(seq 1 $K); do k=$((i-j)); [ $k -ge 0 ] && echo "using Shop.Billing.Internal.M$k"; done
    echo; echo "public int F$i(int x)"; echo "F$i(x) -> x + $i"; } > $t/Shop/Billing/Internal/M$i/m.bs
done
mkdir -p $t/Shop/Billing/Root
{ echo "module Shop.Billing.Root"; echo; for j in $(seq 1 $K); do echo "using Shop.Billing.Internal.M$((N-j))"; done
  echo; echo "public int Go(int x)"; echo "Go(x) -> F$((N-1))(x)"; } > $t/Shop/Billing/Root/r.bs
for v in base p1 base p1; do d=$([ $v = base ] && echo $base || echo $p1)
  erl -noshell -pa $d/ebin -eval "
    Run = fun() -> {T,St} = timer:tc(fun() -> bsc:status([\"--src-root\",\"$t\",\"-o\",\"$t/out_$v\",\"$t/Shop/Billing/Root\"], batch) end), {T,St} end,
    Rs = [Run() || _ <- lists:seq(1,9)], Ts = [T || {T,_} <- Rs], Sts = lists:usort([St || {_,St} <- Rs]),
    io:format(\"$v: N=$N K=$K modules, compile-all ms (9 runs, min/median), exit status ~p: ~p / ~p~n\", [Sts, lists:min(Ts) div 1000, lists:nth(5, lists:sort(Ts)) div 1000]), halt()." 2>&1 | grep -v Warn
done
