#!/usr/bin/env bash
# P02: re-run the repo's 48l prototype UNMODIFIED except the BSC path (line substituted via sed; original untouched).
. "$(dirname "$0")/lib.sh"
sed -e "s#^BSC=.*#BSC=$BSC#" -e 's#^\[ -x "\$BSC" \].*##' "$HERE/../../../wayfinder/prototypes/48l_what_the_workaround_costs.sh" > "$S/64/48l_patched.sh"
bash "$S/64/48l_patched.sh"
