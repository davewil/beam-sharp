#!/usr/bin/env bash
# Probe 64/01 - what does CURRENT bsc do for each collapse-prone signature?
# Each case is its own one-file module; we report bsc --api and the compile diagnostics.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; REPO="$(cd "$HERE/../../../.." && pwd)"
BSC="$REPO/compiler/_build/default/bin/bsc"
echo "git HEAD: $(git -C $REPO log --oneline -1)"; ls -la --time-style=long-iso "$BSC" | awk '{print "bsc built:",$6,$7}'
W=$(mktemp -d); trap 'rm -rf $W' EXIT
mk(){ mkdir -p $W/$1; cat > $W/$1/$1.bs; }
case_(){ echo; echo "=== $1 ==="; sed 's/^/  | /' $W/$1/$1.bs; echo "  --- bsc --api:"; "$BSC" --api $W/$1 2>&1 | sed 's/^/  /'; echo "  --- bsc (compile):"; "$BSC" -o $W/out_$1 $W/$1 > $W/log_$1 2>&1; rc=$?; sed "s/^/  /" $W/log_$1; echo "  exit=$rc"; }
mk A_OptionInt <<'B'
module A_OptionInt
public option<int> FindI(int k)
FindI(k) -> :nothing
B
mk B_OptionTerm <<'B'
module B_OptionTerm
public option<term> FindT(int k)
FindT(k) -> :nothing
B
mk C_ResultTermAtom <<'B'
module C_ResultTermAtom
public result<term, atom> FindR(int k)
FindR(k) -> (:error, :missing)
B
mk D_ResultIntTerm <<'B'
module D_ResultIntTerm
public result<int, term> FindE(int k)
FindE(k) -> (:error, :missing)
B
mk E_ResultTermTerm <<'B'
module E_ResultTermTerm
public result<term, term> FindEE(int k)
FindEE(k) -> (:error, :missing)
B
mk F_ResultAtomTerm <<'B'
module F_ResultAtomTerm
public result<atom, term> FindAT(int k)
FindAT(k) -> (:error, :missing)
B
mk G_ResultTermBinary <<'B'
module G_ResultTermBinary
public result<term, binary> FindTB(int k)
FindTB(k) -> (:error, "x")
B
mk H_Handrolled <<'B'
module H_Handrolled
type Found = (:ok, term) | :absent
public Found FindF(int k)
FindF(k) -> :absent
B
mk I_AliasOptionTerm <<'B'
module I_AliasOptionTerm
type MaybeTerm = option<term>
public int Use(MaybeTerm m)
Use(m) -> 0
B
mk J_MapStringTermParam <<'B'
module J_MapStringTermParam
public term Look(map<string, term> m, string k)
Look(m, k) -> :absent
B
for c in A_OptionInt B_OptionTerm C_ResultTermAtom D_ResultIntTerm E_ResultTermTerm F_ResultAtomTerm G_ResultTermBinary H_Handrolled I_AliasOptionTerm J_MapStringTermParam; do case_ $c; done
