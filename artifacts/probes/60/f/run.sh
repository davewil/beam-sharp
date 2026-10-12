#!/usr/bin/env bash
# 60/f : a RUNTIME caller-identity check is neither cheap nor sound.
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT; cp "$(dirname "$0")/who.erl" "$(dirname "$0")/rogue.erl" "$w/"; cd "$w"
erlc who.erl rogue.erl && erl -noshell -pa . -eval 'who:main(), halt().'
