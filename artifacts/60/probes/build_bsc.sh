#!/usr/bin/env bash
# Builds compiler/src with erlc/leex/yecc on OTP 25 (rebar3 is not installed).
# DEVIATION: OTP 25's leex has no column tracking (TokenLoc), so the lexer copy
# substitutes {TokenLine,1} for TokenLoc. Columns in diagnostics are therefore
# always 1; nothing in this ticket depends on a column.
set -e
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
OUT=${1:-/tmp/bsc-build-60}
mkdir -p "$OUT/gen" "$OUT/ebin"
sed -e 's/TokenLoc/{TokenLine,1}/g' "$ROOT/compiler/src/bs_lexer.xrl" > "$OUT/gen/bs_lexer.xrl"
echo 'adjust_col(_Chars, _Len, C) -> C.' >> "$OUT/gen/bs_lexer.xrl"
(cd "$OUT/gen" && erl -noshell -eval 'leex:file("bs_lexer.xrl",[]), halt().')
(cd "$ROOT/compiler/src" && erl -noshell -eval 'yecc:file("bs_parser.yrl",[{parserfile,"'$OUT'/gen/bs_parser.erl"}]), halt().')
(cd "$ROOT/compiler/src" && erlc -o "$OUT/ebin" -I . "$OUT/gen/bs_lexer.erl" "$OUT/gen/bs_parser.erl" *.erl)
echo "built $OUT/ebin"
