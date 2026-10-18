#!/bin/bash
# Rebuilds bsc (baseline + every prototype variant) from compiler/src and the patches in */proto*.
# Needs only the toolchain in env.sh. Output: $S/<variant>/ebin   (what BSC_EBIN points at).
# The baseline needs no OTP-26 `error_location` leex option on OTP 29? It does, and OTP 29 has it.
. "$(dirname "$0")/env.sh"
HERE=$(cd "$(dirname "$0")" && pwd); SRC=$HERE/../../compiler/src
build() {   # build <variant> [<patch> <file-in-src>]...
  v=$1; shift
  rm -rf $S/$v; mkdir -p $S/$v/src $S/$v/ebin; cp $SRC/*.erl $SRC/*.xrl $SRC/*.yrl $S/$v/src/
  while [ $# -gt 0 ]; do (cd $S/$v/src && patch -s $2 < $HERE/$1) || { echo "PATCH FAILED $v $1"; exit 1; }; shift 2; done
  (cd $S/$v && erl -noshell -eval 'leex:file("src/bs_lexer.xrl",[{error_location,column}]),yecc:file("src/bs_parser.yrl",[]),halt().' >/dev/null 2>&1
   erlc -o ebin +debug_info src/*.erl >/dev/null 2>&1; echo "$v: $(ls ebin | wc -l) beams")
}
build c
build c57_checker 57/proto/checker.patch bs_check.erl
build c57_parser  57/proto/parser.patch  bs_parser.yrl
build c59_narrow  59/proto/narrow.patch  bs_emit.erl
build c59_wide    59/proto/wide.patch    bs_emit.erl
build c60         60/proto.patch         bs_check.erl
build c52         52/proto.patch         bs_check.erl
