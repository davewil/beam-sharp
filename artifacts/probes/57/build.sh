#!/bin/sh
# usage: build.sh SRC_DIR OUT_DIR   (SRC_DIR holds bs_*.erl, bs_lexer.xrl, bs_parser.yrl)
# Builds a compiler into OUT_DIR/ebin, generated files in OUT_DIR/gen; prints yecc conflict lines.
SP=/tmp/claude-0/-home-user-beam-sharp/40070274-2489-5304-8393-d8d915b713dc/scratchpad
src=$(cd "$1" && pwd); out=$2; mkdir -p "$out/ebin" "$out/gen"; out=$(cd "$out" && pwd)
cd "$out/gen"
erl -noshell -pa $SP/newleex -eval '
 R1 = leex:file("'$src'/bs_lexer.xrl", [{scannerfile,"'$out'/gen/bs_lexer.erl"},{includefile,"'/tmp/claude-0/-home-user-beam-sharp/40070274-2489-5304-8393-d8d915b713dc/scratchpad'/newleex/leexinc.hrl"},{error_location,column}]),
 io:format("leex: ~p~n",[R1]),
 R2 = yecc:file("'$src'/bs_parser.yrl", [{parserfile,"'$out'/gen/bs_parser.erl"},{verbose,false}]),
 io:format("yecc: ~p~n",[R2]),
 halt().' 2>&1
for f in "$src"/*.erl "$out"/gen/*.erl; do
  erlc -o "$out/ebin" +debug_info "$f" 2>&1 | grep -v Warning | head -5
done
echo built $out/ebin
