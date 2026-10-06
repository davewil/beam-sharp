#!/usr/bin/env bash
# 57a: Claim (ticket 57, measured 2026-08-23): every refinement containing a negative int
# literal is refused; `value != 0` and a positive disjoint union are accepted; the pattern
# `<= -1` is accepted. Re-run 2026-10-06 against the current compiler.
# Controls: the accepted rows (a probe that cannot go green is worthless) and the
# NotEqZero row, which must also *reject* a zero argument (ZeroRejected).
# Also tests the neighbours the ticket did not: guard `when n >= -5`, arithmetic comparands.
# Run from repo root:  source <scratch>/env.sh; artifacts/probes/57/57a_repro_table.sh
set -u
. "$(dirname "$0")/lib.sh"
echo "== ticket's table =="
probe NegSingle refused 'type T = int where value >= -5
public int Id(T b)
Id(b) -> b'
probe NegAnd refused 'type T = int where value >= -5 and value <= 5
public int Id(T b)
Id(b) -> b'
probe NegOr refused 'type T = int where value >= 1 or value <= -1
public int Id(T b)
Id(b) -> b'
probe DisjointPos accepted 'type T = int where value <= 3 or value >= 10
public int Id(T b)
Id(b) -> b'
probe NotEqZero accepted 'type T = int where value != 0
public int Id(T b)
Id(b) -> b'
probe ZeroRejected refused 'type T = int where value != 0
public int Id(T b)
public int Go()
Id(b) -> b
Go() -> Id(0)'
probe NegPattern accepted 'public atom Sign(int n)
Sign(>= 0) -> :nonneg
Sign(<= -1) -> :neg'
echo "== neighbours: where does an unread comparand stop? (refinement site) =="
probe Flipped refused 'type T = int where -5 <= value
public int Id(T b)
Id(b) -> b'
probe Sum refused 'type T = int where value >= 2 + 3
public int Id(T b)
Id(b) -> b'
probe ParenNeg refused 'type T = int where value >= -(5)
public int Id(T b)
Id(b) -> b'
probe DoubleNeg refused 'type T = int where value >= - -5
public int Id(T b)
Id(b) -> b'
probe ZeroMinus refused 'type T = int where value >= 0 - 5
public int Id(T b)
Id(b) -> b'
probe VarComparand refused 'public int Go(int n)
type T = int where value >= n
Go(n) -> n'
probe NegFloat refused 'type T = float where value >= -0.5
public float Id(T b)
Id(b) -> b'
echo "== neighbours: guard site =="
# a guard that is UNREADABLE is accepted but credits no coverage, so exhaustiveness is the test
probe GuardPosCovers accepted 'public atom S(int n)
S(n) when n >= 5 -> :a
S(n) when n < 5 -> :b'
# NEW FINDING: the same defect lives in guards: `n >= -5` is unreadable so credits nothing.
probe GuardNegCovers refused 'public atom S(int n)
S(n) when n >= -5 -> :a
S(n) when n < -5 -> :b'
probe PatternNegCovers accepted 'public atom S(int n)
S(>= -5) -> :a
S(< -5) -> :b'
probe GuardNegWithCatchAll accepted 'public atom S(int n)
S(n) when n >= -5 -> :a
S(n) -> :b'
echo "fails=$fails"
