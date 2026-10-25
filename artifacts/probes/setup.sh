#!/usr/bin/env bash
# Recreates the probe toolchain under $SCRATCH (any empty directory). Needs outbound HTTPS to conda.anaconda.org only.
#   erlang 28 (erts 16.4 — the ticket 39 benchmark's own number), elixir 1.20.4, gleam 1.19.1  from conda-forge via micromamba
#   bsc, built by hand from compiler/src (rebar3 is not available): leex + yecc + erlc, then escript-free (driven by `bsc:main/1`)
# NOT AVAILABLE in this sandbox, so no probe here executes them: Elm's package registry (package.elm-lang.org) and Hex are blocked.
# `npm install elm` yields an elm 0.19.3 binary that cannot compile anything without elm/core.
set -euo pipefail
: "${SCRATCH:?set SCRATCH}"; mkdir -p "$SCRATCH/mm"; cd "$SCRATCH/mm"
curl -sS --max-time 120 -O https://conda.anaconda.org/conda-forge/linux-64/micromamba-2.9.0-0.tar.bz2
tar xjf micromamba-2.9.0-0.tar.bz2 bin/micromamba
MAMBA_ROOT_PREFIX="$SCRATCH/mm/root" ./bin/micromamba create -y -q -n bx -c conda-forge "erlang=28" gleam elixir
"$(dirname "$0")/build_variant.sh" none "$SCRATCH/ebin"
