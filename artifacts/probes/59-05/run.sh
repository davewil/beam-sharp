#!/usr/bin/env bash
# The 59-02 program under three compilers: base bsc, narrow prototype (tag test exported-only),
# widen prototype (int/float kind test also on private). Shows what each scope lets through.
set -u; HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/../59-common.sh"
W=$(mktemp -d); mkdir -p $W/src/T; cp "$HERE/t.bs" $W/src/T/t.bs
"$HERE/../59-04/make_variant.sh" $W/narrow narrow >/dev/null 2>&1; "$HERE/../59-04/make_variant.sh" $W/widen widen >/dev/null 2>&1
erlc -o $W "$HERE/forge.erl"
for v in base narrow widen; do
  case $v in base) b="$BSC";; *) b="$W/$v/_build/default/bin/bsc";; esac
  echo "=== $v ==="; rm -rf $W/out; "$b" -o $W/out --src-root $W/src $W/src/T >/dev/null 2>&1 || echo "compile failed"
  pp_abstr $W/out/T.abstr | grep -E "^'(Inner|Twice)'\(" 
  erl -noshell -pa $W/out -pa $W -eval 'forge:main(),halt().' 2>&1 | head
done
