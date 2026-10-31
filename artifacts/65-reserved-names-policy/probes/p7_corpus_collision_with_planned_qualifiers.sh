#!/usr/bin/env bash
# Probe (measure): how many bare module names in the repo's own .bs corpus would be refused if every qualifier the
# tickets name as planned/candidate were reserved?  Planned set is read from the ticket text by grep, shown, not assumed.
# Run: bash p7_corpus_collision_with_planned_qualifiers.sh   (from anywhere)
set -u
R=/home/user/beam-sharp
echo "--- .bs files (excluding _build):"; find $R -name '*.bs' -not -path '*/_build/*' | wc -l
find $R -name '*.bs' -not -path '*/_build/*' -print0 | xargs -0 grep -HE '^[[:space:]]*module[[:space:]]+[A-Za-z0-9_.]+' \
  | sed -E 's#^([^:]+):[[:space:]]*module[[:space:]]+([A-Za-z0-9_.]+).*#\2 \1#' > /tmp/p7_mods.txt
echo "--- module declarations: $(wc -l < /tmp/p7_mods.txt), bare (undotted): $(awk '$1 !~ /\./' /tmp/p7_mods.txt | wc -l)"
echo "--- planned/candidate qualifiers, as named in tickets (grep evidence):"
grep -n -E 'Each new qualifier|`Enum`, `String`, `Int`, `Process`' $R/wayfinder/issues/96-standard-environment-breadth.md | cut -c1-200
grep -n -E '`Binary` joins' $R/wayfinder/issues/93-binary-operations-under-a-reserved-qualifier.md | cut -c1-160
grep -n -E '`Task` is a reserved qualifier' $R/wayfinder/issues/98-task-and-agent.md | cut -c1-160
grep -n -E 'Stream\.Map' $R/wayfinder/issues/17-pipeline-and-comprehension.md | head -1 | cut -c1-160
PLANNED="Enum String Int Process GenServer Supervisor Logger System Binary Task Agent Stream"
CURRENT="List Map Term Float Enumerable"
echo "--- corpus modules whose WHOLE name is in the CURRENT set (must be none: the compiler refuses them):"
for n in $CURRENT; do awk -v n=$n '$1==n' /tmp/p7_mods.txt; done
echo "--- corpus modules whose WHOLE name is in the PLANNED/candidate set (would be refused after those land):"
for n in $PLANNED; do awk -v n=$n '$1==n' /tmp/p7_mods.txt; done
echo "--- (control) names near the planned set that are NOT matches, to show the filter is exact:"
awk '$1=="Atom"||$1=="Math"||$1=="Queue"' /tmp/p7_mods.txt | head
