#!/usr/bin/env bash
# P16: MODIFIED COMPILER #2 (scratch; delta2_peekopt.diff adds, on top of P15's rows, a TYPE-ONLY row
#  Map.PeekOpt  "option<V> PeekOpt<K,V>(map<K,V> m, K k)"  standing in for the unbuilt Map.?Get of ticket 108.
# (Runtime shape is irrelevant here: only the checker's verdict at V=int vs V=term is measured.)
. "$(dirname "$0")/lib.sh"
D=$S/64/delta2/bsc
mk Pk <<'SRC'
module Pk
public option<int> OnInt(map<string, int> m)
OnInt(m) -> Map.PeekOpt(m, "k")
public term OnTerm(map<string, term> m)
OnTerm(m) -> Map.PeekOpt(m, "k")
public atom Use(map<string, term> m)
Use(m) -> Map.PeekOpt(m, "k") switch { :nothing => :absent, v => :present }
SRC
$D "$W/Pk" --api 2>&1 | sed "s#$W/##" | head -12
