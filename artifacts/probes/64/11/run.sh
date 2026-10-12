#!/usr/bin/env bash
# Probe 64/11 - re-run the ticket's own prototype (48l) unmodified against the current bsc.
# 48l measures the list<(atom,term)> workaround; it does not print the four-signature table (that came from
# `bsc --api`, reproduced in probe 01). Claim checked: the prototype's verdict lines still hold at HEAD.
HERE="$(cd "$(dirname "$0")" && pwd)"; REPO="$(cd "$HERE/../../../.." && pwd)"
echo "git HEAD: $(git -C $REPO log --oneline -1)"
bash "$REPO/wayfinder/prototypes/48l_what_the_workaround_costs.sh"
