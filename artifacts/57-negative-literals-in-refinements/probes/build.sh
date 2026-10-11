#!/usr/bin/env bash
# build.sh SRC_DIR EBIN : yecc/leex + erlc exactly as the reference ebin is built
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
set -e; SRC=$1; OUT=$2; rm -rf $OUT; mkdir -p $OUT
cd $SRC
erl -noshell -eval 'leex:file("bs_lexer.xrl",[{error_location,column}]), yecc:file("bs_parser.yrl",[{verbose,false}]), halt().' 
erlc +debug_info -o $OUT *.erl
cp bsc.app.src $OUT/bsc.app
