#!/usr/bin/env bash
# Ticket 59, the other direction: the int KIND test is exported-only (F24). Does a float nested in a list reach
# a PRIVATE function's `>= 9` comparison unchecked? (Ticket 18: "a foreign term that breaks your types will crash -
# not always where it entered, but never silently".)
# Usage: BSC=<bsc> bash p4_int_kind_through_a_list.sh
set -u; here=$(cd "$(dirname "$0")" && pwd); BSC=${BSC:-$here/../../../compiler/_build/default/bin/bsc}
out=$(mktemp -d); "$BSC" -o "$out" "$here/prog/Kind59" || exit 1
erl -noshell -pa "$out" -eval '
  T = fun(L, F) -> io:format("~-58s ~p~n", [L, try F() catch C:R -> {C,R} end]) end,
  T("Total([10])          int in a list",               fun() -> '"'"'Kind59'"'"':'"'"'Total'"'"'([10]) end),
  T("Total([100.5])       FLOAT in a list -> private Band", fun() -> '"'"'Kind59'"'"':'"'"'Total'"'"'([100.5]) end),
  T("BandOut(100.5)       FLOAT direct -> exported guard",  fun() -> '"'"'Kind59'"'"':'"'"'BandOut'"'"'(100.5) end),
  halt().'
