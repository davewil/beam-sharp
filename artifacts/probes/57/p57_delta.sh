#!/usr/bin/env bash
# Ticket 57. The motivating type from the ticket: can a signed bounded domain be both DECLARED and INHABITED by a literal?
. "$(dirname "$0")/../env.sh"
W=$(mktemp -d); mkdir -p "$W/M"
printf 'module M\n\ntype Delta = int where value >= -100 and value <= 100\n\npublic Delta Back(int n)\n\nBack(n) -> -3\n\npublic Delta Fwd(int n)\n\nFwd(n) -> 3\n' > "$W/M/m.bs"
out=$(bsc -o "$W/out" "$W/M" Back 0 2>&1); echo "rc=$?"; echo "$out" | sed "s|$W/M/m.bs:||" | head -6
