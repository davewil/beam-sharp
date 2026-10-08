#!/usr/bin/env bash
# Ticket 57 probes: which refinements with negative literals does the checker accept?
. "$(dirname "$0")/../lib.sh"
probe NegGe refused  'type T = int where value >= -5
public int Id(T x)
Id(x) -> x'
probe PosGe accepted 'type T = int where value >= 5
public int Id(T x)
Id(x) -> x'
probe DisjointPos accepted 'type T = int where value <= 3 or value >= 10
public int Id(T x)
Id(x) -> x'
probe NeqZero accepted 'type T = int where value != 0
public int Id(T x)
Id(x) -> x'
probe SubFold refused 'type T = int where value >= 0 - 5
public int Id(T x)
Id(x) -> x'
probe PlusFold refused 'type T = int where value >= 2 + 3
public int Id(T x)
Id(x) -> x'
probe PatNeg accepted 'public atom Sign(int n)
Sign(<= -1) -> :neg
Sign(_) -> :nonneg'
