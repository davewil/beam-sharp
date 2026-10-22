#!/usr/bin/env bash
# Probe 65/06: what does each policy touch, and how much of the tree uses the names?
# Pure grep over the repo at the checked-out HEAD; no compiler needed. Prints raw counts.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/../../../.."   # repo root
echo "HEAD $(git rev-parse --short HEAD)"
SRC=compiler/src
ROSTER='Enum|List|Map|String|Int|Float|Term|Binary|Process|GenServer|Supervisor|Logger|System|Task|Agent|Down|Exit'
BS=$(git ls-files '*.bs' | grep -v '^artifacts/')

echo
echo "=== M1. every site in compiler/src that READS the reserved set (the cost of changing the policy)"
grep -n 'reserved_qualifiers()\|reserved_module_name\|compiler_known_redeclared\|compiler_known_function(\|protocol_table()' $SRC/*.erl | grep -v '^\S*:[0-9]*:%%' 
echo "--- count of reserved_qualifiers() call sites outside its definition:"
grep -c 'reserved_qualifiers()' $SRC/bs_check.erl $SRC/bs_emit.erl $SRC/bs_diag.erl | tr '\n' ' '; echo

echo
echo "=== M2. how many .bs files in the tree, and how many modules declare a whole-name (single segment) module"
echo "$BS" | wc -l
for f in $BS; do sed -n 's/^module  *\([A-Za-z0-9_.]*\).*/\1/p' "$f" | head -1; done | sort | uniq > /tmp/.m65_mods.$$
echo "distinct module names: $(wc -l < /tmp/.m65_mods.$$)"
echo "single-segment (whole-name) modules: $(grep -vc '\.' /tmp/.m65_mods.$$)"
echo "--- any module whose WHOLE name or LAST SEGMENT is a roster word (ticket 96 + 14 + 88):"
grep -E "(^|\.)($ROSTER)\$" /tmp/.m65_mods.$$ || echo "(none)"
rm -f /tmp/.m65_mods.$$

echo
echo "=== M3. records/types declared with a roster word as their name (the unqualified PascalCase namespace)"
grep -rnE "^\s*(record|type)\s+($ROSTER)\b" --include=*.bs . 2>/dev/null | grep -v '^./artifacts' || echo "(none)"

echo
echo "=== M4. qualified-call sites of the ALREADY-reserved qualifiers: the rewrite bill if they moved to another spelling (option 'a namespace users cannot reach')"
for q in List Map Term Float; do
  printf '%-6s .bs:%-4s compiler/test:%-4s LANGUAGE.md+TOUR.md+STANDARD-ENVIRONMENT.md+compiler/features:%s\n' "$q" \
    "$(grep -hoE "\b$q\.[A-Z][A-Za-z]*\(" $BS | wc -l)" \
    "$(grep -rhoE "\b$q\.[A-Z][A-Za-z]*\(" compiler/test | wc -l)" \
    "$(cat LANGUAGE.md TOUR.md STANDARD-ENVIRONMENT.md compiler/features/*.md | grep -oE "\b$q\.[A-Z][A-Za-z]*\(" | wc -l)"
done
echo "--- distinct {Qualifier, Operation, Arity} keys written anywhere in bs_check.erl (upper bound on table rows):"
grep -oE "\{'(List|Map|Term|Float)', '[A-Za-z]+', [0-9]+\}" $SRC/bs_check.erl | sort -u | wc -l

echo
echo "=== M5. which of ticket 96's roster qualifiers are unreserved TODAY (each would burn a name on arrival)"
RES=$(sed -n "s/^reserved_qualifiers() -> \(.*\)\./\1/p" $SRC/bs_check.erl)
echo "reserved_qualifiers() today: $RES"
for w in Enum String Int Binary Process GenServer Supervisor Logger System Task Agent; do
  case "$RES" in *"'$w'"*) s=reserved;; *) s="free today";; esac
  printf '%-11s %s\n' "$w" "$s"
done
echo "--- compiler-known types built today (a user cannot declare these; Timeout is not a type, ticket 88):"
grep -n "stratum_two() ->" -A 30 $SRC/bs_check.erl | grep -oE "'(ValidationError|Down|Exit)'" | sort -u | tr '\n' ' '; echo

echo
echo "=== M6. grammar words that already burned a lowercase identifier (each added with a feature, none under a reservation policy)"
grep -oE "^[a-z]+ +: \{token, \{'[a-z]+'" compiler/src/bs_lexer.xrl | sed "s/ *:.*//" | tr '\n' ' '; echo
echo "count: $(grep -cE "^[a-z]+ +: \{token, \{'[a-z]+'" compiler/src/bs_lexer.xrl)"
