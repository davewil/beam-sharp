#!/usr/bin/env bash
# Probe: does bs_parser.yrl have ANY bracket-attribute production today, of the
# shape `[external: elixir, app: req]` that ticket 52's own candidate assumes it
# can extend? Ticket 22 already found "no attribute grammar has ever existed" on
# 2026-08-23 -- this re-derives that finding directly against the CURRENT
# checked-in grammar rather than trusting the citation.
set -euo pipefail
cd "$(dirname "$0")/../../compiler"

echo "=== 1. Every place '[' or ']' appears as a grammar TERMINAL use in bs_parser.yrl ==="
grep -n "'\['" src/bs_parser.yrl || true

echo
echo "=== 2. The full 'decl' alternation -- every top-level declaration form the parser accepts ==="
grep -n "^decl -> " src/bs_parser.yrl

echo
echo "=== 3. The foreign declaration production, verbatim, as it exists TODAY ==="
grep -n "^foreign_decl ->" -A1 src/bs_parser.yrl

echo
echo "=== 4. Every .bs file in the repo: does any line begin with '[' (an attribute)? ==="
cd ..
COUNT=$(grep -rl "^\s*\[" --include="*.bs" . | wc -l)
echo "files with a line starting '[': $COUNT"
grep -rn "^\s*\[" --include="*.bs" . || echo "(none found)"
