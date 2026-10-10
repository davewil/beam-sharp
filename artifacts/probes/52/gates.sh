#!/usr/bin/env bash
# usage: gates.sh COMPILER_DIR  -- runs the gates that read the touched areas; prints exit code and last lines of each
cd "$1" || exit 1
for g in check-diagnostics check-examples check-language check-tour check-exemplar-frontier; do
  echo "=== $g"; s=$(date +%s); ./bin/$g.sh > /tmp/claude-0/work-52/gate.$$.out 2>&1; rc=$?; tail -6 /tmp/claude-0/work-52/gate.$$.out | cut -c1-200; echo "exit=$rc  ($(( $(date +%s)-s )) s)"
done
