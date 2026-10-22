#!/usr/bin/env bash
# Elixir's SOURCE is not installed (only ebin/). The installed elixir_tokenizer.beam carries debug_info, so the
# original elixir_tokenizer.erl line numbers are recoverable from the abstract code. Prints them.
BEAM=${BEAM:-/usr/lib/elixir/lib/elixir/ebin/elixir_tokenizer.beam}
elixir --version | tail -1
escript "$(dirname "$0")/lines.escript" "$BEAM"
