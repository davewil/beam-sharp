#!/bin/sh
# usage: build-bsc.sh DEST [PATCH]   -- builds compiler/src (read-only) into DEST/ebin by hand
# (rebar3 is broken on OTP 29, see scratchpad ENV.md). With PATCH, applies it to the COPY only (PROTOTYPE).
set -e
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
DEST=$1; PATCH=$( [ -n "$2" ] && realpath "$2" || true )
REPO=/home/user/beam-sharp
rm -rf "$DEST"; mkdir -p "$DEST/src" "$DEST/ebin"
cp "$REPO"/compiler/src/* "$DEST/src/"
cd "$DEST/src"
[ -n "$PATCH" ] && patch -p0 < "$PATCH"
erl -noshell -eval 'leex:file("bs_lexer.xrl", [{error_location,column}]), yecc:file("bs_parser.yrl"), halt().'
erlc +debug_info -o ../ebin *.erl
cp bsc.app.src ../ebin/bsc.app 2>/dev/null || true
echo "built $DEST ($(ls ../ebin/*.beam | wc -l) beams) patch=${PATCH:-none}"
