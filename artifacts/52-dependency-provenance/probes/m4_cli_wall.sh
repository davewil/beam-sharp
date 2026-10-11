#!/usr/bin/env bash
# (d) CLI wall-clock: bare VM boot, stock bsc compiling Dep, prototype bsc compiling DeclA (same 3 usings, + declarations and check). 20 runs each.
H="$(cd "$(dirname "$0")" && pwd)"; FX="$H/fixtures/_fx"
[ -d "$FX/libA" ] || "$H/fixtures/build-fixtures.sh" >/dev/null
[ -d "$H/fixtures/_proto/ebin" ] || "$H/../prototype/build.sh" >/dev/null
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
ELIXLIB=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/mm/root/envs/tc/lib/elixir/lib
export ERL_LIBS="$FX/libA:$ELIXLIB"
STOCK=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/bsc-ebin
t() { # label cmd...
  local label="$1"; shift; local ts=()
  for i in $(seq 20); do s=$(date +%s%N); "$@" >/dev/null 2>&1; e=$(date +%s%N); ts+=($(( (e-s)/1000 ))); done
  printf '%s\n' "${ts[@]}" | sort -n | awk -v l="$label" '{a[NR]=$1} END{printf "   %-52s median %7d us  min %7d  max %7d  (n=%d)\n", l, a[int((NR+1)/2)], a[1], a[NR], NR}'
}
echo "### CLI wall clock (includes VM boot)"
t "bare VM: erl -noshell -eval halt" erl -noshell -eval 'halt().'
BSC_EBIN="$STOCK" t "stock bsc, compile Dep (no declarations)" "$H/bsc.sh" -o "$FX/m4a" --src-root "$H/bs" "$H/bs/Dep"
BSC_EBIN="$H/fixtures/_proto/ebin" t "prototype bsc, compile DeclA (3 declarations + check)" "$H/bsc.sh" -o "$FX/m4b" --src-root "$H/bs" "$H/bs/DeclA"
BSC_EBIN="$H/fixtures/_proto/ebin" t "prototype bsc, compile Dep (no declarations: check path only)" "$H/bsc.sh" -o "$FX/m4c" --src-root "$H/bs" "$H/bs/Dep"
