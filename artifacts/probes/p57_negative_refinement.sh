#!/usr/bin/env bash
# Ticket 57: which refinement spellings of a negative bound does the checker read?
# Re-runs the ticket's table on today's compiler (SHOW=1 prints the diagnostics), then probes
# the two candidate answers' reach: does a folded `2 + 3` / `0 - 5` / `-(5)` also fail?
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
probe Neg5        accepted 'type T = int where value >= -5
public int Id(T x)
Id(x) -> x'
probe NegBoth     accepted 'type T = int where value >= -5 and value <= 5
public int Id(T x)
Id(x) -> x'
probe NegDisj     accepted 'type T = int where value >= 1 or value <= -1
public int Id(T x)
Id(x) -> x'
probe Disj        accepted 'type T = int where value <= 3 or value >= 10
public int Id(T x)
Id(x) -> x'
probe NeZero      accepted 'type T = int where value != 0
public int Id(T x)
Id(x) -> x'
probe Sum         accepted 'type T = int where value >= 2 + 3
public int Id(T x)
Id(x) -> x'
probe Sub         accepted 'type T = int where value >= 0 - 5
public int Id(T x)
Id(x) -> x'
probe PatNeg      accepted 'public atom Sign(int n)
Sign(<= -1) -> :neg
Sign(_) -> :pos'
echo "(expected column states the DESIRED outcome; !! = today refuses/behaves otherwise)"
