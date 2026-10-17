#!/usr/bin/env bash
# Ticket 60 probes. Builds three compilers from compiler/src (copies; nothing in compiler/ is edited) then runs every probe.
set -u
here=$(cd "$(dirname "$0")" && pwd); w=${1:-$(mktemp -d)}
$here/build-bsc.sh $w/base; $here/build-bsc.sh $w/p1 $here/p1-internal-segment.patch; $here/build-bsc.sh $w/p2 $here/p2-internal-marker.patch
for p in "p1_baseline.sh $w/base" "p2_beam_side.sh $w/base" "p5_private_covers_siblings.sh $w/base" \
         "p4_checker_cost.sh $w/base $w/p1 120 6" "p7_matrix.sh $w/base $w/p1 $w/p2" p6_elixir_hidden_not_refused.sh \
         p8_gleam_internal.sh p9_go_internal.sh p10_corpus.sh; do
  echo; echo "######## $p"; $here/$p 2>&1
done
echo; echo "######## p3"; s=$(mktemp -d); erlc -o $s $here/p3_runtime_check_cost.erl && erl -noshell -pa $s -eval 'p3_runtime_check_cost:main(), halt().'
echo; echo "######## p4b"; erlc -o $s $here/p4b_visible_to_micro.erl && erl -noshell -pa $s -eval 'p4b_visible_to_micro:main(), halt().'
