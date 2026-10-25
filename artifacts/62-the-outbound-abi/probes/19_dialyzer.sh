#!/usr/bin/env bash
# Probe 19: dialyzer story. Same misuse module against (a) original Shop, (b) Shop + snake aliases WITH copied -spec.
# Expect: (a) flags via_original; (b) flags both. Control = (a) must NOT flag via_alias (no such function -> unknown function warning).
S=$1; PLT=$S/62/min.plt
echo "### (a) original Shop"; dialyzer --plt $PLT $S/62/ebin/Shop.beam $S/62/dz/misuse.beam 2>&1 | grep -v "^  Checking\|^  Proceeding\|^  Compiling\|^$"
echo "### (b) Shop with local-call aliases + copied specs"; dialyzer --plt $PLT $S/62/alias_local/Shop.beam $S/62/dz/misuse.beam 2>&1 | grep -v "^  Checking\|^  Proceeding\|^  Compiling\|^$"
