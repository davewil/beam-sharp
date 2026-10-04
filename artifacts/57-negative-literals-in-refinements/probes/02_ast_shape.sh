#!/usr/bin/env bash
# Claim (ticket 57 "Why it happens"): `value >= -5` reaches the checker as
#   {e_op,'>=',{e_var,value},{e_op,'-',{e_int,0},{e_int,5}}}.
# Check the real AST on this checkout.
source "$(dirname "$0")/lib.sh"
EBIN=${EBIN:-$root/compiler/_build/default/lib/bsc/ebin}
here=$(cd "$(dirname "$0")" && pwd)
for pred in 'value >= -5' 'value >= 2 + 3' 'value >= -(5)' 'value >= - -5' 'value >= -5.0'; do
  echo "== type T = int where $pred"
  printf 'module M\ntype T = int where %s\n' "$pred" | escript $here/ast.escript $EBIN
done
echo "== pattern: Sign(<= -1) and Sign(-1)"
printf 'module M\npublic atom Sign(int n)\nSign(<= -1) -> :neg\nSign(-1) -> :m1\n' | escript $here/ast.escript $EBIN
echo "== guard: when n >= -5"
printf 'module M\npublic atom Sign(int n)\nSign(n) when n >= -5 -> :a\nSign(_) -> :b\n' | escript $here/ast.escript $EBIN
