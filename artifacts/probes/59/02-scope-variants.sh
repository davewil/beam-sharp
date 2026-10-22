#!/usr/bin/env bash
# Probe 02 — the three scope rules as scratch compilers, the same battery against each.
#   A  as built:            tag everywhere, int exported-only        (repo emitter, unmodified)
#   B  one rule, narrow:    tag exported-only, int exported-only     (patch-tag-exported-only.sh)
#   C  one rule, wide:      tag everywhere, int everywhere           (patch-int-everywhere.sh)
H="$(cd "$(dirname "$0")" && pwd)"; . "$H/lib.sh"
for V in "A:base:" "B:narrow:$H/patch-tag-exported-only.sh" "C:wide:$H/patch-int-everywhere.sh"; do
  IFS=: read -r L N P <<<"$V"
  B=$(build_bsc "$N" "$P") || exit 1
  O="$SCRATCH/o-$N"; rm -rf "$O"; mkdir -p "$O"
  $B --src-root "$H/src" -o "$O" "$H/src/T" || exit 1
  echo; echo "################ variant $L ($N) ################"
  [ -n "$P" ] && { echo "--- diff of scratch bs_emit.erl vs repo ---"; diff "$REPO/compiler/src/bs_emit.erl" "$SCRATCH/$N/src/bs_emit.erl"; }
  echo "--- emitted heads of the private functions ---"; pp_beam "$O/T.beam" | grep -A3 -E "^'(Inner|Bump)'"
  echo "--- forged values ---"; "$H/battery.escript" "$O"
done
