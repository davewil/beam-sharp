#!/usr/bin/env bash
set -u; cd "$(dirname "$0")"; . ./env.sh; export ELIXIR_ERL_OPTIONS="+fnu"; elixir 59_elixir.exs 2>&1
