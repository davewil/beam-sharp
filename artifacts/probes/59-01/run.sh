#!/usr/bin/env bash
# Claim: the record tag test is emitted on a PRIVATE function (ticket 46/59 measurement).
# Also records the git HEAD so staleness of the ticket (2026-08-23) is visible.
set -u; . "$(dirname "$0")/../59-common.sh"
W=$(mktemp -d); mkdir -p $W/src/T; cp "$(dirname "$0")/t.bs" $W/src/T/t.bs
echo "git HEAD: $(git -C $REPO log --oneline -1)"
echo "boundary_guards in current source:"; grep -n 'boundary_guards\|none when Public\|^        none ->' $REPO/compiler/src/bs_emit.erl
( cd $W && "$BSC" -o out --src-root src src/T ) 2>&1
echo "=== emitted Inner/Outer (erl_pp of .abstr) ==="
pp_abstr $W/out/T.abstr | grep -v '^-spec\|^-file' | sed -n '/^.Inner/,$p'
