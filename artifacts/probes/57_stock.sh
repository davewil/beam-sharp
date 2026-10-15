#!/usr/bin/env bash
# 57_stock -- claim (ticket 57, "The repro"): every refinement containing a negative
# integer literal is refused with opaque_refinement; rows 4 and 5 are accepted.
# REFUTED by: R01..R03 printing "accepted", or R04/R05 printing "refused" at HEAD.
# Also the full fold-boundary case set on the STOCK compiler (control for the variants).
# usage: 57_stock.sh [BSC]   (default: $BSC from env.sh)
. "$(dirname "$0")/env.sh"; . "$(dirname "$0")/57_lib.sh"; . "$(dirname "$0")/57_cases.sh"
run_cases "${1:-$BSC}"
