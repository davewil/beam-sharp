#!/usr/bin/env bash
# What FromJson<T> does at master bca165e on the survey's probe inputs.
# Run from this directory with a built bsc: ./run.sh path/to/bsc
B="${1:?path to bsc}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/P" && cp "$HERE/p.bs" "$W/P/p.bs" && cd "$W" || exit 2
run() { printf '%-3s %-42s => ' "$1" "$2"; "$B" P "$1" "\"$(printf '%s' "$2" | sed 's/"/\\"/g')\"" 2>&1 | head -1; }
run Rw '{"a":1,"a":2}'
run Rw '{"a":1,"a":"x"}'
run Rw '{"a":"x","a":1}'
run Rw '{"a":1} x'
run Rw '{"a":1.0}'
run Rw '{"a":1e2}'
run Rw '{"a":123456789012345678901234567890}'
run Rw '{"a":1,"b":2}'
run Rw '{"a":null}'
run Rw '{}'
run Rf '{"a":1}'
run Rf '{"a":1.5}'
run Rn '{"a":1}'
run Ra '{"type":"choice"}'
run Ra '{"type":"tri","choice":"x"}'
run Ra '{"choice":"x"}'
run Ra '{"type":"score","score":"x"}'
run Rl '{"xs":[{"a":1},{"a":"x"},{"a":"y"}]}'
run Rl '{"xs":[{"a":1},{}]}'
