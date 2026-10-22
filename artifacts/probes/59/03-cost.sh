#!/usr/bin/env bash
# Probe 03 — what the guards cost in bytes, and whether erlc already elides them on a local function.
# Runs sizes.escript over the three variants built by probe 02 (builds them if missing).
H="$(cd "$(dirname "$0")" && pwd)"; . "$H/lib.sh"
"$H/02-scope-variants.sh" >/dev/null 2>&1
for V in base narrow wide; do echo "--- $V ---"; "$H/sizes.escript" "$SCRATCH/o-$V/T.beam"; done
