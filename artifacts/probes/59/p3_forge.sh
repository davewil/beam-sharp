#!/usr/bin/env bash
# P3 - forged sub-term reaching a private function through an exported one (see forge_b.erl / forge_a.erl)
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
W="${1:-$(mktemp -d)}/p3"; mkdir -p "$W"
erlc -o "$W" "$HERE/forge_b.erl" "$HERE/forge_a.erl"
"$HERE/p3_forge.escript" "$W"
