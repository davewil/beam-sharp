#!/usr/bin/env bash
export PATH=$HOME/.nix-profile/bin:$PATH
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$HERE/../../.."
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; mkdir -p "$W/ebin"
"$ROOT/compiler/_build/default/bin/bsc" --src-root "$ROOT/compiler/examples" -o "$W/ebin" "$ROOT/compiler/examples/Shop" >/dev/null 2>&1
BS_EBIN="$W/ebin" elixir "$HERE/03_elixir_workarounds.exs" 2>&1
