#!/usr/bin/env bash
# Probe 62-07: apply the derived-snake rule to every public B# function in the repo's corpus.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 -I "$HERE/corpus.py"
echo "--- cross-check: regex-extracted exports vs the compiler's real export table for Shop"
python3 -I - <<'PY'
import re
t=open('/home/user/beam-sharp/compiler/examples/Shop/shop.bs').read()
print(sorted(set(re.findall(r'^public\b[^\n]*?\b([A-Z]\w*)\(', t, re.M))))
PY
