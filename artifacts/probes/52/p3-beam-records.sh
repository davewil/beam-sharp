#!/usr/bin/env bash
# P3: what does a B#-compiled .beam already record about its foreign dependencies?
# Positive: imports chunk (ImpT) lists the foreign MFA. Control: a module with NO foreign call lists no foreign module.
# Also dumps every chunk id + size, and the attributes chunk.
. "$(dirname "$0")/../lib.sh"
D=$(mktemp -d); cd "$D"; mkdir Dep NoDep
cat > Dep/a.bs <<'B'
module Dep
using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
using :lists {
    int sum(list<int> xs)
}
public term Go(list<(atom, term)> o)
Go(o) -> :'Elixir.Req'.new(o)
public int S(list<int> xs)
S(xs) -> :lists.sum(xs)
B
cat > NoDep/a.bs <<'B'
module NoDep
public int Id(int x)
Id(x) -> x
B
bsc -o out Dep/a.bs; bsc -o out NoDep/a.bs
ls -l out
for m in Dep NoDep; do
echo "=== $m chunks"
erl -noshell -eval '
{ok,{_,Cs}} = beam_lib:chunks("out/'$m'.beam",[imports,attributes,compile_info,exports,locals]),
io:format("~p~n",[Cs]),
L = beam_lib:info("out/'$m'.beam"),
[io:format("chunk ~s ~p bytes~n",[Id,Sz]) || {chunks,Ch} <- L, {Id,_,Sz} <- Ch],
halt().'
done
