#!/usr/bin/env bash
# Run: ./run.sh > ../p4_dialyzer.out 2>&1   (needs erlc, dialyzer; builds a tiny erts-only PLT)
set -u
cd "$(dirname "$0")"
erlc +debug_info p4_spec.erl || exit 2
[ -f erts.plt ] || dialyzer --build_plt --output_plt erts.plt --apps erts 2>&1 | tail -3
dialyzer --plt erts.plt p4_spec.beam; echo "dialyzer exit=$?"
