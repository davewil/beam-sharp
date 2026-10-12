#!/usr/bin/env bash
# 57-05 bsc wall-clock (ms) for one 40-clause signed-domain module, 9 runs each,
# baseline vs variant A (parser fold) vs C (checker arithmetic fold). Variants are built from the
# patches in ../57-04 against a COPY of compiler/. NB: baseline cannot spell signed refinements, so
# the SAME source is used with every refinement written non-negatively (src_pos) as the common case,
# and the signed source (src_neg) is timed on the variants only.
here=$(cd "$(dirname "$0")" && pwd); root=$(cd "$here/../../.." && pwd); p4="$here/../57-04"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
build () { local v=$1 p=$2; mkdir -p "$work/$v/compiler"
  (cd "$root/compiler" && tar cf - --exclude=_build --exclude='*.beam' .) | (cd "$work/$v/compiler" && tar xf -)
  [ -n "$p" ] && (cd "$work/$v" && patch -s -p1 < "$p"); (cd "$work/$v/compiler" && rebar3 escriptize >/dev/null 2>&1); }
build base ""; build A "$p4/A-parser-fold.patch"; build C "$p4/C-checker-fold.patch"
gen () { # $1 = lo-sign ('' or '-')
  echo "module M"; for i in $(seq 1 20); do
    echo "type D$i = int where value >= $1$i and value <= $((i+50))"
    echo "public atom S$i(D$i d)"; echo "S$i(d) when d >= $((i+10)) -> :hi"; echo "S$i(d) when d <= $((i+9)) -> :lo"; done; }
mkdir -p "$work/pos/M" "$work/neg/M"; gen "" > "$work/pos/M/a.bs"; gen "-" > "$work/neg/M/a.bs"
t () { local bsc=$1 f=$2 ts=(); for r in 1 2 3 4 5 6 7 8 9; do s=$(date +%s%N); (cd "$work" && "$bsc" "$f" >/dev/null 2>&1); ts+=($(( ($(date +%s%N)-s)/1000000 ))); done
  printf '%s\n' "${ts[@]}" | sort -n | awk '{a[NR]=$1} END{printf "min %d  median %d  max %d ms\n", a[1], a[int((NR+1)/2)], a[NR]}'; }
for v in base A C; do printf '%-5s unsigned source: ' $v; t "$work/$v/compiler/_build/default/bin/bsc" "$work/pos/M/a.bs"; done
for v in base A C; do printf '%-5s signed   source: ' $v; t "$work/$v/compiler/_build/default/bin/bsc" "$work/neg/M/a.bs"; done
printf 'A signed output sanity (empty = compiled): '; (cd "$work" && "$work/A/compiler/_build/default/bin/bsc" "$work/neg/M/a.bs" 2>&1 | head -2); echo
