#!/usr/bin/env bash
# Ticket 59, part 1/3 -- the SHIPPED compiler, unpatched. Never touches
# compiler/src, so it carries none of the concurrent-build risk the patch
# scripts do.
set -euo pipefail
REPO=/home/user/beam-sharp
COMP="$REPO/compiler"
BSC="$COMP/_build/default/bin/bsc"
HERE="$REPO/artifacts/59-probes"
cd "$HERE"

say() { echo; echo "=== $* ==="; }

compile_mod() {
  local dir="$1" mod="$2"
  rm -rf "out/$dir"; mkdir -p "out/$dir"
  ( cd src && "$BSC" --src-root . -o "../out/$dir" "$mod" )
}

say "0. building the shipped compiler"
( cd "$COMP" && rebar3 escriptize )

say "1. SUB-DECISION 1 -- which guard fires on a private function, today"
compile_mod Probe Probe
echo "--- Probe.abstr: PrivateOrder (record param, private) ---"
grep -A6 "'PrivateOrder',1," "out/Probe/Probe.abstr"
echo "--- Probe.abstr: PrivateOctet (refined-int param, private) ---"
grep -A2 "'PrivateOctet',1,\[" "out/Probe/Probe.abstr"
echo "--- Probe.abstr: PublicOrder (record param, exported), for contrast ---"
grep -A6 "'PublicOrder',1," "out/Probe/Probe.abstr"
echo "--- Probe.abstr: PublicOctet (refined-int param, exported), for contrast ---"
grep -A5 "'PublicOctet',1,$" "out/Probe/Probe.abstr"

say "2. THE FORGED-RECORD ATTACK -- Order/Invoice, wrapped one field deep"
compile_mod Attack Attack
echo "--- Outer/1's own emitted guard (none -- Wrapper is neither a closed record nor int-only) ---"
grep -A6 "'Outer',1,$" out/Attack/Attack.abstr
echo "--- Inner/1's own emitted guard (the tag test, unconditional, private) ---"
grep -A6 "'Inner',1," out/Attack/Attack.abstr
echo "--- shipped compiler: forged Invoice through Outer(exported, unguarded) -> Inner(private) ---"
erl -noshell -pa "out/Attack" -pa "$HERE" -s run_attack main

say "2a. same attack, INT guard's existing exported-only scope (already shipped, unpatched)"
compile_mod AttackInt AttackInt
echo "--- Inner/1's own emitted guard (none -- private, so 18 sec 4 scope excludes it) ---"
grep "'Inner',1," out/AttackInt/AttackInt.abstr
echo "--- shipped compiler: forged binary/float through Outer(exported, unguarded) -> Inner(private) ---"
erl -noshell -pa "out/AttackInt" -pa "$HERE" -s run_attack_int main

say "DONE -- baseline. compiler/src untouched throughout."
