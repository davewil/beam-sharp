#!/usr/bin/env bash
# emitted-form.sh — what does `F() -> -5` emit, per variant? Only option B changes the body form.
set -uo pipefail
WORK=${WORK:-/tmp/p57work}; w=$(mktemp -d); trap 'rm -rf "$w"' EXIT
mkdir -p "$w/F"; printf 'module F\npublic int F()\nF() -> -5\n' > "$w/F/a.bs"
for v in base optA1 optB optC; do
  mkdir -p "$w/o_$v"; (cd "$w/o_$v" && "$WORK/$v/bsc" "$w/F/a.bs" >/dev/null 2>&1 </dev/null
    printf '%-6s ' $v; erl -noshell -eval '{ok,Fs}=file:consult("F.abstr"), [io:format("~w~n",[C]) || {function,_,'"'F'"',0,[{clause,_,[],[],C}]} <- Fs], halt().' 2>&1 | sed 's/{\([0-9]*\),[0-9]*}/\1/g')
done
