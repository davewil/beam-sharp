#!/bin/bash
# Reruns every probe for ticket 60. Non-zero if any expected observation fails.
cd "$(dirname "$0")"; rc=0
for d in erlang elixir gleam elm; do echo "=========== $d"; bash $d/run.sh || { echo "FAILED: $d"; rc=1; }; done
exit $rc
