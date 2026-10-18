#!/usr/bin/env bash
# 01 — REPRODUCE: does a private function carry the record tag test today?
source "$(dirname "$0")/lib.sh"
mod Rep <<'B'
module Rep

record Order { Id: int, Total: int }

public int Outer(Order o)
Outer(o) -> Inner(o)

private int Inner(Order o)
Inner(o) -> o.Total

public int Plain(int n)
Plain(n) -> Twice(n)

private int Twice(int n)
Twice(n) -> n + n
B
bsc_compile Rep
echo "--- emitted Erlang (abstract -> source), Inner and Twice:"
show() { # show FILE_DIR FUNCTION... : pretty-print named functions of the .abstr as Erlang
  erl -noshell -eval '
   [F|Ns]=init:get_plain_arguments(),
   {ok,Forms}=file:consult(F),
   [io:format("~s~n",[erl_pp:form(Fm)]) || {function,_,N,_,_}=Fm <- Forms, lists:member(atom_to_list(N),Ns)],
   halt().' -extra "$@"
}
echo "--- emitted Erlang (from the .abstr bsc writes):"
show $(ls $WORK/Rep/out/*.abstr) Outer Inner Plain Twice 2>&1 | head -60
