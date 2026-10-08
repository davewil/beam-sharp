#!/usr/bin/env bash
# Re-runs every probe for ticket 52 and rewrites the .out files. Needs /tmp/bsbuild (stock) and /tmp/bsb_52_x (prototype) built.
cd "$(dirname "$0")"
for p in p1-premise-undef.sh p2-syntax-census.sh p3-beam-records.sh p5-elixir-mix-xref.sh p6-erlang-xref.sh p7-elm.sh p8-prototype-52x.sh p9-census.sh p10-timing-size.sh p13-verdict-purity.sh p14-ast-shape.sh p16-needs-size.sh p17-native-using-precedent.sh p18-post-hoc-needs-check.sh p19-warning-severity.sh p20-yecc-conflicts.sh; do
  ./$p > ${p%.sh}.out 2>&1; echo "ran $p"; done
for e in p4-derive-app p11-app-closure p12-name-collision p15-repetition; do ./$e.escript > $e.out 2>&1; echo "ran $e"; done
