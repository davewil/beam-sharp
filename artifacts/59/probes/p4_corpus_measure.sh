#!/usr/bin/env bash
# P4: compile every module directory under compiler/examples with a given compiler build,
# then count guards and bytes. usage: p4_corpus_measure.sh <ebin> <label>
source "$(dirname "$0")/env.sh"
EBIN=$1; LABEL=$2; [ -d "$EBIN" ] || build_compiler "$EBIN"
OUT=/tmp/bs59-build/corpus-$LABEL; rm -rf "$OUT"; mkdir -p "$OUT"
ROOT=$REPO/compiler/examples; ok=0; bad=0
while IFS= read -r d; do
  n=$(echo "${d#$ROOT/}" | tr / _)
  mkdir -p "$OUT/$n"
  if bsc_in "$EBIN" "$OUT/$n" --src-root "$ROOT" "$d" >"$OUT/$n/log" 2>&1 </dev/null; then ok=$((ok+1)); else bad=$((bad+1)); echo "  (did not compile: ${d#$ROOT/})"; fi
done < <(find "$ROOT" -name '*.bs' -not -path '*/exemplars/*' -printf '%h\n' | sort -u)
echo "[$LABEL] compiled=$ok failed=$bad"
"$PROBES/measure.escript" "$OUT"
