#!/usr/bin/env bash
# Verifier probes (new). Usage: BSC=<bsc> bash v1_new_probes.sh
set -u; here=$(cd "$(dirname "$0")" && pwd); out=$(mktemp -d); "$BSC" -o "$out" "$here/prog/V1" || exit 1
erl -noshell -pa "$out" -eval '
  O = fun(I,T) -> #{'"'"'Kind'"'"' => '"'"'V1.Order'"'"', '"'"'Id'"'"' => I, '"'"'Total'"'"' => T} end,
  F = #{'"'"'Kind'"'"' => '"'"'V1.Invoice'"'"', '"'"'Id'"'"' => 2, '"'"'Total'"'"' => 100},
  T = fun(L, Fn) -> io:format("~-46s ~p~n", [L, try Fn() catch C:R -> {C,R} end]) end,
  T("SumOct([5,6])",              fun() -> '"'"'V1'"'"':'"'"'SumOct'"'"'([5,6]) end),
  T("SumOct([300])  out of range",fun() -> '"'"'V1'"'"':'"'"'SumOct'"'"'([300]) end),
  T("SumOct([2.5])  float",       fun() -> '"'"'V1'"'"':'"'"'SumOct'"'"'([2.5]) end),
  T("DblOut(300) control",        fun() -> '"'"'V1'"'"':'"'"'DblOut'"'"'(300) end),
  T("DblOut(2.5) control",        fun() -> '"'"'V1'"'"':'"'"'DblOut'"'"'(2.5) end),
  T("ViaTuple({1,Good})",         fun() -> '"'"'V1'"'"':'"'"'ViaTuple'"'"'({1,O(1,7)}) end),
  T("ViaTuple({1,Forged}) tuple field -> One", fun() -> '"'"'V1'"'"':'"'"'ViaTuple'"'"'({1,F}) end),
  T("ViaField(#{O=>Good})",       fun() -> '"'"'V1'"'"':'"'"'ViaField'"'"'(#{'"'"'Kind'"'"'=>'"'"'V1.Box'"'"','"'"'O'"'"'=>O(1,7)}) end),
  T("ViaField(#{O=>Forged}) nested field -> One", fun() -> '"'"'V1'"'"':'"'"'ViaField'"'"'(#{'"'"'Kind'"'"'=>'"'"'V1.Box'"'"','"'"'O'"'"'=>F}) end),
  halt().'
