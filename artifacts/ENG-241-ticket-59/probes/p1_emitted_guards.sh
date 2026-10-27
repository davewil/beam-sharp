#!/usr/bin/env bash
# H1: bsc (shimmed build, OTP 25) puts the record TAG test on private Total/1 and the
#     is_integer KIND test only on exported BigOf/1 (not on private Big/1), and the
#     exported SumTotals/SumBig put NO per-element test on a list parameter.
# Falsifier: any CHECK line below reads FAIL (script exits 1).
# Command: ./p1_emitted_guards.sh   (BSC=path to the shimmed bsc escript)
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
BSC=${BSC:-/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/bsc/_build/default/bin/bsc}
OUT=$(mktemp -d)
cd "$HERE/bs" && "$BSC" -o "$OUT" --src-root . P59 >/dev/null || exit 2
escript "$HERE/guard_shape.escript" "$OUT/P59.abstr"
