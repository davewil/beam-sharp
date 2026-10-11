#!/usr/bin/env bash
# tests.sh SCRATCH -- run the repo's eunit suite on each compiler run.sh built in SCRATCH,
# and name every failing test. `base` is the unpatched HEAD copy: its failures are not the patches'.
source /tmp/claude-0/env.sh
SCRATCH="${1:?usage: tests.sh SCRATCH}"
for v in base exported-only guard-all field-depth; do
  echo "---- $v"
  (cd "$SCRATCH/src-$v/compiler" && rebar3 eunit 2>&1 | tr -d '\r' > "$SCRATCH/eunit-$v.txt")
  grep -E "Failed: |tests, |All [0-9]+ tests passed" "$SCRATCH/eunit-$v.txt" | head -3
  grep -E "^\s+[A-Za-z_0-9]+:[0-9]+: [A-Za-z_0-9]+.*\*failed\*|\*failed\*|\.\.\.\*failed\*" "$SCRATCH/eunit-$v.txt" | sed 's/^ *//' | cut -c1-150 | head -12
done

echo; echo "==== the two gates that cover the touched area (compiler/bin), run against each compiler's own build"
for v in base exported-only guard-all field-depth; do
  for g in check-boundary-kind check-boundary-range; do
    printf '%-14s %-22s ' "$v" "$g"
    (cd "$SCRATCH/src-$v/compiler" && bash "bin/$g.sh" >/tmp/claude-0/gate.$$ 2>&1; echo "exit=$? $(tail -1 /tmp/claude-0/gate.$$)")
  done
done
