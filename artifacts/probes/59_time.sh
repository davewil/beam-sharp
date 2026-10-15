#!/usr/bin/env bash
# 59_time.sh -- call-time cost of the boundary guards on a PRIVATE function, B#-emitted.
# Claim (ticket 59 / 18): is_integer call time is below the +-0.09 ns/call resolution; the tag test
# "costs nothing measurable" (26a). Method: private self-recursive loops compiled under HEAD (tag test
# on private record fn), EXP (none), ALL (is_integer on private int fn), NOTAG; 1e7 iterations x N=15
# runs, round-robin across variants. REFUTED if the HEAD-vs-EXP or ALL-vs-HEAD gap is larger than the
# run-to-run spread (max-min within a variant) -- i.e. report the gap AND the spread.
set -u
cd "$(dirname "$0")"; . ./env.sh; . ./59_lib.sh
T=$(mktemp -d "${TMPDIR:-/tmp}/p59time.XXXXXX")
for V in HEAD EXP ALL NOTAG; do var=BSC_$V; mkdir -p "$T/$V"; (cd 59_time && "${!var}" --src-root . -o "$T/$V" T) || exit 1; done
echo "emitted guards on the loops:"; for V in HEAD EXP ALL; do echo " [$V]"; ./59_guards.escript "$T/$V/T.beam" | sed 's/^/   /'; done
./59_time.escript ${N59:-15} ${ITERS59:-10000000} HEAD="$T/HEAD" EXP="$T/EXP" ALL="$T/ALL" NOTAG="$T/NOTAG"
echo "(the node: $(erl -noshell -eval 'io:format("OTP ~s, ~s, JIT=~p",[erlang:system_info(otp_release), erlang:system_info(system_architecture), erlang:system_info(emu_flavor)]),halt().'))"
