#!/usr/bin/env bash
#
# 63b + 63c — the two compile-driven probes for ticket 63, with their controls.
#
# Each case below states the exit code it must produce BEFORE it is run, so a
# result cannot be read off after the fact. The controls are the point: 63b's
# refusal and 63c's acceptance both mean nothing unless the near-identical file
# beside them goes the other way.
#
#   63b  GuardProbe          MUST FAIL     a user function call in a guard
#        GuardControl        MUST COMPILE  the same shape with a comparison
#   63c  Complement          MUST COMPILE  9 guard/complement pairs, no catch-all
#        NotComplement       MUST FAIL     an int pair that is not a complement
#        NotComplementAtom   MUST FAIL     an atom pair that is not a complement
#
# Run from the repository root:
#
#     bash wayfinder/prototypes/63bc_run.sh
#
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
bsc="$root/compiler/_build/default/bin/bsc"

if [ ! -x "$bsc" ]; then
    echo "bsc not built — run 'rebar3 escriptize' in $root/compiler" >&2
    exit 2
fi

fails=0

# $1 expected outcome (compile|fail), $2 probe root, $3 module dir, $4 file
probe() {
    local want=$1 src=$2 dir=$3 file=$4 out rc
    out=$("$bsc" --src-root "$root/wayfinder/prototypes/$src" \
                 "$root/wayfinder/prototypes/$src/$dir/$file" 2>&1) && rc=0 || rc=$?

    case "$want:$rc" in
        compile:0)
            printf '  ok    %-18s compiled, as required\n' "$dir"
            ;;
        fail:0)
            printf '  FAIL  %-18s compiled, and MUST NOT have\n' "$dir"
            fails=$((fails + 1))
            ;;
        compile:*)
            printf '  FAIL  %-18s was refused, and MUST have compiled\n' "$dir"
            printf '%s\n' "$out" | sed 's/^/          /'
            fails=$((fails + 1))
            ;;
        *)
            printf '  ok    %-18s refused, as required\n' "$dir"
            printf '%s\n' "$out" | head -3 | sed 's/^/          | /'
            ;;
    esac
}

echo
echo "63b — is a user function call legal in a guard?"
probe fail    63b_guard_probe                 GuardProbe        guardprobe.bs
probe compile 63b_guard_probe                 GuardControl      guardcontrol.bs

echo
echo "63c — is the guard fragment closed under complement?"
probe compile 63c_guards_close_under_complement Complement        complement.bs
probe fail    63c_guards_close_under_complement NotComplement     notcomplement.bs
probe fail    63c_guards_close_under_complement NotComplementAtom notcomplementatom.bs

echo
if [ "$fails" -eq 0 ]; then
    echo "63b/63c: all five cases as required"
else
    echo "63b/63c: $fails case(s) did not match — the measurement is void"
    exit 1
fi
