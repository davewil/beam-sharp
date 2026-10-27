#!/bin/bash
# Builds four SCRATCH variants of the real source ($W/src, from 00_build_scratch.sh). Tracked files are untouched.
#  A1 parser : negate/2 folds `-<int literal>` to {e_int,_,-N} everywhere (the F51 float clause, extended to ints).
#  A2 parser : only a refinement's expression is folded (the ticket's "narrow it at one site", written as an action).
#  B1 checker: comparison/1 reads a comparand through const_int/1, which folds e_neg over literals only.
#  B3 checker: B2 plus type_of/3 types a negated int literal as the literal's range (what A1 gets for free).
#  B2 checker: const_int/1 also folds + - * / % over literals (a zero divisor stays unreadable).
set -e
W=${W:-/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/w57}
D=$(cd "$(dirname "$0")" && pwd)
mk()    { rm -rf $W/v_$1; mkdir -p $W/v_$1/src $W/v_$1/ebin; cp $W/src/*.erl $W/src/*.yrl $W/src/*.xrl $W/v_$1/src/; }
build() {
  cd $W/v_$1/src
  erl -noshell -eval 'leex:file("bs_lexer.xrl",[{return,true}]), R=yecc:file("bs_parser.yrl",[{return,true},{verbose,false}]), io:format("[~s] ~p~n",["'$1'",R]), halt().'
  for f in *.erl; do erlc -o ../ebin +debug_info $f 2>&1 | grep -v 'format string\|%\|^$' | head -3 || true; done
  erlc -o ../ebin $D/drv.erl $D/guards.erl $D/table.erl $D/more.erl
}
mk A1; python3 -I - $W/v_A1/src/bs_parser.yrl <<'P'
import sys
p=sys.argv[1]; s=open(p).read()
s=s.replace("negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};","negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};\nnegate(_L, {e_int, IL, N})   -> {e_int, IL, -N};")
open(p,'w').write(s)
P
build A1
mk A2; python3 -I - $W/v_A2/src/bs_parser.yrl <<'P'
import sys
p=sys.argv[1]; s=open(p).read()
s=s.replace("refinement -> expr_low : '$1'.","refinement -> expr_low : fold_neg('$1').")
s=s.replace("negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};","fold_neg({e_neg, _, {e_int, IL, N}}) -> {e_int, IL, -N};\nfold_neg({e_op, L, Op, A, B})        -> {e_op, L, Op, fold_neg(A), fold_neg(B)};\nfold_neg(E)                          -> E.\n\nnegate(_L, {e_float, FL, F}) -> {e_float, FL, -F};")
open(p,'w').write(s)
P
build A2
for V in B1 B2 B3; do
  mk $V
  python3 -I - $W/v_$V/src/bs_check.erl $V $D <<'P'
import sys
p,v,d=sys.argv[1:4]; s=open(p).read()
old="comparison({e_op, _, Op, {e_var, _, V}, {e_int, _, K}}) -> int_cmp(Op, V, K);\ncomparison({e_op, _, Op, {e_int, _, K}, {e_var, _, V}}) -> int_cmp(flip(Op), V, K);"
assert old in s
new="""comparison({e_op, _, Op, {e_var, _, V}, R}) when element(1, R) =:= e_int; element(1, R) =:= e_neg; element(1, R) =:= e_op ->
    case const_int(R) of {ok, K} -> int_cmp(Op, V, K); error -> unknown end;
comparison({e_op, _, Op, L, {e_var, _, V}}) when element(1, L) =:= e_int; element(1, L) =:= e_neg; element(1, L) =:= e_op ->
    case const_int(L) of {ok, K} -> int_cmp(flip(Op), V, K); error -> unknown end;"""
s=s.replace(old,new)
h=open(d+'/b_helper_common.erl.txt').read()
if v in ('B2','B3'): h+=open(d+'/b_helper_arith.erl.txt').read()
h+=open(d+'/b_helper_tail.erl.txt').read()
if v in ('B2','B3'): h+=open(d+'/b_helper_bin.erl.txt').read()
if v=='B3':
    a2="type_of({e_neg, L, E}, S, C) ->"
    assert a2 in s
    s=s.replace(a2,"type_of({e_neg, _, {e_int, _, N}}, _S, _C) -> {bs_types:range(-N, -N), []};\n"+a2,1)
anchor="int_cmp('>',  V, K) ->"
assert anchor in s
s=s.replace(anchor,h+"\n"+anchor,1)
open(p,'w').write(s)
P
  build $V
done
cd $W
diff -u src/bs_parser.yrl v_A1/src/bs_parser.yrl > $D/fix_A1.patch || true
diff -u src/bs_parser.yrl v_A2/src/bs_parser.yrl > $D/fix_A2.patch || true
diff -u src/bs_check.erl  v_B1/src/bs_check.erl  > $D/fix_B1.patch || true
diff -u src/bs_check.erl  v_B2/src/bs_check.erl  > $D/fix_B2.patch || true
diff -u src/bs_check.erl  v_B3/src/bs_check.erl  > $D/fix_B3.patch || true
wc -l $D/fix_*.patch
