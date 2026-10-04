#!/usr/bin/env bash
# AST of `value >= -5` and of a guard comparand, before (base) and after the grammar fold; checker folds leave the AST alone.
PROTO=${PROTO:-/tmp/claude-0/-home-user-beam-sharp/4180a786-23e5-53e3-b71e-94fb1d89eea9/scratchpad/proto}
here=$(cd "$(dirname "$0")" && pwd)
export PATH=/opt/otp28/bin:$PATH
for v in base grammar checker_full; do
  echo "######## $v"
  printf 'module M\ntype T = int where value >= -5\npublic atom F(int n)\nF(n) when n >= -(5) -> :a\nF(_) -> :b\n' | escript $here/ast.escript $PROTO/$v/compiler/_build/default/lib/bsc/ebin | grep -E "e_neg|e_int|e_op" 
done
