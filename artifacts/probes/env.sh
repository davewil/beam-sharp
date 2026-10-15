# Shared probe environment. Source it: `. artifacts/probes/env.sh`
# Toolchains (erlang 28, elixir 1.18, gleam, elm 0.19.2, rebar3) come from the nix profile.
export PATH="$HOME/.nix-profile/bin:$PATH"
export REPO="${REPO:-/home/user/beam-sharp}"
export BSC="$REPO/compiler/_build/default/bin/bsc"   # built from HEAD with `rebar3 escriptize`
# A fresh scratch dir per probe run, never inside the repo tree:
bs_scratch() { mktemp -d "${TMPDIR:-/tmp}/probe.XXXXXX"; }
