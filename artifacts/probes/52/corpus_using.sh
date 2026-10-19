#!/usr/bin/env bash
# ticket 52: which foreign modules do the repo's .bs files name with `using`?  (run from anywhere)
cd "$(dirname "$0")/../../.."
echo "using declarations: $(grep -rhE '^\s*using\s' --include=*.bs . | grep -v artifacts | wc -l) in $(grep -rlE '^\s*using\s' --include=*.bs . | wc -l) files"
grep -rhoE "^\s*using\s+:'?[A-Za-z_.]+" --include=*.bs . | sed -E "s/^\s*using\s+//" | sort | uniq -c | sort -rn
