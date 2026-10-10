#!/usr/bin/env bash
# Residual printing and re-pasteability with negative bounds. BSC=arg1.
#  R1: the residual of a refinement-typed param (only compiles where the refinement is writable)
#  R2: baseline-reachable: bare int, one clause -> residual has negative bounds; paste it back
#  R3: baseline-reachable bounded signed residual (no refinement needed)
BSC=${1:?bsc}
W=$(mktemp -d)
try() { # label source
  rm -rf $W/P; mkdir -p $W/P; printf '%s\n' "$2" > $W/P/p.bs
  out=$(cd $W && "$BSC" -o $W/out P 2>&1); printf '== %s rc=%s\n%s\n' "$1" $? "$(echo "$out"|head -8)"
}
try 'R1a Delta -10..10, only Sign(0)' 'module P

type Delta = int where value >= -10 and value <= 10

public atom Sign(Delta d)

Sign(0) -> :zero'
try 'R1b R1a with the printed heads pasted back' 'module P

type Delta = int where value >= -10 and value <= 10

public atom Sign(Delta d)

Sign(0) -> :zero
Sign(>= -10 and <= -1) -> :neg
Sign(>= 1 and <= 10) -> :pos'
try 'R2a bare int, only Sign(0)' 'module P

public atom Sign(int d)

Sign(0) -> :zero'
try 'R2b R2a with printed heads pasted back' 'module P

public atom Sign(int d)

Sign(0) -> :zero
Sign(<= -1) -> :neg
Sign(>= 1) -> :pos'
try 'R3a baseline-reachable bounded signed residual: bare int, three clauses leave -10..-1 | 1..10' 'module P

public atom Sign(int d)

Sign(<= -11) -> :low
Sign(>= 11) -> :high
Sign(0) -> :zero'
try 'R3b R3a with the printed heads pasted back' 'module P

public atom Sign(int d)

Sign(<= -11) -> :low
Sign(>= 11) -> :high
Sign(0) -> :zero
Sign(>= -10 and <= -1) -> :neg
Sign(>= 1 and <= 10) -> :pos'
