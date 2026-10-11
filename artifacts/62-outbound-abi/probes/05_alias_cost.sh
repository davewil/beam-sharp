#!/usr/bin/env bash
# One command: ./05_alias_cost.sh -> probes/05_alias_cost.out   (takes a few minutes)
# Uses the PATCHED scratch compiler (patch_emit.sh builds it from alias_emit.patch; compiler/src is untouched).
HERE="$(cd "$(dirname "$0")" && pwd)"; source "$HERE/lib.sh"
"$HERE/patch_emit.sh" >/dev/null || exit 1
rm -rf $WORK/gen $WORK/out
escript "$HERE/05_alias_cost.escript" $S/62/csrc-ebin $WORK
