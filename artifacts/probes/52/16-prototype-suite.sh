#!/usr/bin/env bash
# The PROTOTYPE patch must not break the repo's own suite. Runs `rebar3 eunit` in the patched COPY (slow; opt-in:
# RUN_EUNIT=1 ./16-prototype-suite.sh).  REFUTED IF: any test fails that the unpatched tree passes.
# (The baseline is run too, in a second copy, so a pre-existing failure is not blamed on the patch.)
. "$(dirname "$0")/lib.sh"
[ "${RUN_EUNIT:-0}" = 1 ] || { echo "skipped (set RUN_EUNIT=1)"; exit 0; }
B=$WORK/baseline; rm -rf "$B"; mkdir -p "$B"; ( cd /home/user/beam-sharp/compiler && tar cf - --exclude=_build . ) | tar xf - -C "$B"
clean() { sed 's/\x1b\[[0-9;]*m//g' | grep -E "tests passed|Failed|failed|passed|===> Error" | tail -4; }
echo "### patched copy"; ( cd "$WORK/patched/compiler" && T0=$(date +%s); rebar3 eunit 2>&1 | clean; echo "wall $(( $(date +%s)-T0 ))s" )
echo "### baseline copy"; ( cd "$B" && T0=$(date +%s); rebar3 eunit 2>&1 | clean; echo "wall $(( $(date +%s)-T0 ))s" )
