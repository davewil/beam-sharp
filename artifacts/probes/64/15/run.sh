#!/usr/bin/env bash
# Probe 64/15 - blast radius of ALWAYS-tagging option<T> (Gleam/Elm shape), counted from the repo itself.
# Cheap static counts only: how many places spell the bare option shape today. No claim about how many
# would need to CHANGE beyond "each of these sites reads or writes :nothing / a bare success".
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; REPO="$(cd "$HERE/../../../.." && pwd)"; cd $REPO
echo "git HEAD: $(git log --oneline -1)"
echo "-- .bs programs under compiler/examples + aoc (exemplars, examples, AoC):"
echo "   files: $(find compiler/examples aoc -name '*.bs' | wc -l)"
echo "   files mentioning option<: $(grep -rl 'option<' --include=*.bs compiler/examples aoc | wc -l)"
echo "   option<...> spellings (incl. comments):"; grep -rhoE 'option<[A-Za-z]+>' --include=*.bs compiler/examples aoc | sort | uniq -c | sort -rn | sed 's/^/     /'
echo "   lines containing :nothing: $(grep -rn ':nothing' --include=*.bs compiler/examples aoc | wc -l)  in $(grep -rl ':nothing' --include=*.bs compiler/examples aoc | wc -l) files"
echo "   option<term> / result<term in any .bs: $(grep -rn 'option<term\|result<term' --include=*.bs compiler/examples aoc wayfinder | wc -l)"
echo "-- compiler tests:"
echo "   test files: $(ls compiler/test/*.erl | wc -l); files mentioning :nothing / nothing: $(grep -l 'nothing' compiler/test/*.erl | wc -l); lines: $(grep -c 'nothing' compiler/test/*.erl | awk -F: '{s+=$2} END{print s}')"
echo "-- docs that spell the bare shape as a feature:"
for f in LANGUAGE.md TOUR.md STANDARD-ENVIRONMENT.md CONTEXT.md; do printf '   %-24s lines with ":nothing": %s\n' $f "$(grep -c ':nothing' $f)"; done
echo "-- features keyed on the BARE option success:"
for f in F61-absent-option-key F72-tagged-union F69-from-json; do printf '   %-26s mentions of option<: %s\n' $f "$(grep -c 'option<' compiler/features/$f.md)"; done
echo "-- runtime: 3 extra words per PRESENT option value (probe 05): a record with 5 present option fields pays 15 words (120 bytes)"
