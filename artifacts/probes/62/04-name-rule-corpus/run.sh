#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib.sh"
BSC=$(build_bsc plain) || exit 1
OUT="$SCRATCH/all-ebin"; rm -rf "$OUT"; mkdir -p "$OUT"
mkdir -p "$SCRATCH/cwd"; cd "$SCRATCH/cwd"
for d in "$EX"/*/; do d=$(basename "$d"); [ "$d" = exemplars ] && continue
  "$BSC" --src-root "$EX" -o "$OUT" "$EX/$d" >/dev/null 2>&1 || echo "(did not compile under the OTP25 scratch bsc: $d)"; done
erlc -o "$SCRATCH" "$HERE/dump.erl" && erl -noshell -pa "$SCRATCH" -run dump main "$OUT" | python3 -I "$HERE/rules.py"
elixir "$HERE/underscore.exs"
