#!/usr/bin/env bash
# PROBE 62-03 — Claim (ticket 62 cand. 2): "Costs two exports per function and a rule for deriving the name."
# MEASURES the cost of snake_case aliases by transforming the .abstr bsc hands to compile:file/2
# (alias_xform.erl = the compiler delta in miniature) over every module in compiler/examples (27).
# Metrics: .beam bytes, export-table entries, chunk-level bytes (beam_lib), code:load_binary time, compile time.
# CONTROL: rebuilding the baseline from .abstr must be byte-identical to bsc's own .beam (printed first);
#          if not, the sizes are of a different artifact and the probe says so.
# Run from repo root: bash artifacts/probes/62/62_03_alias_cost.sh
set -uo pipefail
source /tmp/claude-0/-home-user-beam-sharp/5c54aeca-205c-5959-b98d-85886863a86f/scratchpad/env.sh
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT; mkdir -p "$W/all" "$W/ebin"
for d in $(find compiler/examples -name '*.bs' -not -path '*/exemplars/*' -printf '%h\n' | sort -u); do
  $BSC --src-root compiler/examples -o "$W/all" "$d" >/dev/null 2>&1 || echo "bsc FAILED on $d"
done
H=artifacts/probes/62
erlc -o "$W/ebin" $H/alias_xform.erl $H/alias_measure.erl
cd "$W" && erl -noshell -pa ebin -eval 'alias_measure:main(["all"])'
