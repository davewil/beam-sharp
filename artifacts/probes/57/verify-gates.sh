#!/usr/bin/env bash
source /tmp/claude-0/env.sh
v=$1; cd /tmp/claude-0/wp-$v/compiler
for g in check-diagnostics check-residual-pasteable check-guard-calls check-negation check-division check-boundary-range check-examples check-helper-agrees check-switch-diagnostics check-tagged-union; do
  s=$(date +%s); SPEC_CHECK_DIR=$(mktemp -d) bash bin/$g.sh > /tmp/claude-0/gate-$v-$g.log 2>&1; rc=$?
  echo "$v $g rc=$rc $(( $(date +%s)-s ))s" >> /tmp/claude-0/gates-$v.txt
done
echo FINISHED >> /tmp/claude-0/gates-$v.txt
