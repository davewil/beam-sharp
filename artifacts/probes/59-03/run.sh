#!/usr/bin/env bash
# Corpus census: across the checked-in examples, how many PRIVATE functions carry the record tag test
# (and how many exported ones carry it / is_integer). Compiles every module directory it can.
set -u; HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/../59-common.sh"
W=$(mktemp -d); erlc -o $W "$HERE/count.erl"
ok=0; fail=0
for d in $(cd $REPO/compiler/examples && find . -name '*.bs' -not -path './exemplars/*' -printf '%h\n' | sort -u | sed 's|^\./||'); do
  if "$BSC" -o $W/out --src-root $REPO/compiler/examples $REPO/compiler/examples/$d >$W/log 2>&1; then ok=$((ok+1)); else fail=$((fail+1)); echo "compile failed: $d"; fi
done
echo "compiled ok=$ok failed=$fail"
erl -noshell -pa $W -eval 'count:main(["'$W/out'"]),halt().'
