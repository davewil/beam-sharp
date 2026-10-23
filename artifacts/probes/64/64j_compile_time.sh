#!/usr/bin/env bash
# PROBE 64j — does carrying a user-declared tagged sibling change bsc compile time measurably?
# A: a module using option<int> in 6 functions.  B: the same 6 functions using Maybe<int> = (:some,int) | :nothing.
# Honest limit: bsc is an escript; VM start-up dominates a one-module compile, so we report the spread and
# whether the two distributions overlap, not a small difference.
set -uo pipefail
: "${BSC:?source env.sh first}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/A" "$W/B"
gen() { # dir, module, typeexpr, none, some-wrapper-open, close, decl
  {
    printf 'module %s\n\n%s\n\n' "$2" "$7"
    for i in 1 2 3 4 5 6; do
      printf 'public %s F%s(int n)\nF%s(0) -> :nothing\nF%s(n) -> %sn + %s%s\n\n' "$3" $i $i $i "$5" $i "$6"
    done
  } > "$1/$2.bs"
}
gen "$W/A" A 'option<int>' x '' '' ''
gen "$W/B" B 'Maybe<int>' x '(:some, ' ')' 'type Maybe<T> = (:some, T) | :nothing'
echo "A (option<int>) compiles:";  "$BSC" --api "$W/A/A.bs" > "$W/a.api"; sed -n 1,2p "$W/a.api"
echo "B (Maybe<int>)  compiles:";  "$BSC" --api "$W/B/B.bs" > "$W/b.api"; sed -n 1,2p "$W/b.api"
t() { local s e; s=$(date +%s%N); "$BSC" -o "$W/out" "$1" >/dev/null 2>&1 || { echo "COMPILE FAILED: $1" >&2; exit 1; }; e=$(date +%s%N); echo $(( (e - s) / 1000000 )); }
mkdir -p "$W/out"
for _ in 1 2 3; do t "$W/A/A.bs" >/dev/null; t "$W/B/B.bs" >/dev/null; done
ra=(); rb=()
for _ in $(seq 1 30); do ra+=("$(t "$W/A/A.bs")"); rb+=("$(t "$W/B/B.bs")"); done
sum() { printf '%s\n' "$@" | sort -n | awk '{a[NR]=$1} END{printf "min=%d median=%d max=%d ms (n=%d)\n", a[1], a[int((NR+1)/2)], a[NR], NR}'; }
echo "A option<int>:  $(sum "${ra[@]}")"
echo "B Maybe<int>:   $(sum "${rb[@]}")"
