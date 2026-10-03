#!/bin/sh
# Builds TWO compilers from the repo's compiler/src into scratch, by hand (rebar3 is broken on OTP 29):
#   base/ebin  = unmodified repo source
#   proto/ebin  = same source + option-a-internal-segment.patch   (v1: the `using` site only; PROTOTYPE, never committed)
#   proto2/ebin = proto + option-a-v2-type-site.patch (v2: also the qualified-type site that v1 missed, see run.out)
# The repo is only read.
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
HERE="$(cd "$(dirname "$0")" && pwd)"
W=/tmp/claude-0/-home-user-beam-sharp/41c7fa9e-39c6-543b-8f3d-dee4a7daa0ba/scratchpad/proto60
mkdir -p $W
for V in base proto proto2; do
  rm -rf $W/$V; mkdir -p $W/$V/src $W/$V/ebin
  cp /home/user/beam-sharp/compiler/src/* $W/$V/src/
  [ $V != base ] && patch -s -p1 -d $W/$V/src < "$HERE/option-a-internal-segment.patch"
  [ $V = proto2 ] && patch -s -p1 -d $W/$V/src < "$HERE/option-a-v2-type-site.patch"
  ( cd $W/$V/src
    erl -noshell -eval 'leex:file("bs_lexer.xrl",[{error_location,column}]), yecc:file("bs_parser.yrl"), halt().' 
    erlc +debug_info -o ../ebin *.erl >/dev/null 2>$W/$V/erlc.err || { echo "erlc failed ($V)"; head $W/$V/erlc.err; } )
  cp $W/$V/src/bsc.app.src $W/$V/ebin/bsc.app 2>/dev/null
  echo "$V: $(ls $W/$V/ebin/*.beam | wc -l) beams"
done
