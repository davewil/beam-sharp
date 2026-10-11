#!/usr/bin/env bash
# Probe (e), cost: compile-time with and without the check, plus a regression sweep of the example corpus.
# One command: ./e_cost.sh      (N cold runs and M warm runs are tunable: COLD=30 WARM=60)
source ${BS_ENV:-/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh}
PROTO=${PROTO:-/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/60/proto}
EX=/home/user/beam-sharp/compiler/examples
COLD=${COLD:-30}; WARM=${WARM:-60}
OUT=$(mktemp -d)
echo "repo rev $(git -C /home/user/beam-sharp rev-parse --short HEAD); $(nproc) cpus"
ROUNDS=${ROUNDS:-8}; PER=${PER:-10}
echo "### warm: ${ROUNDS} interleaved rounds (a fresh VM per build per round, so machine drift hits every build alike); each does 5 warm-ups then ${PER} timed compiles of examples/Shop/Reports. Pooled n=$((ROUNDS*PER)) per build, microseconds"
declare -A POOL
for r in $(seq 1 $ROUNDS); do
  for v in base A B C; do
    t=$(erl -noshell -pa $PROTO/ebin_$v -eval '
      file:set_cwd("'$EX'"),
      Run=fun() -> {T,_}=timer:tc(fun() -> bsc:file_to_dir("Shop/Reports","'$OUT'") end), T end,
      [Run()||_<-lists:seq(1,5)],
      io:format("~s~n",[string:join([integer_to_list(Run())||_<-lists:seq(1,'$PER')]," ")]), halt().')
    POOL[$v]+="$t "
  done
done
for v in base A B C; do
  echo ${POOL[$v]} | tr ' ' '\n' | grep -v '^$' | sort -n | awk -v v=$v '{a[NR]=$1} END{printf "%-5s median=%d min=%d p10=%d p90=%d max=%d (n=%d)\n", v, a[int((NR+1)/2)], a[1], a[int(NR*0.1)+1], a[int(NR*0.9)], a[NR], NR}'
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
