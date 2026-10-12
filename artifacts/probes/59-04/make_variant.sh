#!/usr/bin/env bash
# Builds a PROTOTYPE bsc in a scratch dir (never touches compiler/): tag test only on exported functions.
# usage: make_variant.sh DEST [narrow|widen]  (narrow = tag test only on exported; widen = int/float kind test on private too)
# was: make_variant.sh DEST    -> DEST/_build/default/bin/bsc
set -eu; HERE="$(cd "$(dirname "$0")" && pwd)"; REPO="$(cd "$HERE/../../.." && pwd)"
DEST="$1"; V="${2:-narrow}"; rm -rf "$DEST"; mkdir -p "$DEST"
cp -r "$REPO/compiler/src" "$REPO/compiler/rebar.config" "$REPO/compiler/rebar.lock" "$REPO/compiler/bin" "$DEST/"
( cd "$DEST" && patch -p1 < "$HERE/$V.patch" && rebar3 escriptize 2>&1 | tail -2 )
