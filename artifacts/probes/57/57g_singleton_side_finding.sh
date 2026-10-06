#!/usr/bin/env bash
# 57g: SIDE FINDING (not ticket 57, found while building the 57e matrix): a refinement that
# (Expectations below record the CURRENT behaviour: the two singleton rows are "refused" = crash; a fix flips them.)
# denotes ONE integer (`value == 1`, `value >= 1 and value <= 1`) passes the checker and then the
# compile CRASHES with "bad range type" -- the emitted -spec says `1..1`, which erl_lint rejects.
# Controls: `value >= 1 and value <= 2` compiles (two integers); erlc on a hand-written `-spec f(1..1)`
# shows the rejection is Erlang's, not B#'s, and that `1..2` is fine.
# Run from repo root with env.sh sourced.
set -u
. "$(dirname "$0")/lib.sh"
probe Eq1       refused 'type T = int where value == 1
public int Id(T b)
Id(b) -> b'
probe Range1_1  refused 'type T = int where value >= 1 and value <= 1
public int Id(T b)
Id(b) -> b'
probe Range1_2  accepted 'type T = int where value >= 1 and value <= 2
public int Id(T b)
Id(b) -> b'
d=$(mktemp -d); printf -- '-module(r).\n-export([f/1]).\n-spec f(1..1) -> ok.\nf(1) -> ok.\n' > "$d/r.erl"
echo "-- erlc on -spec f(1..1):"; erlc -o "$d" "$d/r.erl" 2>&1 | sed "s#$d/##" | head -3
printf -- '-module(r2).\n-export([f/1]).\n-spec f(1..2) -> ok.\nf(1) -> ok.\n' > "$d/r2.erl"
echo "-- erlc on -spec f(1..2): rc=$(erlc -o "$d" "$d/r2.erl" >/dev/null 2>&1; echo $?)"
