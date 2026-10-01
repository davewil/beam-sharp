#!/usr/bin/env bash
# Ticket 57: build bsc from HEAD plus each variant patch, and re-run p1 (refinements) and p2 (guards)
# UNCHANGED against each build. The patches are in this directory and are generic (no probe-specific text).
# Usage: bash p3_prototype_variants.sh     (needs OTP >= 26 and rebar3 on PATH; ~1 min per variant)
set -u; here=$(cd "$(dirname "$0")" && pwd); root=$(cd "$here/../../.." && pwd)
W=${W:-$(mktemp -d)}
for v in variantA_parse_fold variantB_checker_negated_literal variantC_checker_const_fold; do
  rm -rf "$W/$v" && mkdir -p "$W/$v" && (cd "$root" && git archive HEAD compiler) | tar -x -C "$W/$v"
  (cd "$W/$v/compiler" && patch -p1 -s < "$here/$v.patch" && rebar3 escriptize >build.log 2>&1) || { echo "$v: BUILD FAILED"; tail -5 "$W/$v/compiler/build.log"; continue; }
  echo; echo "################ $v ($(grep -c '^[+-][^+-]' "$here/$v.patch") changed lines)"
  BSC="$W/$v/compiler/_build/default/bin/bsc" bash "$here/p1_repro_at_head.sh" 2>&1 | grep -E '^(==|rc=)'
  BSC="$W/$v/compiler/_build/default/bin/bsc" bash "$here/p2_guards_share_the_gap.sh" 2>&1 | grep -E '^(==|rc=)'
done
echo; echo "(builds kept in $W for the test-suite run)"
