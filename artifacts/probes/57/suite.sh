#!/usr/bin/env bash
# Probe D: run a slice of the repo's own eunit suite (OTP 25, shim build) against a variant,
# print the sorted list of FAILING test names. Many fail on OTP 25 even at base (they shell out to
# the bsc escript, which is not buildable here); the claim is only that a variant adds none.
# usage: suite.sh BUILD_DIR  (a dir made by build.sh)
set -euo pipefail
b=$(cd "$1" && pwd); here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/proj/_build/test/lib/bsc" "$t/ebin"
cp "$root"/compiler/test/*.erl "$t/"
(cd "$t" && erlc -o ebin *.erl >/dev/null 2>&1)
cd "$t/proj/_build/test/lib/bsc"
mods=${MODS:-intervals_tests,negation_tests,types_tests,switch_tests,division_tests,float_tests,guard_kind_tests,heads_tests,body_check_tests,pipe_tests,records_tests,strings_tests}
erl -noshell -pa "$b" -pa "$t/ebin" -eval "eunit:test([$mods],[verbose]), halt()." 2>&1 \
  | grep -E 'failed\*|^  Failed:|All [0-9]+ tests passed' | sed -E 's/^ *//' | sed 's/\.\.\.\*failed\*//' | sort
