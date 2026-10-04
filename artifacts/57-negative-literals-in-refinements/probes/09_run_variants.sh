#!/usr/bin/env bash
# Usage: bash 09_run_variants.sh 07_literal_flows_into_refined_type.sh   -> same probe on every prototype build
here=$(cd "$(dirname "$0")" && pwd)
PROTO=${PROTO:-/tmp/claude-0/-home-user-beam-sharp/4180a786-23e5-53e3-b71e-94fb1d89eea9/scratchpad/proto}
for v in base grammar checker_min checker_wide checker_full refine_only; do
  echo "################ $v"
  BSC=$PROTO/$v/compiler/_build/default/bin/bsc bash $here/$1 2>&1 | sed 's#/tmp/tmp\.[A-Za-z0-9]*/##'
done
