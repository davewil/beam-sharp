#!/usr/bin/env bash
# Probe 06 -- cost of Option 1 (tag option<T> itself): compile every example directory under compiler/examples
# with the baseline bsc and with a bsc whose prelude says option<T> = (:some, T) | :nothing, and diff the verdicts.
# A directory that compiled and no longer does is code that depends on the bare shape.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib/env.sh"
REPO="$(cd "$HERE/../../../.." && pwd)"
TAGGED="$("$HERE/../lib/build-bsc-tagged-option.sh" | tail -1)"
OUTD="$(mktemp -d)"; cd "$REPO/compiler/examples"
tot=0; both=0; newfail=0; basefail=0
printf '%-48s %-8s %-8s %s\n' DIR baseline tagged "first tagged diagnostic"
while read -r d; do
  tot=$((tot+1))
  b="$("$BSC" -o "$OUTD" --src-root . "$d" 2>&1 </dev/null)"; brc=$?
  t="$("$TAGGED" -o "$OUTD" --src-root . "$d" 2>&1 </dev/null)"; trc=$?
  [ $brc -ne 0 ] && basefail=$((basefail+1))
  if [ $brc -eq 0 ] && [ $trc -ne 0 ]; then newfail=$((newfail+1)); printf '%-48s %-8s %-8s %s\n' "$d" ok REFUSED "$(printf '%s' "$t" | head -1 | cut -c1-110)"; fi
  [ $brc -eq 0 ] && [ $trc -eq 0 ] && both=$((both+1))
done < <(find . -name '*.bs' -printf '%h\n' | sort -u | sed 's#^\./##')
echo "dirs=$tot  ok under both=$both  ok-baseline-but-refused-tagged=$newfail  failing at baseline already=$basefail"
echo "--- .bs lines mentioning option< or :nothing under compiler/examples:"
grep -rn 'option<\|:nothing' --include=*.bs . | wc -l
echo "--- of those, in files that declare option<:"
grep -rl 'option<' --include=*.bs . | sort
echo "--- exemplars/ (ticket 25's targets; the repo's own FRONTIER file records that they stop early, so they cannot show the tagged-option cost by compiling):"
cd exemplars
for d in */; do printf '%-30s baseline: %s\n' "${d%/}" "$("$BSC" -o "$OUTD" --src-root "$PWD" "${d%/}" 2>&1 </dev/null | head -1 | cut -c1-120)"; done
echo "--- does option<option<int>> (15 §1's nesting case) and option<atom> survive under each bsc?"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/N"; printf 'module N\npublic option<option<int>> F(option<option<int>> x)\nF(x) -> x\npublic option<atom> G(option<atom> x)\nG(x) -> x\npublic option<term> H(option<term> x)\nH(x) -> x\n' > "$W/N/N.bs"
for v in base tagged; do B="$BSC"; [ $v = tagged ] && B="$TAGGED"; echo "[$v]"; "$B" -o "$W" "$W/N" </dev/null 2>&1 | grep -E 'error' | sed "s#$W/##"; "$B" --api "$W/N" </dev/null 2>&1 | grep -E '^[^/]*[FGH]\(' ; done
