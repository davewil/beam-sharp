#!/usr/bin/env bash
# What exactly is printed for (a) `value == -3` and (b) a now-redundant catch-all after the fix?
# Compare with the same shapes using a POSITIVE literal on the unpatched bsc (control).
source "$(dirname "$0")/lib.sh"
mk () { printf '\ntype T = int where %s\npublic int Id(T b)\nId(b) -> b' "$1"; }
echo "### control, positive literal, current bsc"
probe EqPos "$(mk 'value == 3')"
probe CatchAllPos '
public atom F(int n)
F(n) when n >= 5 -> :hi
F(n) when n < 5  -> :lo
F(_) -> :other'
echo "### same shapes, negative literal, bsc=$BSC"
probe EqNeg "$(mk 'value == -3')"
probe CatchAllNeg '
public atom F(int n)
F(n) when n >= -5 -> :hi
F(n) when n < -5  -> :lo
F(_) -> :other'
