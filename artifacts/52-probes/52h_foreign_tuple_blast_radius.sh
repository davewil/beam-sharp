#!/usr/bin/env bash
# Probe: if the `foreign` decl tuple grows a field (an app-name atom), how many
# hand-written sites does that touch? (bs_parser.erl is YECC-GENERATED from
# bs_parser.yrl and is excluded -- it is not a site anyone edits.)
set -euo pipefail
cd "$(dirname "$0")/../../compiler"

echo "=== the ONE grammar production that builds the {foreign, ...} tuple ==="
grep -n "^foreign_decl ->" -A2 src/bs_parser.yrl

echo
echo "=== every HAND-WRITTEN site that pattern-matches {foreign, ...} (excludes generated bs_parser.erl) ==="
grep -rn "{foreign," src/*.erl | grep -v "src/bs_parser.erl"

cd ..
echo
echo "=== every .bs file in the repo using the foreign 'using :atom { ... }' form today (quoted or bare atom) ==="
grep -rln "^\s*using :" --include="*.bs" . | sort

echo
echo "=== how many such using-blocks total (the existing-file migration cost if the field became MANDATORY) ==="
grep -rn "^\s*using :" --include="*.bs" . | wc -l
cd compiler

echo
echo "=== precedent: the diagnostic machinery a comparable NEW check costs (reserved_module_name), counted ==="
echo "-- bs_check.erl definition --"
grep -n "^reserved_module_name" -A10 src/bs_check.erl | head -12
echo "-- bs_diag.erl descriptor/2 clause --"
grep -n "reserved_module_name, Module, Line" -A2 src/bs_diag.erl | head -6
echo "-- bs_diag.erl message/1 clause --"
grep -n "tag := reserved_module_name" -A7 src/bs_diag.erl | head -9
