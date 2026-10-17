#!/usr/bin/env bash
# build-variant.sh NAME [PATCH...]  -> builds a COPY of compiler/src (never edits it)
# into $WORK/NAME/ebin and writes $WORK/NAME/bsc, a launcher with bsc's CLI.
# OTP 25 here: leex has no TokenLoc/error_location (OTP 26+), so the lexer is
# patched in the COPY to {Line,1} columns. Semantics are unaffected, diagnostic
# columns are wrong. Every variant gets the identical shim, so it cancels out.
set -euo pipefail
root=$(cd "$(dirname "$0")/../../.." && pwd)
WORK=${WORK:-/tmp/p57work}
name=$1; shift
d=$WORK/$name
rm -rf "$d"; mkdir -p "$d/src" "$d/ebin"
cp "$root"/compiler/src/* "$d/src/"
cd "$d/src"
for p in "$@"; do patch -s -p0 < "$p"; done
sed -i 's/TokenLoc/{TokenLine,1}/g' bs_lexer.xrl
ln=$(grep -n '^Erlang code' bs_lexer.xrl | cut -d: -f1)
sed -i "${ln}a adjust_col(_Chars, Len, C) -> C + Len." bs_lexer.xrl
erl -noshell -eval 'leex:file("bs_lexer.xrl",[]), halt().'
erl -noshell -eval 'yecc:file("bs_parser.yrl",[{verbose,false}]), halt().' 2>&1 | tee "$d/yecc.txt" >&2
erlc +debug_info -o "$d/ebin" *.erl 2>&1 | grep -iE "error" || true
cp bsc.app.src "$d/ebin/bsc.app"
cat > "$d/bsc" <<EOF
#!/bin/sh
exec erl -noshell -pa $d/ebin -eval 'bsc:main(init:get_plain_arguments()), halt().' -extra "\$@"
EOF
chmod +x "$d/bsc"
echo "built $d ($(grep -c 'onflict' "$d/yecc.txt") yecc conflict line(s))"
