#!/usr/bin/env bash
# Ticket 57 / design intent: `alternatives/1` (bs_check.erl) is shared by refinements AND clause guards.
# Hypothesis (from reading the code, so a probe must confirm it): a guard containing -5 is "unknown",
# credits no coverage, and an otherwise exhaustive function is refused as inexhaustive. If true, folding in
# the GRAMMAR (refinement-only) leaves guards broken; folding in the CHECKER's comparison/1 repairs both.
# Control pair: identical program with the literal non-negative (shifted by +5 bound) must be accepted.
set -u; here=$(cd "$(dirname "$0")" && pwd); BSC=${BSC:-$here/../../../compiler/_build/default/bin/bsc}; . "$here/lib.sh"
echo "== guard with a negative literal, two clauses that cover int between them"
try G1 'public atom F(int n)
F(n) when n >= -5 -> :a
F(n) when n < -5 -> :b'
echo "== control: same shape, non-negative literal"
try G2 'public atom F(int n)
F(n) when n >= 5 -> :a
F(n) when n < 5 -> :b'
echo "== control: negative literal in a guard but a catch-all clause follows (no coverage claim needed)"
try G3 'public atom F(int n)
F(n) when n >= -5 -> :a
F(n) -> :b'
echo "== the pattern form of the same split"
try G4 'public atom F(int n)
F(>= -5) -> :a
F(< -5) -> :b'
