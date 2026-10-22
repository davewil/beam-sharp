#!/usr/bin/env bash
# Probe 05 — call-time cost of a guard on a private function (per element of a 1000-element list). Noise is reported, not hidden.
# Compares variant A (as built), B (tag exported-only) and C (int everywhere) from probe 02. OTP 25, this VM, not the ticket's OTP 28.5 arm64.
H="$(cd "$(dirname "$0")" && pwd)"; . "$H/lib.sh"
"$H/02-scope-variants.sh" >/dev/null 2>&1
for pass in 1 2; do echo "== pass $pass =="; "$H/bench.escript" "$SCRATCH/o-base" "$SCRATCH/o-narrow" "$SCRATCH/o-wide"; done
