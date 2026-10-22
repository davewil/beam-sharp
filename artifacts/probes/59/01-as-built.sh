#!/usr/bin/env bash
# Probe 01 — what the reference compiler emits TODAY for the private/exported pairs, and what each door does with a forged value.
# Claims tested: ticket 59 "a private Inner(Order o) receives the tag test; the int KIND test is exported-only".
H="$(cd "$(dirname "$0")" && pwd)"; . "$H/lib.sh"
B=$(build_bsc base) || exit 1
O="$SCRATCH/o-base"; rm -rf "$O"; mkdir -p "$O"
$B --src-root "$H/src" -o "$O" "$H/src/T" || exit 1
echo "=== emitted Erlang (OTP-25-built bsc, repo emitter unmodified) ==="; pp_beam "$O/T.beam"
echo; echo "=== forged values at each door ==="; "$H/battery.escript" "$O"
