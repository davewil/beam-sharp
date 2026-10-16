#!/usr/bin/env bash
# 59 / behaviour — a forged record reaching a PRIVATE function through an exported one.
#   behave.sh LABEL PATH_TO_BSC
# SumAll(list<Order>) guards nothing about its elements (the boundary tests a single closed
# record parameter only), so the private Inner(Order) tag test is the only defence on that route.
set -uo pipefail
L=$1; B=$2; O=$(mktemp -d); trap 'rm -rf "$O"' EXIT
"$B" -o "$O" src/G59/g.bs 2>/dev/null
erl -noshell -pa "$O" -eval '
Good = #{'"'"'Kind'"'"' => '"'"'G59.Order'"'"', '"'"'Id'"'"' => 1, '"'"'Total'"'"' => 7},
Forged = #{'"'"'Kind'"'"' => '"'"'Other.Thing'"'"', '"'"'Id'"'"' => 1, '"'"'Total'"'"' => 99},
NoKind = #{'"'"'Id'"'"' => 1, '"'"'Total'"'"' => 5},
T = fun(Tag, F) -> R = try F() catch C:E -> {C, case E of {Rn,_} -> Rn; Rn -> Rn end} end, io:format("  ~-34s -> ~p~n", [Tag, R]) end,
io:format("[~s]~n", ["'"$L"'"]),
T("SumAll([good])",              fun() -> '"'"'G59'"'"':'"'"'SumAll'"'"'([Good]) end),
T("SumAll([forged tag])",        fun() -> '"'"'G59'"'"':'"'"'SumAll'"'"'([Forged]) end),
T("SumAll([map with no Kind])",  fun() -> '"'"'G59'"'"':'"'"'SumAll'"'"'([NoKind]) end),
T("One(forged tag)  (exported)", fun() -> '"'"'G59'"'"':'"'"'One'"'"'(Forged) end),
T("SumB([300])  (nested, out of range)", fun() -> '"'"'G59'"'"':'"'"'SumB'"'"'([300]) end),
T("SumB([2.5]) (nested, a float)", fun() -> '"'"'G59'"'"':'"'"'SumB'"'"'([2.5]) end),
T("SumC([300]) (nested, NO private call)", fun() -> '"'"'G59'"'"':'"'"'SumC'"'"'([300]) end),
T("Pub(3.5)         (exported)", fun() -> '"'"'G59'"'"':'"'"'Pub'"'"'(3.5) end),
halt().'
