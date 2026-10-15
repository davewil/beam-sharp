#!/usr/bin/env bash
# 59_corpus.sh -- how much of the shipped corpus does the scope choice touch?
# For every module under compiler/examples (excl. exemplars/, which do not compile): compile with HEAD,
# EXP (both guards exported-only) and ALL (both guards everywhere), and report the number of PRIVATE
# functions carrying a tag test (HEAD) / an is_integer or is_float test (ALL-only) and the Code-chunk delta.
# REFUTED (nothing to decide) if every row is zero.
set -u
cd "$(dirname "$0")"; . ./env.sh; . ./59_lib.sh
T=$(mktemp -d "${TMPDIR:-/tmp}/p59corp.XXXXXX"); EX="$REPO/compiler/examples"
echo "rows shown only where the scope choice changes something (priv tag tests under HEAD, or extra private int/float tests under ALL)"
echo "columns: example-dir beam | tag = private fns with the record tag test (HEAD) | int/flt = private fns that GAIN an is_integer/is_float test under ALL | Code-chunk byte deltas"
nb=0; nrow=0
for d in $(cd "$EX" && ls -d */ | tr -d / | grep -v '^exemplars$'); do
  ok=1
  for V in HEAD EXP ALL; do var=BSC_$V; mkdir -p "$T/$d/$V"; (cd "$EX" && "${!var}" --src-root . -o "$T/$d/$V" "$d" >/dev/null 2>&1) || ok=0; done
  [ $ok = 1 ] || { printf '%-12s (did not compile standalone)\n' "$d"; continue; }
  for b in "$T/$d/HEAD"/*.beam; do n=$(basename "$b"); case "$n" in *@*) continue;; esac
    pt=$(./59_guards.escript "$b" 2>/dev/null | awk '$2=="private" && $3=="tag_guard=Y"' | wc -l)
    pa=$(./59_guards.escript "$T/$d/ALL/$n" 2>/dev/null | awk '$2=="private" && ($5=="is_integer=Y" || $6=="is_float=Y")' | wc -l)
    ph=$(./59_guards.escript "$b" 2>/dev/null | awk '$2=="private" && ($5=="is_integer=Y" || $6=="is_float=Y")' | wc -l)
    h=$(./59_size.escript "$b" | sed 's/.*code=\([0-9]*\).*/\1/'); e=$(./59_size.escript "$T/$d/EXP/$n" | sed 's/.*code=\([0-9]*\).*/\1/'); a=$(./59_size.escript "$T/$d/ALL/$n" | sed 's/.*code=\([0-9]*\).*/\1/')
    nb=$((nb+1))
    priv_all=$(./59_guards.escript "$b" 2>/dev/null | awk '$2=="private"' | wc -l); echo "  [$d/$n: $priv_all private fns]" >> "$T/inv.txt"
    [ "$pt$((pa-ph))" = "00" ] && continue
    nrow=$((nrow+1))
    printf '%-12s %-20s tag=%-3s int/flt=%-3s HEAD-EXP=%-5s ALL-HEAD=%-5s\n' "$d" "$n" "$pt" "$((pa-ph))" "$((h-e))" "$((a-h))"
  done
done
echo "beams scanned: $nb ; with a non-zero row: $nrow ; private functions in scanned beams: $(grep -o '[0-9]* private' "$T/inv.txt" | awk '{s+=$1} END{print s}')"
