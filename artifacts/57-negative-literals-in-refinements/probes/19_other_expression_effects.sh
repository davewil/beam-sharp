#!/usr/bin/env bash
# Behaviour of a literal -N OUTSIDE refinements, per prototype. In base, `-5` is e_neg => typed `int`; with the grammar fold
# it is e_int(-5) => typed -5..-5 like any other literal.
source "$(dirname "$0")/lib.sh"
probe DivByNegZero '
public int F(int x)
F(x) -> x / -0' F 4
probe DivByNegThree '
public int F(int x)
F(x) -> x / -3' F 9
probe DivByPosZero '
public int F(int x)
F(x) -> x / 0' F 4
probe NegArith '
public int F()
F() -> -2 * 3 + -4' F
probe NegPrec '
public int F()
F() -> 10 - -3' F
probe NegLitTuple '
public (int, int) F()
F() -> (-1, -2)' F
probe NegAsRefinedReturn '
type Neg = int where value <= -1
public Neg F()
F() -> -5' F
probe NegZeroPat '
public atom F(int n)
F(-0) -> :zero
F(_) -> :other' F 0
probe BigNeg '
public int F()
F() -> -9223372036854775808' F
probe NegFloatStill '
public float F()
F() -> -0.0' F
