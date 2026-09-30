#!/usr/bin/env bash
# Build the reference compiler WITHOUT rebar3 (not installed). Output: $B (default /tmp/bsc57/ebin)
# NB: OTP 25 here; repo pins OTP 28.5. leex is borrowed from OTP maint-26 (see below).
set -euo pipefail
root=/home/user/beam-sharp; B=${B:-/tmp/bsc57}; SRC=${SRC:-$root/compiler/src}
rm -rf "$B"; mkdir -p "$B/ebin" "$B/gen"
cp $SRC/*.{xrl,yrl} "$B/gen/"
cd "$B/gen"
# OTP 25's leex predates TokenLoc/error_location (OTP 26+); use maint-26's leex.erl (maint-28's uses OTP27 doc sigils, unbuildable on 25) fetched into /tmp/leexnew with leexinc.hrl.
if [ ! -f /tmp/leexnew/leex.beam ]; then mkdir -p /tmp/leexnew; ( cd /tmp/leexnew && curl -sSf -O https://raw.githubusercontent.com/erlang/otp/maint-26/lib/parsetools/src/leex.erl && curl -sSf -O https://raw.githubusercontent.com/erlang/otp/maint-28/lib/parsetools/include/leexinc.hrl && erlc -I /usr/lib/erlang/lib/stdlib-4.3.1.3/include leex.erl ); fi
erl -noshell -pa /tmp/leexnew -eval 'R=leex:file("bs_lexer.xrl",[{error_location,column},{includefile,"/tmp/leexnew/leexinc.hrl"}]), io:format("~p~n",[R]), yecc:file("bs_parser.yrl",[]), halt().'
erlc -o "$B/ebin" +debug_info *.erl $SRC/*.erl
cp $SRC/bsc.app.src "$B/ebin/bsc.app" 
echo built
