#!/usr/bin/env bash
# 02 — can a value that no checked B# call site ever saw reach a PRIVATE function?
#
# ticket 59, "It is a defect" side: "A private function's every call site is a
# checked beam-sharp call site, so site 1 has already rejected a wrong tag".
# LANGUAGE.md "A function as a value — shipped" (F46) lets a private function's
# name leave the module as a fun (`Rule(:staff) -> Free`). Whoever holds the fun
# calls it with anything. Here: export the fun, then call it from plain Erlang.
HERE0="$(cd "$(dirname "$0")" && pwd)"; source "$HERE0/lib.sh"
mod Esc <<'B'
module Esc

record Order { Id: int, Total: int }

type Octet = int where value >= 0 and value <= 255

public fn(Order) -> int TotalOf()
TotalOf() -> Inner/1

private int Inner(Order o)
Inner(o) -> o.Total

public fn(int) -> int Doubler()
Doubler() -> Twice/1

private int Twice(int n)
Twice(n) -> n + n

public fn(Octet) -> int DoublerRange()
DoublerRange() -> Narrow/1

private int Narrow(Octet n)
Narrow(>= 100) -> 1
Narrow(<= 99) -> 0
B
bsc_compile Esc | head -20
cd "$WORK"   # erl_crash.dump lands here, not in the repo
[ -e "$WORK/Esc/out/Esc.beam" ] || { echo 'COMPILE FAILED'; exit 1; }
OUT=$WORK/Esc/out
erl -noshell -pa $OUT -eval '
 T = fun(Label, F) -> R = try F() catch C:E -> {C,E} end, io:format("~-46s ~p~n",[Label, R]) end,
 FOrder = '"'Esc'"':'"'TotalOf'"'(),
 FTwice = '"'Esc'"':'"'Doubler'"'(),
 FNarrow = '"'Esc'"':'"'DoublerRange'"'(),
 T("TotalOf, a real Order",            fun() -> FOrder(#{'"'Kind'"' => '"'Esc.Order'"', '"'Id'"' => 1, '"'Total'"' => 7}) end),
 T("TotalOf, WRONG tag, has Total",     fun() -> FOrder(#{'"'Kind'"' => '"'Other.Thing'"', '"'Id'"' => 1, '"'Total'"' => 7}) end),
 T("Twice(2) via escaped fun",          fun() -> FTwice(2) end),
 T("Twice(1.5) via escaped fun",        fun() -> FTwice(1.5) end),
 T("Twice(foo) via escaped fun",        fun() -> FTwice(foo) end),
 T("Narrow(100.5) via escaped fun",     fun() -> FNarrow(100.5) end),
 T("Narrow(1000) via escaped fun (>255)", fun() -> FNarrow(1000) end),
 halt().'
echo "--- the guards the private functions carry:"
erl -noshell -eval '
   {ok,Forms}=file:consult(hd(filelib:wildcard("'$WORK'/Esc/out/*.abstr"))),
   [io:format("~s~n",[erl_pp:form(Fm)]) || {function,_,N,_,_}=Fm <- Forms, lists:member(atom_to_list(N),["Inner","Twice","Narrow"])],
   halt().' | head -30
