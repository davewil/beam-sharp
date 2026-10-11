#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"; source "$HERE/lib.sh"
build_examples "$WORK/ebin"
BS_EBIN="$WORK/ebin" elixir "$HERE/08_record_and_kind.exs" 2>&1
