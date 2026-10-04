#!/usr/bin/env bash
# Claim: the same literal in a guard behaves how?  A guard goes through alternatives/1
# (apply_guard), so an unread guard credits NO coverage (bs_check.erl ~4918). Measure.
source "$(dirname "$0")/lib.sh"
probe GuardPos_Complete '
public atom F(int n)
F(n) when n >= 5 -> :hi
F(n) when n < 5  -> :lo'
probe GuardNeg_Complete '
public atom F(int n)
F(n) when n >= -5 -> :hi
F(n) when n < -5  -> :lo'
probe GuardNeg_WithCatchAll '
public atom F(int n)
F(n) when n >= -5 -> :hi
F(n) when n < -5  -> :lo
F(_) -> :other'
probe PatternNeg_Complete '
public atom F(int n)
F(>= -5) -> :hi
F(<= -6) -> :lo'
probe PatternPos_Complete '
public atom F(int n)
F(>= 5) -> :hi
F(<= 4) -> :lo'
probe GuardNeg_RunsFine '
public atom F(int n)
F(n) when n >= -5 -> :hi
F(_) -> :lo
' F -7
