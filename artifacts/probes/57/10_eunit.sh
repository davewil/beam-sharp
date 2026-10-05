#!/usr/bin/env bash
# 10 -- the repo's own eunit suite against every variant, ONE AT A TIME.
# (Run in parallel, five at once, a subprocess-driving test timed out and
# eunit cancelled the run -- see CHANGELOG.md item 9.)
# REFUTES "a fold is test-neutral": any variant with MORE failures than base.
# The base run is the control: it has the same failures a clean copy has.
# Opt out with SKIP_EUNIT=1 (the suite takes ~7 minutes wall clock).
. "$(dirname "$0")/lib.sh"
[ "${SKIP_EUNIT:-0}" = 1 ] && { echo "SKIPPED (SKIP_EUNIT=1)"; exit 0; }
mkdir -p "$OUT/eunit"
for v in base g1 g1b c1 c2; do
  ( cd "$WORK/$v/compiler" && s=$(date +%s) && rebar3 eunit > "$OUT/eunit/$v.txt" 2>&1; echo "wall_seconds=$(( $(date +%s) - s ))" > "$OUT/eunit/$v.time" )
done
for v in base g1 g1b c1 c2; do
  printf '%-5s %s  (%s)\n' $v "$(grep -E 'Failed: [0-9]+\.|All [0-9]+ tests passed' "$OUT/eunit/$v.txt" | tail -1 | sed 's/^ *//')" "$(cat "$OUT/eunit/$v.time")"
  grep -E '\*failed\*' "$OUT/eunit/$v.txt" | sed 's/^ */      /'
done
