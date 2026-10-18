#!/usr/bin/env bash
# 02b — the second way a private function is reached by a value no B# call site checked:
# its name is handed to a FOREIGN higher-order function whose declaration says the
# collection is `list<term>`.  Whatever the list holds is applied to the private fn.
HERE0="$(cd "$(dirname "$0")" && pwd)"; source "$HERE0/lib.sh"; cd "$WORK"
mod Cb <<'B'
module Cb

using :lists {
    list<term> map(fn(int) -> int f, list<term> xs)
}

public list<term> Run(list<term> xs)
Run(xs) -> :lists.map(Twice/1, xs)

private int Twice(int n)
Twice(n) -> n + n
B
bsc_compile Cb | head -8
[ -e Cb/out/Cb.beam ] || { echo COMPILE FAILED; exit 1; }
erl -noshell -pa Cb/out -eval '
  io:format("Run([1,2])          -> ~p~n",[catch '"'Cb'"':'"'Run'"'([1,2])]),
  io:format("Run([1, 2.5])       -> ~p~n",[catch '"'Cb'"':'"'Run'"'([1,2.5])]),
  io:format("Run([1, foo])       -> ~p~n",[catch '"'Cb'"':'"'Run'"'([1,foo])]),
  halt().' 2>&1 | head
