#!/usr/bin/env bash
# P3 - forged sub-term reaching a private function through an exported one (see forge_g.erl / forge_u.erl)
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
W="${1:-$(mktemp -d)}/p3"; mkdir -p "$W"
erlc -o "$W" "$HERE/forge_g.erl" "$HERE/forge_u.erl"
"$HERE/p3_forge.escript" "$W"
