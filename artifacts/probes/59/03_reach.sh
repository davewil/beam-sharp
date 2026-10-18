#!/usr/bin/env bash
# 03 — the ticket's second argument, run: "a forged record can reach a private
# function by being passed through an exported one". Four attempts, best first.
HERE0="$(cd "$(dirname "$0")" && pwd)"; source "$HERE0/lib.sh"; cd "$WORK"
run() { erl -noshell -pa "$WORK/$1/out" -eval "$2" -eval 'halt().' 2>&1 | head -${3:-8}; }

echo "=== A. exported takes list<Order>; the exported guard sees only a top-level single record"
mod Nest <<'B'
module Nest

record Order { Id: int, Total: int }

public int SumTotals(list<Order> os)
SumTotals([]) -> 0
SumTotals([o, ..rest]) -> Inner(o) + SumTotals(rest)

private int Inner(Order o)
Inner(o) -> o.Total

public int SumInts(list<int> xs)
SumInts([]) -> 0
SumInts([n, ..rest]) -> Add(n) + SumInts(rest)

private int Add(int n)
Add(n) -> n + 1
B
bsc_compile Nest | head; [ -e Nest/out/Nest.beam ] || { echo COMPILE FAILED; exit 1; }
erl -noshell -eval '
   {ok,Forms}=file:consult(hd(filelib:wildcard("'$WORK'/Nest/out/*.abstr"))),
   [io:format("~s~n",[erl_pp:form(Fm)]) || {function,_,N,_,_}=Fm <- Forms, lists:member(atom_to_list(N),["SumTotals","Inner","SumInts","Add"])],
   halt().' | head -40
run Nest '
 T = fun(L, F) -> R = try F() catch C:E -> {C,E} end, io:format("~-52s ~p~n",[L, R]) end,
 Good = #{'"'Kind'"' => '"'Nest.Order'"', '"'Id'"' => 1, '"'Total'"' => 7},
 Forged = #{'"'Kind'"' => '"'Elsewhere.Thing'"', '"'Id'"' => 1, '"'Total'"' => 1000},
 T("SumTotals([Good])",                 fun() -> '"'Nest'"':'"'SumTotals'"'([Good]) end),
 T("SumTotals([Good, Forged])  (tag test in private Inner)", fun() -> '"'Nest'"':'"'SumTotals'"'([Good, Forged]) end),
 T("SumInts([1,2])",                    fun() -> '"'Nest'"':'"'SumInts'"'([1,2]) end),
 T("SumInts([1,2.5])  (no kind test in private Add)", fun() -> '"'Nest'"':'"'SumInts'"'([1,2.5]) end)' 12

echo
echo "=== B. exported term -> private Order: does the CHECKER let a term reach it?"
mod Fwd <<'B'
module Fwd

record Order { Id: int, Total: int }

public int Outer(term t)
Outer(t) -> Inner(t)

private int Inner(Order o)
Inner(o) -> o.Total
B
bsc_compile Fwd | head -8

echo
echo "=== C. a foreign return declared as Order (the other way a foreign value could arrive)"
mod Fgn <<'B'
module Fgn

record Order { Id: int, Total: int }

using :maps {
    Order new()
}

public int Run()
Run() -> Inner(:maps.new())

private int Inner(Order o)
Inner(o) -> o.Total
B
bsc_compile Fgn | head -8

echo
echo "=== D. a structural lookalike { Id, Total } (no Kind) offered where Order is wanted"
mod Look <<'B'
module Look

record Order { Id: int, Total: int }

type Loose = { Id: int, Total: int }

public int Outer(Loose l)
Outer(l) -> Inner(l)

private int Inner(Order o)
Inner(o) -> o.Total
B
bsc_compile Look | head -8

echo
echo "=== E. exported term, narrowed by validation, then handed to the private function"
mod Val <<'B'
module Val

record Order { Id: int, Total: int }

public int Outer(term t)
Outer(t) -> Check(ValidateAs<Order>(t))

private int Check(result<Order, ValidationError> r)
Check((:error, _)) -> -1
Check(o) -> Inner(o)

private int Inner(Order o)
Inner(o) -> o.Total
B
bsc_compile Val | head -8
[ -e Val/out/Val.beam ] && erl -noshell -pa Val/out -eval '
  io:format("forged map, no Kind:  ~p~n",[catch '"'Val'"':'"'Outer'"'(#{'"'Id'"'=>1,'"'Total'"'=>2})]),
  io:format("wrong Kind:           ~p~n",[catch '"'Val'"':'"'Outer'"'(#{'"'Kind'"'=>'"'X'"','"'Id'"'=>1,'"'Total'"'=>2})]),
  halt().' 2>&1 | head -8
