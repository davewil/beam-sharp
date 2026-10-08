#!/bin/bash
# gen_tree.sh MODE N OUT : synthetic tree of N modules (N divisible by 5). Per group g: Core, Lib (or Internal.Lib) and 3 members.
# MODE: base (A-shaped: members call Syn.Gg.Core and Syn.Gg.Internal.Lib), baseB / B (members nested under Core; Core.Helper public / internal), C (base shape + friend lines on Lib)
mode=$1; n=$2; out=$3; g=$((n/5)); mkdir -p $out
w() { mkdir -p "$out/$1"; cat > "$out/$1/a.bs"; }
for ((i=0;i<g;i++)); do
  G=Syn.G$i; P=Syn/G$i
  case $mode in
  base|C)
    fr=""; [ $mode = C ] && fr=$'friend Syn.G'$i$'\n'
    w $P/Internal/Lib <<EOT
module $G.Internal.Lib
$fr
public int L(int n)
L(n) -> n + 1
EOT
    w $P/Core <<EOT
module $G.Core

public int Compute(int n)
Compute(n) -> n * 2
EOT
    for j in 1 2 3; do w $P/M$j <<EOT
module $G.M$j
using $G.Core
using $G.Internal.Lib

public int Go(int n)
Go(n) -> Compute(L(n)) + $j
EOT
    done;;
  baseB|B)
    v=public; [ $mode = B ] && v=internal
    w $P/Lib <<EOT
module $G.Lib

public int L(int n)
L(n) -> n + 1
EOT
    w $P/Core <<EOT
module $G.Core

public int Compute(int n)
Compute(n) -> n * 2

$v int Helper(int n)
Helper(n) -> n - 1
EOT
    for j in 1 2 3; do w $P/Core/M$j <<EOT
module $G.Core.M$j
using $G.Core
using $G.Lib

public int Go(int n)
Go(n) -> Compute(L(n)) + Helper(n) + $j
EOT
    done;;
  esac
done
