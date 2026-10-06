#!/usr/bin/env bash
# 57b: Claim (NEW, not in ticket): the ticket's "-5 desugars to 0 - 5" is STALE. Since F51 the
# parser emits {e_neg,L,E}; a negated float literal folds, an int literal does not, and the
# checker types `-3` as plain `int`, not the singleton -3..-3. So a negative literal ARGUMENT
# is refused where the positive literal is accepted, even with a refinement that CAN be written.
# Control: the positive literal 2 passes the same boundary (so the refusal is about the sign).
# Run from repo root with env.sh sourced.
set -u
. "$(dirname "$0")/lib.sh"
probe PosLitArg accepted 'type T = int where value <= 3
public int Id(T b)
public int Go()
Id(b) -> b
Go() -> Id(2)'
probe NegLitArg accepted 'type T = int where value <= 3
public int Id(T b)
public int Go()
Id(b) -> b
Go() -> Id(-3)'
probe NegViaPatternTypeCtl accepted 'public atom Sign(int n)
Sign(<= -1) -> :neg
Sign(_) -> :other'
echo "-- the diagnostic on NegLitArg:"
$BSC --src-root "$WORK/src" -o "$WORK/oo" "$WORK/src/NegLitArg" 2>&1 | head -12
echo "-- and a direct return of -3 against a bounded return type spelled as a pattern-free refinement:"
probe NegLitReturn accepted 'type T = int where value >= 0 - 100
public int Go()
Go() -> -3'
echo "fails=$fails"
