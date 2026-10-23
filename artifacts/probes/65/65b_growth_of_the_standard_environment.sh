#!/usr/bin/env bash
# PROBE 65b — has the reserved set / standard environment GROWN, or is it closed?
#
# Ticket 65's gating question: "is B#'s standard environment closed by intent?"
# A closed set shows a flat curve after its founding rows; an accreting one keeps
# climbing. This reads every commit that touched compiler/src/bs_check.erl, pulls
# (a) the `reserved_qualifiers()` list and (b) the standard table's distinct
# {Qualifier, Operation, Arity} keys, and prints the first commit on each date
# where either changed. It reads history, it does not run the compiler.
#
# NEEDS FULL HISTORY (`git rev-parse --is-shallow-repository` must say false).
# A shallow clone has ~50 commits and would print a flat line for the wrong reason:
# the script refuses rather than print it.
#
#   bash artifacts/probes/65/65b_growth_of_the_standard_environment.sh
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
if [ "$(git rev-parse --is-shallow-repository)" != false ]; then
  echo "REFUSED: shallow clone; a growth curve over 50 commits is not a curve"; exit 2
fi
F=compiler/src/bs_check.erl
prev=""
echo "date        commit   qualifiers-reserved            rows"
git log --reverse --format='%h %cs' -- "$F" | while read -r h d; do
  src="$(git show "$h:$F" 2>/dev/null)" || continue
  quals="$(printf '%s\n' "$src" | grep -E -A1 "^reserved_qualifiers\(\) ->" | tr -d '\n' | sed -E "s/.*-> *\[([^]]*)\].*/\1/; s/'//g; s/ //g")"
  # distinct table keys; both historical spellings: {{'List','Sum',1}, ...} and {'List','Sum',1}
  rows="$(printf '%s\n' "$src" | grep -E -o "\{\{?'(List|Map|Term|Float|String|Int|Process|GenServer|Supervisor|Logger|Enum)', *'[A-Za-z]+', *[0-9]\}" | sed -E "s/^\{+//; s/\}$//" | sort -u | wc -l)"
  cur="$quals|$rows"
  if [ "$cur" != "$prev" ]; then printf '%s  %s  %-28s %s\n' "$d" "$h" "${quals:-<none>}" "$rows"; prev="$cur"; fi
done
