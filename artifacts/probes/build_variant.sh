#!/usr/bin/env bash
# usage: build_variant.sh PATCH|none OUTDIR   — build bsc from compiler/src, optionally with ONE prototype patch from patches/.
# The only deviation from rebar3's build: leex's {error_location,column} is passed exactly as rebar.config does; nothing else.
set -euo pipefail
. "$(dirname "$0")/env.sh" 2>/dev/null || true
H="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$H/../.." && pwd)"; PATCH=$1; OUT=$(mkdir -p "$2" && cd "$2" && pwd)
T=$(mktemp -d); mkdir -p "$T/a"; cp "$ROOT"/compiler/src/* "$T/a/"
if [ "$PATCH" != none ]; then ( cd "$T" && mkdir -p compiler && cp -r a compiler/src && patch -p1 < "$H/patches/$PATCH.patch" >/dev/null && rm -rf a && mv compiler/src a ); fi
( cd "$T/a" && erl -noshell -eval 'leex:file("bs_lexer.xrl",[{error_location,column}]), yecc:file("bs_parser.yrl"), halt().' 2>&1 | grep -v conflicts || true
  erlc -o "$OUT" *.erl 2>&1 | grep -v -i warning | grep -E 'error|Error' || true
  cp bsc.app.src "$OUT/bsc.app" )
echo "built $PATCH -> $OUT ($(ls "$OUT" | wc -l) files)"
