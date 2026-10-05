#!/usr/bin/env bash
# gen_sz.sh N OUTDIR : writes module SzN with N public two-clause functions ScoreAtKValue(int) (boundary guard, 2 clauses)
N=$1; D=$2; mkdir -p "$D/Sz$N"
{ echo "module Sz$N"; echo
  for k in $(seq 1 $N); do
    echo "public int ScoreAt${k}Value(int n)"
    echo "ScoreAt${k}Value(n) when n > $k -> n - $k"
    echo "ScoreAt${k}Value(n) -> $k - n"
    echo
  done; } > "$D/Sz$N/sz$N.bs"
