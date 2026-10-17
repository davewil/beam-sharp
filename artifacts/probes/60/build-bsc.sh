#!/usr/bin/env bash
# Build bsc from compiler/src (never modified) into $1, optionally applying patch $2 (-p1, a/ b/ paths) to the COPY.
# Host is OTP 25; the repo targets OTP 28. leex here has no TokenLoc/column support, so the lexer is
# patched in the copy to {Line,1}-style positions: diagnostics columns are wrong, semantics are not.
set -euo pipefail
root=$(cd "$(dirname "$0")/../../.." && pwd)
out=$1; patch_file=${2:-}
rm -rf "$out"; mkdir -p "$out/gen" "$out/ebin"
cp "$root"/compiler/src/* "$out/gen/"
cd "$out/gen"
[ -n "$patch_file" ] && patch -s -p1 < "$patch_file"
sed -i 's/TokenLoc/{TokenLine,1}/g' bs_lexer.xrl
ln=$(grep -n '^Erlang code' bs_lexer.xrl | cut -d: -f1)
sed -i "${ln}a adjust_col(_Chars, Len, C) -> C + Len." bs_lexer.xrl
erl -noshell -eval 'leex:file("bs_lexer.xrl",[]), yecc:file("bs_parser.yrl"), halt().' >/dev/null 2>&1
erlc +debug_info -o "$out/ebin" *.erl 2>&1 | grep -E "Error|error:" || true
cp bsc.app.src "$out/ebin/bsc.app"
cat > "$out/bsc" <<EOF
#!/bin/sh
exec erl -noshell -pa $out/ebin -eval 'bsc:main(init:get_plain_arguments()), halt().' -extra "\$@"
EOF
chmod +x "$out/bsc"
