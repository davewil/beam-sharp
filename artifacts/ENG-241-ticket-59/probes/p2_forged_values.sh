#!/usr/bin/env bash
# H2: values the exported boundary never tests reach a private function.
#   (a) private Total(Order) is the ONLY tag test between a forged list element and map_get:
#       real bsc output raises function_clause; the same module with Total's guard stripped
#       (counterfactual, from bsc's own .abstr) returns the forged map's Total silently.
#   (b) private Big(Octet) has no kind test: SumBig([100.5]) and SumBig([300]) answer 1 although
#       neither is an Octet; the direct exported BigOf(100.5) is refused.
# Falsifier: (a) real module returns a number for the forged element, or the stripped module
#   raises; (b) SumBig refuses, or BigOf answers.
# Command: ./p2_forged_values.sh        Toolchain: OTP 25 shimmed bsc (see BRIEF limits)
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
BSC=${BSC:-/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/bsc/_build/default/bin/bsc}
OUT=$(mktemp -d); STRIP=$(mktemp -d)
cd "$HERE/bs"
run() { echo "\$ bsc P59 $1 $2"; "$BSC" -o "$OUT" --src-root . P59 "$1" "$2" 2>&1 | head -4; echo "  -> exit ${PIPESTATUS[0]}"; }
FORGED='[{ Kind = :'"'"'Other.Thing'"'"', Id = 1, Total = 5 }]'
GOOD='[{ Kind = :'"'"'P59.Order'"'"', Id = 1, Total = 5 }]'
echo "== (a) record tag, real bsc output"
run SumTotals "$GOOD"          # control: must answer 5
run SumTotals "$FORGED"
run TotalOf   "${FORGED:1:-1}" # forged record straight into the exported function
echo "== (a') counterfactual: Total/1's guard stripped from bsc's own .abstr"
"$BSC" -o "$OUT" --src-root . P59 >/dev/null
escript "$HERE/strip_guard.escript" "$OUT/P59.abstr" "$STRIP" Total
erl -noshell -pa "$STRIP" -eval '
R = (catch '"'"'P59'"'"':'"'"'SumTotals'"'"'([#{'"'"'Kind'"'"' => '"'"'Other.Thing'"'"', '"'"'Id'"'"' => 1, '"'"'Total'"'"' => 5}])),
io:format("stripped SumTotals(forged) = ~p~n",[R]), halt().'
echo "== (b) int kind"
run SumBig "[3, 100]"          # control
run SumBig "[100.5]"
run SumBig "[300]"
run BigOf  "100.5"
run BigOf  "300"
