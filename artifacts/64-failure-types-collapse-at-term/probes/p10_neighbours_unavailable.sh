#!/usr/bin/env bash
# P10: record the attempts to reach gleam_stdlib and Elm core sources. Result: unavailable.
. "$(dirname "$0")/lib.sh"
echo "--- npm gleam_stdlib"; npm view gleam_stdlib name 2>&1 | head -2
echo "--- pip gleam_stdlib"; pip download gleam_stdlib --no-deps -d $S/64/pip 2>&1 | tail -1
echo "--- find dict.gleam / Dict.elm on disk"; find / \( -name 'dict.gleam' -o -name 'Dict.elm' -o -name 'gleam_stdlib*' \) -not -path '/proc/*' -not -path '*/artifacts/*' 2>/dev/null | head
echo "--- elm package cache (elm/core would live here)"; find $S/elmhome -type f | head -5
echo "--- gleam binary embeds stdlib dict.gleam?"; strings -n 12 "$(readlink -f $S/beam/bin/gleam)" | grep -c 'pub fn get'
