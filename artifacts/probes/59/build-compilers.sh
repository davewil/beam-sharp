#!/usr/bin/env bash
# Builds two bsc escripts from the repo's compiler source into $1:
#   $1/head/bsc    -- unmodified HEAD
#   $1/narrow/bsc  -- PROTOTYPE DELTA: prototype-delta.patch applied (tag test exported-only)
#   $1/widen/bsc   -- PROTOTYPE DELTA: prototype-delta-widen.patch applied (int/float kind test on private too)
# Never touches /home/user/beam-sharp/compiler.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/../../../compiler"
OUT="$1"; mkdir -p "$OUT"
for v in head narrow widen; do
  rm -rf "$OUT/$v-src"; mkdir -p "$OUT/$v-src"
  (cd "$SRC" && tar cf - --exclude=_build .) | (cd "$OUT/$v-src" && tar xf -)
  if [ "$v" = narrow ]; then
    (cd "$OUT/$v-src" && patch -p0 -s src/bs_emit.erl < "$HERE/prototype-delta.patch")
  fi
  if [ "$v" = widen ]; then
    (cd "$OUT/$v-src" && patch -p0 -s src/bs_emit.erl < "$HERE/prototype-delta-widen.patch")
  fi
  (cd "$OUT/$v-src" && rebar3 escriptize >/dev/null 2>&1)
  mkdir -p "$OUT/$v"; cp "$OUT/$v-src/_build/default/bin/bsc" "$OUT/$v/bsc"
done
echo "built: $OUT/head/bsc  $OUT/narrow/bsc  $OUT/widen/bsc"
