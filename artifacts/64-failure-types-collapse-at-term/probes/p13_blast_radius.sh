#!/usr/bin/env bash
# P13: how many existing B# sources / tests / docs use option<...> and :nothing (the blast radius of a universally tagged option<T>)
cd "$(dirname "$0")/../../.."
echo "--- .bs files mentioning option<"; grep -rl 'option<' --include=*.bs . | grep -v '^./artifacts\|^./compiler/_build' | wc -l
echo "--- occurrences of option< in .bs (excluding artifacts/)"; grep -r 'option<' --include=*.bs . | grep -v '^./artifacts\|^./compiler/_build' | wc -l
echo "--- occurrences of :nothing in .bs"; grep -r ':nothing' --include=*.bs . | grep -v '^./artifacts\|^./compiler/_build' | wc -l
echo "--- by tree"; for d in compiler/examples aoc wayfinder handoff; do printf '%s: files=%s lines=%s\n' $d "$(grep -rl ':nothing\|option<' --include=*.bs $d 2>/dev/null | wc -l)" "$(grep -r ':nothing\|option<' --include=*.bs $d 2>/dev/null | wc -l)"; done
echo "--- erl test/src files mentioning option<"; grep -l 'option<' compiler/test/*.erl compiler/src/*.erl | wc -l
echo "--- docs mentioning option<T> (md)"; grep -rl 'option<' --include=*.md . | grep -v '^./artifacts\|^./compiler/_build' | wc -l
echo "--- option< lines in .bs by top-level dir"; grep -r 'option<' --include=*.bs . | grep -v '^./artifacts\|^./compiler/_build' | cut -d/ -f2-3 | sort | uniq -c | sort -rn | head -8
echo "--- the 14 ticket-108 pair rows are all unbuilt; option<T> consumers today are user code only (no stdlib row returns option<T>):"; grep -n 'option<' compiler/src/bs_check.erl | head -5
