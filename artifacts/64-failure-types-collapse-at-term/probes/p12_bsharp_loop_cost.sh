#!/usr/bin/env bash
# P12: the same 1M-lookup loop written in B# under (a) today's bare option<int> and (b) a tagged Maybe<int>=(:some,T)|:nothing,
# run end-to-end through bsc (VM boot + compile included, so compare to the N=0 baseline in the same run).
. "$(dirname "$0")/lib.sh"
mk LoopBare <<'SRC'
module LoopBare

private option<int> Probe(int i)
Probe(i) when i % 2 == 1 -> i * 2
Probe(i) -> :nothing

private int Loop(int i, int n, int acc)
Loop(i, n, acc) when i > n -> acc
Loop(i, n, acc) -> Loop(i + 1, n, Probe(i) switch { :nothing => acc, v => acc + v })

public int Run(int n)
Run(n) -> Loop(1, n, 0)
SRC
mk LoopTag <<'SRC'
module LoopTag

type Maybe<T> = (:some, T) | :nothing

private Maybe<int> Probe(int i)
Probe(i) when i % 2 == 1 -> (:some, i * 2)
Probe(i) -> :nothing

private int Loop(int i, int n, int acc)
Loop(i, n, acc) when i > n -> acc
Loop(i, n, acc) -> Loop(i + 1, n, Probe(i) switch { :nothing => acc, (:some, v) => acc + v })

public int Run(int n)
Run(n) -> Loop(1, n, 0)
SRC
now () { date +%s%N; }
for m in LoopBare LoopTag; do
  for n in 0 1000000 10000000; do
    ts=()
    for r in 1 2 3 4 5; do s=$(now); out=$($BSC "$W/$m" Run $n 2>&1 | tail -1); e=$(now); ts+=($(( (e-s)/1000000 ))); done
    sorted=$(printf '%s\n' "${ts[@]}" | sort -n | tr '\n' ' ')
    echo "$m N=$n result=$out wall_ms(sorted of 5)= $sorted"
  done
done
