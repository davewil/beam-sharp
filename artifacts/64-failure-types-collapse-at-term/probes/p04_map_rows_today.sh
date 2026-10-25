#!/usr/bin/env bash
# P04: which Map rows exist today (HEAD 1429fdc) at map<string, term>; what a caller does with Map.Has
. "$(dirname "$0")/lib.sh"
try () { echo "=== $1"; $BSC "$W/$1" "${@:2}" 2>&1 | head -8; }
mk MGet <<'SRC'
module MGet
public term A(map<string, term> m)
A(m) -> Map.Get(m, "k")
SRC
try MGet
mk MQGet <<'SRC'
module MQGet
public option<int> A(map<string, int> m)
A(m) -> Map.?Get(m, "k")
SRC
try MQGet
mk MHas <<'SRC'
module MHas
public bool H(map<string, term> m, string k)
H(m, k) -> Map.Has(m, k)
SRC
try MHas
mk MPut <<'SRC'
module MPut
public map<string, term> P(map<string, term> m)
P(m) -> Map.Put(m, "k", 1)
public list<(string, term)> L(map<string, term> m)
L(m) -> Map.ToList(m)
public map<string, term> F()
F() -> Map.FromList([("a", 1), ("b", :x)])
public list<(string, term)> Run()
Run() -> Map.ToList(F())
SRC
try MPut; try MPut Run
