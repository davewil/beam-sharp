#!/usr/bin/env bash
# Emitted Erlang abstract form for a negative literal, base vs parser-fold (A). Also times 10 compiles.
. "$(dirname "$0")/../lib.sh"
d=$(mktemp -d); mkdir $d/Neg; printf 'module Neg\npublic int K()\nK() -> -5\npublic int J(int x)\nJ(x) -> x - -5\n' > $d/Neg/a.bs
for v in base A D; do
  case $v in base) BSC_EBIN=/tmp/bsbuild/ebin;; *) BSC_EBIN=/tmp/bsb_$v/ebin;; esac
  echo "== $v"
  (cd $d && rm -rf out && mkdir out && bsc Neg/a.bs >/dev/null 2>&1; ls Neg out 2>/dev/null | tr '\n' ' '; echo)
  f=$(find $d -name '*.abstr' | head -1)
  if [ -n "$f" ]; then grep -n "'K'" -A3 "$f" | head -8; else echo "(no .abstr found)"; fi
  find $d -name '*.abstr' -delete; find $d -name '*.beam' -delete
  ts=(); for i in 1 2 3 4 5 6 7 8 9 10; do s=$(date +%s%N); (cd $d && bsc Neg/a.bs >/dev/null 2>&1); e=$(date +%s%N); ts+=($(( (e-s)/1000000 ))); done
  echo "compile ms x10: $(printf '%s\n' "${ts[@]}" | sort -n | tr '\n' ' ')"
done
rm -rf $d
