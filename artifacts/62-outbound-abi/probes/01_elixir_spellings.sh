#!/usr/bin/env bash
# One command: ./01_elixir_spellings.sh  -> probes/01_elixir_spellings.out
HERE="$(cd "$(dirname "$0")" && pwd)"; source "$HERE/lib.sh"
build_examples "$WORK/ebin"
BS_EBIN="$WORK/ebin" elixir "$HERE/01_elixir_spellings.exs" 2>&1
