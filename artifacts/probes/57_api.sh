#!/usr/bin/env bash
# 57_api -- side finding: `bsc --api` prints a bounded interval as `-100..100`; is that source syntax?
# Claim: it is a DISPLAY spelling only -- `type X = 1..5` is refused even with positive bounds, so the
# ticket's "residual cannot be spelled" worry does not extend to --api (the --api form was never source).
# REFUTED by: `type X = 1..5` being accepted on stock.
# usage: V57=<dir> 57_api.sh
. "$(dirname "$0")/env.sh"; . "$(dirname "$0")/57_lib.sh"; : "${V57:?}"
d=$(mktemp -d "${TMPDIR:-/tmp}/p57a.XXXXXX"); mkdir "$d/M"
printf 'module M\ntype Delta = int where value >= -100 and value <= 100\npublic atom Sign(Delta d)\nSign(<= -1) -> :neg\nSign(0) -> :zero\nSign(>= 1) -> :pos\n' > "$d/M/a.bs"
echo "-- gramA: bsc --api"; "$V57/gramA/_build/default/bin/bsc" --api "$d/M"
try "$V57/stock/_build/default/bin/bsc" 'type X = 1..5 (stock)'  'type X = 1..5'
try "$V57/stock/_build/default/bin/bsc" 'type X = -5..5 (stock)' 'type X = -5..5'
