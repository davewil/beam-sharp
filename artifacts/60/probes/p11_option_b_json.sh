#!/usr/bin/env bash
# P11: the prototype's new tag on the JSON wire (F47). `parent` is a charlist in the prototype;
# bs_diag's roster decides which integer lists are text, per tag, and the prototype added no entry.
cd "$(dirname "$0")"; export BSC_EBIN=/tmp/bsc-build-60b/ebin
[ -d $BSC_EBIN ] || ./p5_option_b_prototype.sh >/dev/null 2>&1
./_bsc.sh --diagnostics json --src-root fx -o /tmp/p11out fx/Shop/Reports 2>/dev/null; echo "exit=$?"
