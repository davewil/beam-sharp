#!/usr/bin/env bash
# Fix B changes what `-5` IS in a function body (e_neg -> e_int). Does anything observable move?
BSC=${1:?bsc}
W=$(mktemp -d); mkdir $W/P
cat > $W/P/p.bs <<'EOS'
module P

public int A()
A() -> -5

public int B(int x)
B(x) -> x - -5

public int C(int x)
C(x) -> -x

public int D()
D() -> 3 - 5 * -2

public int E()
E() -> -(-5)
EOS
cd $W; "$BSC" -o out P; echo "compile rc=$?"
for f in A D E; do printf '%s() = ' $f; "$BSC" -o out P $f 2>&1 | head -1; done
printf 'B(10) = '; "$BSC" -o out P B 10 2>&1 | head -1
printf 'C(7) = ';  "$BSC" -o out P C 7 2>&1 | head -1
erl -noshell -pa out -eval '{ok,{_,[{abstract_code,{_,F}}]}}=beam_lib:chunks("out/P.beam",[abstract_code]), io:format("~p~n",[[X||{function,_,N,_,_}=X<-F, N=:='"'"'A'"'"']]),halt().' 2>&1 | head -8
