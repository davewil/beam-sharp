#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
BSC=$(build_bsc plain) || exit 1
compile_shop "$BSC" "$SCRATCH/shop-ebin"
BS_EBIN="$SCRATCH/shop-ebin" elixir "$(dirname "$0")/probe.exs" 2>&1
