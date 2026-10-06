#!/usr/bin/env bash
# 59i — CLAIM: how many private functions in the exemplar corpus (compiler/examples, excluding
# the non-compiling exemplars/) take a record parameter (would lose the tag test under
# `narrow`) and how many take a bare int/float parameter (would gain a test under `widen`)?
# Regex census over the signature lines (`private <ret> Name(<params>)`), so it is a count of
# declarations, not of emitted guards (59h measures the emitted effect). CONTROL: the same
# regex counts `public` signatures; a regex that found nothing there would be broken.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; cd "$REPO/compiler/examples"
F=$(find . -name '*.bs' -not -path './exemplars/*')
RECS=$(grep -h -o '^record [A-Za-z]*' $F | awk '{print $2}' | sort -u | paste -sd'|')
echo "records declared in corpus: $(echo "$RECS" | tr '|' ' ')"
for vis in private public; do
  sigs=$(grep -h "^$vis [^=]*(.*)\s*$" $F | grep -v '^\S* *//' )
  total=$(echo "$sigs" | grep -c .)
  rec=$(echo "$sigs" | grep -cE "\((.*[ ,(])?($RECS) [a-z]" )
  int=$(echo "$sigs" | grep -cE "[(,] *(int|float) [a-z]" )
  echo "$vis signatures: $total ; with a record param: $rec ; with an int/float param: $int"
done
