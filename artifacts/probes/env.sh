# Sourced by every probe. Reproduces the toolchain this batch measured with:
#   OTP 28.x, Elixir 1.20.4, Gleam 1.19.1, Elm 0.19.3  (conda-forge + npm; no rebar3)
# and builds the reference compiler from compiler/src with OTP 28 into $PROBE_HOME.
# Override PROBE_HOME to relocate; a pre-existing toolchain is reused.
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
export PROBE_HOME=${PROBE_HOME:-/tmp/claude-0/-home-user-beam-sharp/4470aa70-af51-55ae-b1b5-031ed97c6df4/scratchpad}
export PATH=$PROBE_HOME/mm/env/lib/elixir/bin:$PROBE_HOME/mm/env/bin:$PROBE_HOME/elm/node_modules/.bin:$PATH
export ELIXIR_ERL_OPTIONS="+fnu"
export BSC=$PROBE_HOME/bsc.sh
export BSC_SRC=$root/compiler/src
