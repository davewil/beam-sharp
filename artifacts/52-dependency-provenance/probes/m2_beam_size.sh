#!/usr/bin/env bash
# (d) Run: ./m2_beam_size.sh
H="$(cd "$(dirname "$0")" && pwd)"; FX="$H/fixtures/_fx"
[ -d "$FX/libA" ] || "$H/fixtures/build-fixtures.sh" >/dev/null
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
for m in Dep Many; do
  D="$FX/size-$m"; rm -rf "$D"
  "$H/bsc.sh" -o "$D" --src-root "$H/bs" "$H/bs/$m" >/dev/null 2>&1
  lcm=$(echo $m | tr A-Z a-z)
  echo "=== $m (bsc -o: $(ls $D | tr '\n' ' '); real bsc beam = $(stat -c %s $D/$m.beam) B)"
  BS_SRC="$H/bs/$m/$lcm.bs" escript "$H/m2_beam_size.escript" "$D/$m.abstr" $m
  echo "--- the first forms bsc emits (shape of the form the attribute joins):"
  head -c 700 "$D/$m.abstr" | head -6 | sed 's/^/    /'
done
