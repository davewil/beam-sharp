#!/bin/sh
# Run every probe; each exits non-zero if its own assertions on observed output fail.
cd "$(dirname "$0")" || exit 1
for p in p1_beam_has_no_caller_restriction.escript p2b_xref_needs_debug_info.escript p4_subtree_check_prototype.escript p5_beam_size_and_attr_read.escript p6_runtime_caller_check.escript; do echo "== $p"; escript "$p" || echo "PROBE FAILED: $p"; done
echo "== p2 (N=100,1000,3000)"; for n in 100 1000 3000; do escript p2_xref_caller_restriction.escript $n || echo "PROBE FAILED p2 $n"; done
echo "== p3"; elixir p3_elixir_privacy.exs || echo "PROBE FAILED p3"
