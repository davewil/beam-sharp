#!/usr/bin/env bash
# The ticket's "residual doctrine" claim: for a signed bounded domain the compiler prints a residual the surface
# could not spell. With the fix the domain is declarable; is the printed residual pasteable and does the paste close it?
source "$(dirname "$0")/lib.sh"
D='type Delta = int where value >= -100 and value <= 100'
probe MissingNegatives "$D
public atom Sign(Delta d)
Sign(0) -> :zero
Sign(>= 1) -> :pos"
probe PastedNegatives "$D
public atom Sign(Delta d)
Sign(0) -> :zero
Sign(>= 1) -> :pos
Sign(<= -1) -> :neg"
probe DividesOutOfRange "$D
public int Half(Delta d)
Half(d) -> 100 / d"
probe NonZeroDelta "type Delta = int where value >= -100 and value <= 100 and value != 0
public int Inv(Delta d)
Inv(d) -> 100 / d"
probe NonZeroDeltaViaOr "type NzDelta = int where value >= -100 and value <= -1 or value >= 1 and value <= 100
public int Inv(NzDelta d)
Inv(d) -> 100 / d"
