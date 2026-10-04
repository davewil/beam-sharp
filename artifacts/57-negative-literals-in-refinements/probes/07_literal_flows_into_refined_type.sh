#!/usr/bin/env bash
# Declaring `type Delta = int where value >= -100 and value <= 100` is half the story:
# can a literal -5 then be PASSED, RETURNED and PATTERN-MATCHED as a Delta?
# type_of({e_int,_,N}) is the singleton N..N; type_of({e_neg,_,E}) is plain `int` (bs_check.erl:2867, 2874-2885).
# Run per variant: BSC=... bash 07_...sh
source "$(dirname "$0")/lib.sh"
D='type Delta = int where value >= -100 and value <= 100'
echo "### positive control (works today)"
probe PosCall "type Pos = int where value >= 1 and value <= 100
public int Id(Pos p)
Id(p) -> p
public int Go()
Go() -> Id(5)"
echo "### negative literal passed to Delta"
probe NegCall "$D
public int Id(Delta d)
Id(d) -> d
public int Go()
Go() -> Id(-5)" Go
probe NegCallOutOfRange "$D
public int Id(Delta d)
Id(d) -> d
public int Go()
Go() -> Id(-500)" Go
echo "### negative literal returned as Delta"
probe NegReturn "$D
public Delta Zero()
Zero() -> -5" Zero
echo "### binding it first"
probe NegViaVar "$D
public int Id(Delta d)
Id(d) -> d
public int Go()
Go() -> Id(0 - 5)" Go
echo "### Delta used as a clause head: residual with negative bounds"
probe DeltaClassify "$D
public atom Sign(Delta d)
Sign(<= -1) -> :neg
Sign(0) -> :zero
Sign(>= 1) -> :pos" Sign -3
