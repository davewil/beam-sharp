#!/usr/bin/env bash
# build.sh SRC_DIR OUT_DIR  -- hand build (rebar3 is broken on OTP 29): leex + yecc + erlc.
# Prints the yecc conflict report. SRC_DIR is copied, never modified.
set -euo pipefail
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
src=$(cd "$1" && pwd); out=$2
rm -rf "$out"; mkdir -p "$out/src" "$out/ebin"
cp "$src"/* "$out/src/"
cd "$out/src"
erl -noshell -eval '
  {ok,_} = leex:file("bs_lexer.xrl", [{error_location,column}]),
  R = yecc:file("bs_parser.yrl", [verbose, {report,true}]),
  io:format("yecc: ~p~n",[R]), halt().' 2>&1 | sed 's/^/  /'
for f in *.erl; do erlc -W0 +debug_info -o ../ebin "$f" || exit 1; done
cp bsc.app.src ../ebin/bsc.app 2>/dev/null || true
