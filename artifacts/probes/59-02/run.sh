#!/usr/bin/env bash
# Claim (ticket 59, "not a defect" side): a forged record can reach a private function via an exported
# one. Tested by feeding forged terms to exported entry points via `bsc ... FUNCTION ARG`.
set -u; HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/../59-common.sh"
W=$(mktemp -d); mkdir -p $W/src/T; cp "$HERE/t.bs" $W/src/T/t.bs
cd $W
good="{ Kind = :'T.Order', Id = 1, Total = 7 }"
bad="{ Kind = :'T.Invoice', Id = 1, Total = 7 }"
run() { echo "--- $*"; "$BSC" --src-root src src/T "$@" 2>&1 | head -8; }
run ViaOrder "$good"
run ViaOrder "$bad"
run ViaLine "{ Kind = :'T.Line', Item = $good, Qty = 2 }"
run ViaLine "{ Kind = :'T.Line', Item = $bad, Qty = 2 }"
run ViaList "[$good]"
run ViaList "[$bad]"
run ViaLineQty "{ Kind = :'T.Line', Item = $good, Qty = 2 }"
run ViaLineQty "{ Kind = :'T.Line', Item = $good, Qty = 2.5 }"

echo "=== which function raised? (erl, stack top frame) ==="
"$BSC" -o out --src-root src src/T >/dev/null 2>&1; erlc -o out "$HERE/forge.erl"
pp_abstr out/T.abstr | grep -v '^-spec\|^-file' | grep -A3 "^'ViaLine'("
erl -noshell -pa out -eval 'forge:main(),halt().' 2>&1 | head
