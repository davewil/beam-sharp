#!/usr/bin/env bash
# Cost of doubling the export table with snake_case aliases, on every example module that compiles.
export PATH=$HOME/.nix-profile/bin:$PATH
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$HERE/../../.."
BSC="$ROOT/compiler/_build/default/bin/bsc"; EX="$ROOT/compiler/examples"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; mkdir -p "$W/out"
ok=0; bad=0
for d in "$EX"/*/ "$EX"/Shop/*/; do
  d="${d%/}"; [ "$(basename "$d")" = exemplars ] && continue
  if "$BSC" --src-root "$EX" -o "$W/out" "$d" >/dev/null 2>&1; then ok=$((ok+1)); else bad=$((bad+1)); fi
done
echo "modules compiled: $ok   not compiled standalone: $bad"
escript "$HERE/05_alias_cost.escript" "$W/out"
