#!/bin/bash
# Builds the REAL bs_parser.yrl, bs_check.erl, bs_types.erl ... from compiler/src on OTP 25 into a scratch dir.
# The only changed file is a SCRATCH COPY of bs_lexer.xrl: TokenLoc (OTP 27 leex) is replaced by {TokenLine,1},
# so tokens keep the {Line,Col} shape but every column is 1. Nothing tracked is edited.
set -e
W=${W:-/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/w57}
SRC=/home/user/beam-sharp/compiler/src
rm -rf $W; mkdir -p $W/src $W/ebin; cp $SRC/*.erl $SRC/*.yrl $SRC/*.xrl $W/src/; cd $W/src
sed -i 's/TokenLoc/{TokenLine,1}/g' bs_lexer.xrl
cat >> bs_lexer.xrl <<'X'

adjust_col(_Chars, _Len, C) -> C.
X
erl -noshell -eval 'io:format("~p~n",[leex:file("bs_lexer.xrl",[{return,true}])]), io:format("~p~n",[yecc:file("bs_parser.yrl",[{return,true},{verbose,false}])]), halt().' 2>&1 | tail -4
for f in *.erl; do erlc -o ../ebin +debug_info $f 2>&1 | grep -v 'format string\|%' | head -3; done
ls ../ebin | wc -l; erl -noshell -eval 'io:format("OTP ~s~n",[erlang:system_info(otp_release)]),halt().'
