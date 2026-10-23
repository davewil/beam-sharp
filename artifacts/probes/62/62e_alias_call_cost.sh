#!/usr/bin/env bash
# PROBE 62e — remote call cost: 'Shop':'Squared'(N) (the real export) vs 'Shop':squared(N) (delegating alias).
# Bench loop lives in alias_bench.erl, compiled with erlc.
# CONTROL: two timings of the SAME function ('Squared' vs 'Squared') give the noise floor; an alias cost is only
# claimed where it exceeds that floor. 15 runs x 5M calls each, interleaved; reports median and min/max in ns/call.
# PROTOTYPE DELTA: patched compiler (see 62d). Usage: source env.sh; ALIASBSC=... bash 62e_alias_call_cost.sh
set -uo pipefail
: "${ALIASBSC:?}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; mkdir "$W/d"
BS_ALIAS=deleg "$ALIASBSC" --src-root "$REPO/compiler/examples" -o "$W/d" "$REPO/compiler/examples/Shop" >/dev/null 2>&1
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
erlc -o "$W" "$HERE/alias_bench.erl"
erl -noshell -pa "$W/d" -pa "$W" -eval 'alias_bench:run(), halt().'
