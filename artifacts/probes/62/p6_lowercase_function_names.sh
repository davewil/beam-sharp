#!/usr/bin/env bash
# Ticket 62, candidate 2 collision surface: does B# let a program declare BOTH `Get` and `get` (so an
# emitted snake_case alias for `Get` could collide with a user's own export), or refuse lowercase names?
set -u; here=$(cd "$(dirname "$0")" && pwd); BSC=${BSC:-$here/../../../compiler/_build/default/bin/bsc}
d=$(mktemp -d); mkdir -p $d/Both; printf 'module Both\n\npublic int Get(int x)\nGet(x) -> x\n\npublic int get(int x)\nget(x) -> x + 1\n' > $d/Both/a.bs
"$BSC" -o $d/out $d/Both 2>&1 | head -4; echo "exit=${PIPESTATUS[0]}"
