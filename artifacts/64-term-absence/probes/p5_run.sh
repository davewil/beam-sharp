#!/usr/bin/env bash
# Run from this dir: ./p5_run.sh > p5_hazard.out
set -e
d="$(cd "$(dirname "$0")" && pwd)"; t="$(mktemp -d)"
erlc -o "$t" "$d/p5_hazard.erl"
erl -noshell -pa "$t" -eval 'p5_hazard:main().'
