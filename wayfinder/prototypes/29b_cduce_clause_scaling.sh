#!/usr/bin/env bash
# 29b — what CDuce's checker costs when the subject is an integer interval and the
# clause count is the one ticket 04 flagged as pathological.
#
# Ticket 20 §5 admitted intervals as "affordable", on the argument that they are a
# *domain* added to the algebra rather than a *solving* problem. 29a confirms the algebra
# is exact. This measures the cost, because ticket 04 found the exhaustiveness algorithm
# has no complexity bound, and ticket 20's own hand-over to the walking skeleton asks for
# "the residual-computation cost at showcase clause counts".
#
# Two shapes, because they stress different halves of the checker:
#   partition  — N+2 disjoint clauses that exactly cover Int with no catch-all. The
#                residual empties only after every clause is subtracted: the
#                exhaustiveness path, and the shape ticket 20 §5 says intervals buy.
#   overlap    — N clauses each of which contains the next, so every clause after the
#                first is unreachable: the redundancy path.
#
# All timing happens *inside* one container, because container start-up on emulated
# amd64 is ~1.2 s and swamped the signal when each run paid it. Absolute times are under
# emulation on Apple Silicon and are not comparable with anything else; the growth is
# what carries the finding.
#
# Usage:  ./29b_cduce_clause_scaling.sh [N ...]
# Needs:  docker (amd64 emulation), 29a_Dockerfile alongside.

set -u
cd "$(dirname "$0")"

IMG=cduce:0.6.0
docker build --platform linux/amd64 -q -t "$IMG" -f 29a_Dockerfile . >/dev/null || exit 1

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

NS=${*:-10 40 100 200 400 800 1600}

# N+2 disjoint interval clauses exactly covering Int, no catch-all.
for n in $NS; do
  { printf 'let f (Int -> Int)\n | *--0 -> 0\n'
    for ((i = 1; i <= n; i++)); do printf ' | %d--%d -> %d\n' "$i" "$i" "$i"; done
    printf ' | %d--* -> 0\n;;\n' "$((n + 1))"
  } > "$WORK/part_$n.cd"
done

# Nested intervals; every clause after the first is unreachable.
for n in $NS; do
  { printf 'let f (Int -> Int)\n'
    for ((i = 0; i < n; i++)); do printf ' | %d--%d -> %d\n' "$((0 - i))" "$((1000 + i))" "$i"; done
    printf ' | _ -> 0\n;;\n'
  } > "$WORK/ovl_$n.cd"
done

printf 'let f (Int -> Int)\n | _ -> 0\n;;\n' > "$WORK/base.cd"

echo "=== CDuce checker cost over an integer-interval subject ==="
docker run --rm --platform linux/amd64 "$IMG" cduce --version | head -2
echo

docker run --rm --platform linux/amd64 -v "$WORK:/w" "$IMG" bash -c '
  cd /w
  timed() {   # timed <label> <file>
    local t0 t1 out
    t0=$(date +%s%N)
    out=$(cduce --compile "$2" --obj-dir /tmp 2>&1)
    t1=$(date +%s%N)
    if [ -z "${out//[[:space:]]/}" ]; then out=ACCEPTED
    else out=$(printf "%s" "$out" | tr "\n" " " | cut -c1-60); fi
    printf "  %-26s %7d ms   %s\n" "$1" "$(( (t1 - t0) / 1000000 ))" "$out"
  }

  echo "baseline (1 clause, no intervals):"
  timed "1 clause" base.cd

  echo
  echo "exhaustive partition of Int by intervals, no catch-all:"
  for f in $(ls part_*.cd | sort -t_ -k2 -n); do
    n=${f#part_}; n=${n%.cd}
    timed "N=$n ($((n + 2)) arms)" "$f"
  done

  echo
  echo "nested overlapping intervals (redundancy path):"
  for f in $(ls ovl_*.cd | sort -t_ -k2 -n); do
    n=${f#ovl_}; n=${n%.cd}
    timed "N=$n" "$f"
  done
'
