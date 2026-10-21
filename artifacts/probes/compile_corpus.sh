#!/bin/sh
# Compile every directory of .bs under compiler/examples with bsc and collect the .abstr files FLAT into $1.
# (The seven exemplars/25* directories are fragments, not buildable modules; they fail and are reported, not hidden.)
set -u
OUT=${1:?usage: compile_corpus.sh OUTDIR}; BSC=${BSC:?set BSC}
R=$(cd "$(dirname "$0")/../../compiler/examples" && pwd); T=$(mktemp -d); mkdir -p "$OUT"; ok=0; bad=0
for d in $(find "$R" -name '*.bs' -printf '%h\n' | sort -u); do
  if "$BSC" --src-root "$R" -o "$T/$ok" "$d" >/dev/null 2>&1; then ok=$((ok+1)); else bad=$((bad+1)); echo "not buildable alone: ${d#$R/}" >&2; fi
done
for f in $(find "$T" -name '*.abstr'); do cp "$f" "$OUT/$(echo "$f" | tr '/' '_')"; done
echo "compiled-dirs=$ok failed-dirs=$bad abstr-files=$(ls "$OUT" | wc -l)"
