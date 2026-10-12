#!/usr/bin/env bash
# Probe 64/03 - where else does the term-collapse appear, and which positions does the F31 refusal reach?
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; REPO="$(cd "$HERE/../../../.." && pwd)"
BSC="$REPO/compiler/_build/default/bin/bsc"
echo "git HEAD: $(git -C $REPO log --oneline -1)"
W=$(mktemp -d); trap 'rm -rf $W' EXIT
one(){ # name, body (stdin)
  mkdir -p $W/$1; { echo "module $1"; cat; } > $W/$1/$1.bs
  echo; echo "=== $1 ==="; sed 1d $W/$1/$1.bs | sed 's/^/  | /'
  out=$("$BSC" --api $W/$1 2>&1); echo "$out" | sed "s|$W/||; s/^/  /" | head -8
}
one R1_RecordField <<'B'
record Doc { Extra: option<term> }
public int Use(Doc d)
Use(d) -> 0
B
one R2_TupleNested <<'B'
public (option<term>, int) Pair(int n)
Pair(n) -> (:nothing, n)
B
one R3_ListOfOption <<'B'
public list<option<term>> Xs(int n)
Xs(n) -> []
B
one R4_WireFieldOptionTerm <<'B'
type Wire = { "id": string, "extra": option<term>, .. }
public result<Wire, ValidationError> Read(term doc)
Read(doc) -> ValidateAs<Wire>(doc)
B
one R5_ValidateAsTerm <<'B'
public result<term, ValidationError> Read(term doc)
Read(doc) -> ValidateAs<term>(doc)
B
one R6_ValidateAsOptionTerm <<'B'
public term Read(term doc)
Read(doc) -> ValidateAs<option<term>>(doc)
B
one R7_MapValueOptionTerm <<'B'
public int M(map<string, option<term>> m)
M(m) -> 0
B
one R8_TaggedPairOK <<'B'
public (:some, term) | :nothing Find(int k)
Find(k) -> :nothing
B
one R9_ParametricAliasMaybe <<'B'
type Maybe<T> = (:some, T) | :nothing
public Maybe<term> Find(int k)
Find(k) -> :nothing
public Maybe<int> FindI(int k)
FindI(k) -> (:some, 3)
B
