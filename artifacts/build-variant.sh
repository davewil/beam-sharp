#!/usr/bin/env bash
# build-variant.sh PATCH OUTDIR — rebuild a prototype compiler from a patch against a clean copy of compiler/.
# Prints the path of the built bsc. Source of truth for every "prototype compiler" cited in artifacts/.
set -euo pipefail
PATCH=$(readlink -f "$1"); OUT=$2
. "$(dirname "$0")/env.sh"
mkdir -p "$OUT"
(cd "$(dirname "$0")/../compiler" && tar cf - --exclude=_build --exclude=bs_parser.erl --exclude=bs_lexer.erl .) | tar xf - -C "$OUT"
(cd "$OUT" && patch -s -p1 < "$PATCH")
(cd "$OUT" && rebar3 escriptize >/dev/null 2>&1)
echo "$OUT/_build/default/bin/bsc"
