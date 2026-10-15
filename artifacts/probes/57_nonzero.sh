#!/usr/bin/env bash
# 57_nonzero -- ticket claim (repro table row 5): `int where value != 0` is accepted "and it genuinely
# excludes 0". Test: the residual of a clause set over NZ, and the exported-boundary check at run time.
# REFUTED by: NZ accepting 0 at the boundary, or the residual of `F(>=1)` over NZ not being `<= -1`.
. "$(dirname "$0")/env.sh"
w=$(mktemp -d "${TMPDIR:-/tmp}/p57n.XXXXXX"); mkdir -p "$w/M"
printf 'module M\ntype NZ = int where value != 0\npublic atom F(NZ d)\nF(>= 1) -> :pos\n' > "$w/M/a.bs"
echo "-- residual of F(>= 1) over NZ:"; "$BSC" "$w/M" 2>&1 | sed 's#^[^ ]*/a.bs#a.bs#'
printf 'module M\ntype NZ = int where value != 0\npublic NZ Id(NZ d)\nId(d) -> d\n' > "$w/M/a.bs"
for a in -1 0 1; do printf 'Id(%s) -> %s\n' $a "$("$BSC" "$w/M" Id $a 2>&1 | head -1)"; done
