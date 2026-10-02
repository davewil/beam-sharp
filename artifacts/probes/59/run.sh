#!/usr/bin/env bash
# Reruns every probe of the ticket-59 brief from scratch. Exit non-zero if an expected observation fails.
# Needs erl/erlc (OTP 25), elixir; gleam optional (GLEAM=/path). CALLS/RUNS tune the timing probe.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
W="$(mktemp -d)"; echo "work dir: $W"
rc=0
step() { echo; echo "################ $1"; shift; "$@" || { echo ">>> STEP FAILED: $*"; rc=1; }; }
step "P1 elision: is_integer vs tag test in a local-only function (OTP 25 erlc -S)" "$HERE/p1_elision.sh" "$W"
step "P3 forged value reaches a private function (sub-term, list element, escaped fun)" "$HERE/p3_forge.sh" "$W"
step "P4 Elixir defp heads"  "$HERE/p4_elixir.sh" "$W"
step "P5 Gleam pub/private"  "$HERE/p5_gleam.sh" "$W"
step "P6 Erlang stdlib+kernel type-guard census, exported vs local" "$HERE/p6_erlang_practice.escript"
echo; echo "################ P2 cost (Code bytes, instructions, words, ns/call)"
"$HERE/p2_cost.sh" "$W" | tee "$W/p2.out" || rc=1
# structural assertions on P2 (the timing rows are reported, not asserted: the VM is noisy)
g=$(awk '$1=="map_get==" {print $4-0, $6}' "$W/p2.out" | awk '{print $1}' | sort -u | wc -l)   # distinct Code sizes across N
if [ "$g" = 1 ]; then echo "ok   tag test Code size is flat in field count (1 distinct size across N=1,5,20)"; else echo "FAIL tag test Code size not flat"; rc=1; fi
e=$(awk '$1=="exact-set" {print $4}' "$W/p2.out" | sort -u | wc -l)
if [ "$e" -ge 2 ]; then echo "ok   exact-set test grows with field count (control: the probe CAN see growth)"; else echo "FAIL exact-set control did not grow"; rc=1; fi
echo; [ $rc = 0 ] && echo "ALL PROBES OK" || echo "SOME PROBE FAILED"
exit $rc
