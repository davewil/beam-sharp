#!/usr/bin/env bash
# 60/d : compile-time overhead of the visibility check. 60 modules, each `using` the previous 5 (<=300 edges).
# configs: A repo bsc, no markers | B patched bsc, no markers | C patched bsc, every 3rd module `internal` (all edges legal)
here=$(cd "$(dirname "$0")" && pwd)
repo_bsc=${BSC:-$here/../../../../compiler/_build/default/bin/bsc}
proto_bsc=$("$here/../proto/build.sh") || exit 1
N=${N:-60}; RUNS=${RUNS:-9}
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT
gen () { # dir marked
  local d=$1 marked=$2
  for j in $(seq 0 $((N-1))); do
    mkdir -p "$d/App/M$j"
    { echo "module App.M$j"; echo
      for k in 1 2 3 4 5; do p=$((j-k)); [ $p -ge 0 ] && echo "using App.M$p"; done
      echo; echo "public int F$j(int n)"
      if [ $j -ge 1 ]; then echo "F$j(n) -> F$((j-1))(n) + 1"; else echo "F$j(n) -> n"; fi
    } > "$d/App/M$j/F$j.bs"
    # every module gets an index.bs so file counts match across configs; only `marked` adds `internal`
    if [ "$marked" = 1 ] && [ $((j%3)) -eq 0 ]; then printf 'module App.M%s\n\ninternal\n' $j > "$d/App/M$j/index.bs"; else printf 'module App.M%s\n' $j > "$d/App/M$j/index.bs"; fi
  done
}
gen "$w/plain" 0; gen "$w/marked" 1
echo "modules=$N  using-edges=$(grep -rh '^using' $w/plain | wc -l)  internal-modules=$(grep -rl '^internal' $w/marked | wc -l)"
time_cfg () { # name bsc root
  local name=$1 bsc=$2 root=$3 ts=() 
  for r in $(seq 1 $RUNS); do
    o=$(mktemp -d); s=$(date +%s%N)
    (cd "$root" && "$bsc" -o "$o" --src-root . $(ls -d App/M* )) >/dev/null 2>"$w/err" || { echo "FAILED"; cat "$w/err"|head -5; return 1; }
    e=$(date +%s%N); ts+=($(( (e-s)/1000000 ))); rm -rf "$o"
  done
  sorted=($(printf '%s\n' "${ts[@]}" | sort -n))
  echo "$name runs=$RUNS min=${sorted[0]}ms median=${sorted[$((RUNS/2))]}ms max=${sorted[$((RUNS-1))]}ms"
}
time_cfg "A repo-bsc / plain      " "$repo_bsc" "$w/plain"
time_cfg "B patched / plain       " "$proto_bsc" "$w/plain"
time_cfg "C patched / 20 internal " "$proto_bsc" "$w/marked"
time_cfg "A repo-bsc / plain      " "$repo_bsc" "$w/plain"
time_cfg "B patched / plain       " "$proto_bsc" "$w/plain"
time_cfg "C patched / 20 internal " "$proto_bsc" "$w/marked"
