#!/bin/sh
# Build a PROTOTYPE bsc (patched COPY of compiler/src; the repo is untouched) into $OUT.
# Mirrors the ENV.md recipe: leex + yecc + erlc +debug_info, by hand (rebar3 is broken on OTP 29).
set -e
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=/home/user/beam-sharp
OUT=${1:-/tmp/bs52_proto}
rm -rf "$OUT"; mkdir -p "$OUT/src" "$OUT/ebin"
cp "$REPO"/compiler/src/* "$OUT/src/"
( cd "$OUT/src" && patch -s -p0 < /dev/null 2>/dev/null; true )
# the patch was made as `diff -u orig src`; apply file by file
( cd "$OUT/src" && for f in bs_parser.yrl bsc.erl; do
    awk -v f="$f" 'BEGIN{p=0} /^--- /{p=($2 ~ f"$")} p' "$HERE/proto52.patch" | sed "s#^--- .*#--- $f#; s#^+++ .*#+++ $f#" > /tmp/.p52_$f.diff
    patch -s "$f" < /tmp/.p52_$f.diff
  done )
cd "$OUT/src"
erl -noshell -eval 'ok=case leex:file("bs_lexer.xrl",[{error_location,column}]) of {ok,_}->ok; E->io:format("~p~n",[E]),halt(1) end, case yecc:file("bs_parser.yrl",[{verbose,false}]) of {ok,_}->ok; {ok,_,W}->io:format("yecc warnings: ~p~n",[W]); E2->io:format("~p~n",[E2]),halt(1) end, halt().'
for f in *.erl; do erlc +debug_info -o "$OUT/ebin" "$f" || exit 1; done
echo "built $OUT/ebin"
