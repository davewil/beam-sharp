#!/usr/bin/env bash
# One-factor-at-a-time variants of the Day-1 loop (see mkvariants.erl), timed in ONE VM, rotated order.
# Answers the ticket's section-3 item 2 (strip annotations: no_type_opt, no specs) and item 3
# (can the forms carry facts: narrow -spec, guard, -compile(inline)).
set -e
source "$(dirname "$0")/../common.sh"
cd "$(dirname "$0")"
B="$PWD/../01-rerun/build"; [ -f "$B/Day01.abstr" ] || bash ../01-rerun/run.sh >/dev/null 2>&1
rm -rf vbuild; erlc mkvariants.erl bench3.erl
erl -noshell -pa . -eval 'mkvariants:main(["'$B'","vbuild"])'
for i in 1 2 3; do echo "--- invocation $i"; erl -noshell -pa . -eval 'bench3:main(["vbuild","'$INPUT'","40"])'; done
