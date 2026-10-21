#!/usr/bin/env bash
# Verifier's own probe for ticket 57 (not written by the brief's author).
# Usage: PROBE_HOME=... BSC_EBIN=.../ebin artifacts/verification/57-extra.sh
# Expect column: the CORRECT outcome. Includes NEGATIVE controls (must stay refused) so a fold
# that merely accepts everything is caught, and a boundary pair that detects a wrong-signed fold.
. "$(cd "$(dirname "$0")" && pwd)/../probes/lib.sh"
probe GtPair        accepted 'public atom S(int n)
S(n) when n > -1 -> :a
S(n) when n <= -1 -> :b'
probe GapGuard      refused  'public atom S(int n)
S(n) when n < -1 -> :a
S(n) when n > -1 -> :b'
probe OverlapLeft   accepted 'public atom S(int n)
S(n) when -1 <= n -> :a
S(n) when n < -1 -> :b'
probe LeftLit       accepted 'type T = int where -5 <= value
public int Id(T x)
Id(x) -> x'
probe LeftBoth      accepted 'type T = int where -5 <= value and 5 >= value
public int Id(T x)
Id(x) -> x'
# boundary: T = [-5, inf). -5 must be admitted, -6 must be refused (checks fold sign/bound is right)
probe BoundIn       accepted 'type T = int where value >= -5
public int Id(T x)
Id(x) -> x
public int Use()
Use() -> Id(-5)'
probe BoundOut      refused  'type T = int where value >= -5
public int Id(T x)
Id(x) -> x
public int Use()
Use() -> Id(-6)'
# a wrong fold (e.g. +5) would accept this; the true set is value<=-1 so 0 is out
probe NegUpperOut   refused  'type T = int where value <= -1
public int Id(T x)
Id(x) -> x
public int Use()
Use() -> Id(0)'
probe NegUpperIn    accepted 'type T = int where value <= -1
public int Id(T x)
Id(x) -> x
public int Use()
Use() -> Id(-1)'
# exhaustiveness through a refinement with a negative bound: Neg covers only <=-1, so Sign over it needs just one arm
probe RefinedExh    accepted 'type Neg = int where value <= -1
public atom F(Neg n)
F(n) when n < -1 -> :lo
F(n) when n >= -1 -> :m1'
echo "fails=$fails"
