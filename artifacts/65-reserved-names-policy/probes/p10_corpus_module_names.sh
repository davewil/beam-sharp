#!/usr/bin/env bash
# P10: every `module X` declared in the repo's .bs corpus (examples, tests' fixtures excluded: .bs files only), single-segment vs dotted.
cd /home/user/beam-sharp
grep -rhoE '^module [A-Za-z0-9_.]+' --include=*.bs --exclude-dir=_build compiler wayfinder 2>/dev/null | sort | uniq -c | sort -rn
echo "--- single-segment module names (the only shape a reserved bare name can refuse):"
grep -rhoE '^module [A-Za-z0-9_]+$' --include=*.bs --exclude-dir=_build compiler wayfinder 2>/dev/null | sort -u | tr '\n' ' '; echo
echo "--- candidate future qualifiers appearing as a top-level module name anywhere in the .bs corpus:"
for n in String Set Option Result Json Binary Int Bool Atom Tuple Enum Seq Order Math Time Regex File IO; do
  c=$(grep -rlE "^module $n\$" --include=*.bs --exclude-dir=_build compiler wayfinder 2>/dev/null | wc -l); echo "$n $c"; done | tr '\n' ';'; echo
# distinct single-segment module declarations (count):
grep -rhoE '^module [A-Za-z0-9_]+$' --include=*.bs --exclude-dir=_build compiler wayfinder | sort -u | wc -l
