#!/usr/bin/env bash
# Variant B: checker folds literal arithmetic (e_neg, + - * over int literals) in comparison/1.
f="$1/src/bs_check.erl"
python3 - "$f" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
old="""comparison({e_op, _, Op, {e_var, _, V}, {e_int, _, K}}) -> int_cmp(Op, V, K);
comparison({e_op, _, Op, {e_int, _, K}, {e_var, _, V}}) -> int_cmp(flip(Op), V, K);"""
new="""comparison({e_op, _, Op, {e_var, _, V}, R}) when element(1, R) =/= e_atom, element(1, R) =/= e_var ->
    case fold_int(R) of {ok, K} -> int_cmp(Op, V, K); error -> unknown end;
comparison({e_op, _, Op, L, {e_var, _, V}}) when element(1, L) =/= e_atom, element(1, L) =/= e_var ->
    case fold_int(L) of {ok, K} -> int_cmp(flip(Op), V, K); error -> unknown end;"""
assert old in s
s=s.replace(old,new)
s=s.replace("int_cmp('>',  V, K) ->","""fold_int({e_int, _, K})      -> {ok, K};
fold_int({e_neg, _, E})      -> case fold_int(E) of {ok, K} -> {ok, -K}; error -> error end;
fold_int({e_op, _, Op, A, B}) when Op =:= '+'; Op =:= '-'; Op =:= '*' ->
    case {fold_int(A), fold_int(B)} of
        {{ok, X}, {ok, Y}} -> {ok, case Op of '+' -> X + Y; '-' -> X - Y; '*' -> X * Y end};
        _ -> error
    end;
fold_int(_) -> error.

int_cmp('>',  V, K) ->""",1)
open(p,'w').write(s)
PY
