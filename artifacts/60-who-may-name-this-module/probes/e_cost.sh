#!/usr/bin/env bash
# Probe (e), cost: compile-time with and without the check, plus a regression sweep of the example corpus.
# One command: ./e_cost.sh      (N cold runs and M warm runs are tunable: COLD=30 WARM=60)
source ${BS_ENV:-/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh}
PROTO=${PROTO:-/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/60/proto}
EX=/home/user/beam-sharp/compiler/examples
COLD=${COLD:-30}; WARM=${WARM:-60}
OUT=$(mktemp -d)
echo "repo rev $(git -C /home/user/beam-sharp rev-parse --short HEAD); $(nproc) cpus"
echo "### warm: in one VM, ${WARM} timed compiles of examples/Shop/Reports (2 using lines, 2 modules) after 5 warm-ups, microseconds"
for v in base A B C; do
  erl -noshell -pa $PROTO/ebin_$v -eval '
  {ok,Cwd}=file:get_cwd(), file:set_cwd("'$EX'"),
  Run=fun() -> {T,_}=timer:tc(fun() -> bsc:file_to_dir("Shop/Reports","'$OUT'") end), T end,
  [Run()||_<-lists:seq(1,5)],
  Ts=lists:sort([Run()||_<-lists:seq(1,'$WARM')]), N=length(Ts),
  io:format("~-5s median=~p min=~p p90=~p max=~p  (n=~p)~n",["'$v'",lists:nth(N div 2,Ts),hd(Ts),lists:nth(round(N*0.9),Ts),lists:last(Ts),N]),
  file:set_cwd(Cwd), halt().'
done
echo "### cold: ${COLD} separate 'bsc' process launches each (includes VM boot), milliseconds"
for v in base A B C; do
  ts=()
  for i in $(seq 1 $COLD); do
    s=$(date +%s%N)
    (cd $EX && erl -noshell -pa $PROTO/ebin_$v -eval 'bsc:main(["-o","'$OUT'","Shop/Reports"])' >/dev/null 2>&1)
    e=$(date +%s%N); ts+=($(( (e-s)/1000000 )))
  done
  printf '%s\n' "${ts[@]}" | sort -n | awk -v v=$v '{a[NR]=$1} END{printf "%-5s median=%d min=%d p90=%d max=%d (n=%d)\n", v, a[int((NR+1)/2)], a[1], a[int(NR*0.9)], a[NR], NR}'
done
echo "### regression sweep: every module dir under compiler/examples (not exemplars/), exit status per variant"
cd $EX
dirs=$(find . -name '*.bs' -not -path './exemplars/*' -printf '%h\n' | sort -u | sed 's|^\./||')
for v in base A B C; do
  ok=0; bad=0; badlist=""
  for d in $dirs; do
    if erl -noshell -pa $PROTO/ebin_$v -eval 'bsc:main(["--src-root",".","-o","'$OUT'","'$d'"])' >/dev/null 2>&1; then ok=$((ok+1)); else bad=$((bad+1)); badlist="$badlist $d"; fi
  done
  echo "$v: $ok compile, $bad do not${badlist:+ ($badlist)}"
done
