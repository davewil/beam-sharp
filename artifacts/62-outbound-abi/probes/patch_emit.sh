#!/usr/bin/env bash
# Builds the PATCHED scratch copy of the compiler (never touches compiler/src):
# adds snake_case alias emission to bs_emit.erl, switched by BS_ALIAS_MODE=none|forward|forward_nospec|dup.
# Output: $S/62/csrc-ebin. Idempotent.
S=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad
source $S/env.sh
HERE="$(cd "$(dirname "$0")" && pwd)"
D=$S/62; rm -rf $D/csrc $D/csrc-ebin; cp -r /home/user/beam-sharp/compiler/src $D/csrc; mkdir $D/csrc-ebin; cp $S/bsc-ebin/bsc.app $D/csrc-ebin/
( cd $D/csrc && erl -noshell -eval 'leex:file("bs_lexer.xrl",[{error_location,column}]), yecc:file("bs_parser.yrl"), halt().' >/dev/null 2>&1
  patch -p0 bs_emit.erl < $HERE/alias_emit.patch >/dev/null || exit 1
  for f in *.erl; do erlc +debug_info -o ../csrc-ebin $f >/dev/null 2>&1 || echo FAIL $f; done )
echo built $D/csrc-ebin
