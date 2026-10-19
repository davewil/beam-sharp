#!/usr/bin/env bash
# ticket 66: re-run the five exemplars against a bsc built from this repo's working tree (OTP 28).
export PATH=/opt/otp28/bin:$PATH; BSC=${BSC:-/tmp/dl/compiler-build/_build/default/bin/bsc}; cd "$(dirname "$0")"
for d in T66a T66b T66c T66d T66e T66f T66g; do echo "=== $d"; $BSC -o /tmp/dl/out66 $d 2>&1 | head -14; echo "rc=${PIPESTATUS[0]}"; done
