#!/usr/bin/env bash
# P2 - cost of the tag test vs is_integer: Code bytes, instructions, term words, ns/call (OTP 25, JIT).
# Env: CALLS (default 10000000) RUNS (default 15). Always exits 0 unless the escript crashes; the
# structural facts (flat Code delta, exact-set growth) are asserted in run.sh from this output.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
W="${1:-$(mktemp -d)}/p2"; rm -rf "$W"; mkdir -p "$W"
"$HERE/p2_cost.escript" "$W" "${CALLS:-10000000}" "${RUNS:-15}"
