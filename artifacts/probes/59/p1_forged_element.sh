#!/usr/bin/env bash
# Ticket 59: can a forged record reach a PRIVATE function through an exported one?
# Compiles prog/Shop59 with a given bsc, then drives the exported functions from Erlang with
#   (a) a well-formed Order, (b) an Invoice-tagged map with Order's field set (wrong tag), nested in a list,
#   (c) the same forged map passed directly to the exported record-parameter twin (the entry guard).
# Usage: BSC=<bsc> bash p1_forged_element.sh
set -u; here=$(cd "$(dirname "$0")" && pwd); BSC=${BSC:-$here/../../../compiler/_build/default/bin/bsc}
out=$(mktemp -d); "$BSC" -o "$out" "$here/prog/Shop59" || exit 1
erl -noshell -pa "$out" -eval '
  Good   = #{'"'"'Kind'"'"' => '"'"'Shop59.Order'"'"',   '"'"'Id'"'"' => 1, '"'"'Total'"'"' => 7},
  Forged = #{'"'"'Kind'"'"' => '"'"'Shop59.Invoice'"'"', '"'"'Id'"'"' => 2, '"'"'Total'"'"' => 100},
  T = fun(L, F) -> io:format("~-52s ~p~n", [L, try F() catch C:R -> {C,R} end]) end,
  T("SumAll([Good])  (well-formed)",                       fun() -> '"'"'Shop59'"'"':'"'"'SumAll'"'"'([Good]) end),
  T("SumAll([Forged]) forged element, via private One/1",  fun() -> '"'"'Shop59'"'"':'"'"'SumAll'"'"'([Forged]) end),
  T("Direct(Forged)   forged, exported record parameter",  fun() -> '"'"'Shop59'"'"':'"'"'Direct'"'"'(Forged) end),
  halt().'
