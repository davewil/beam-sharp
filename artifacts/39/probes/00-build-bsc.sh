#!/usr/bin/env bash
# Builds bsc without rebar3 (not installed): leex, yecc, erlc, then run via -pa ebin.
set -e
R=/home/user/beam-sharp
B=$R/artifacts/39/build
mkdir -p $B/ebin $B/gen
# DEVIATION: installed leex (parsetools 2.4.1) has no TokenLoc / error_location / adjust_col.
# Shim the .xrl copy: positions become {Line,1}. Affects diagnostics' columns only, not emitted code.
sed -e 's/TokenLoc/{TokenLine,1}/g' $R/compiler/src/bs_lexer.xrl > $B/gen/bs_lexer.xrl
cat >> $B/gen/bs_lexer.xrl <<'XEOF'

adjust_col(_Chars, N, C) -> C + N.
XEOF
erl -noshell -eval '{ok,_}=leex:file("'$B'/gen/bs_lexer.xrl",[{scannerfile,"'$B'/gen/bs_lexer.erl"}]),{ok,_}=yecc:file("'$R'/compiler/src/bs_parser.yrl",[{parserfile,"'$B'/gen/bs_parser.erl"}]),halt().' 
erlc -o $B/ebin $B/gen/*.erl $R/compiler/src/*.erl
cp $R/compiler/src/bsc.app.src $B/ebin/bsc.app
echo built; ls $B/ebin | head -30
