#!/usr/bin/env bash
# Asserts on p4_dialyzer.out: tagged spec's dead clause flagged (line of use_tagged), untagged not flagged.
f="$(dirname "$0")/p4_dialyzer.out"
tl=$(grep -n "use_tagged() ->" "$(dirname "$0")/p4_dialyzer/p4_spec.erl" | cut -d: -f1)
ul=$(grep -n "use_untagged() ->" "$(dirname "$0")/p4_dialyzer/p4_spec.erl" | cut -d: -f1)
flagged() { grep -E "^p4_spec.erl:([0-9]+):" "$f" | cut -d: -f2 | awk -v lo="$1" -v hi="$2" '$1>lo && $1<=hi' | wc -l; }
t=$(flagged "$tl" $((tl+6))); u=$(flagged "$ul" $((ul+6)))
echo "warnings inside use_tagged: $t ; inside use_untagged: $u"
[ "$t" -ge 1 ] && [ "$u" -eq 0 ] && echo "ASSERT holds" || { echo "ASSERT FAILS"; exit 1; }
