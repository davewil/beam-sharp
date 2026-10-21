# Source me. Toolchain the probes were run with (see ../README.md for versions and what each probe needs).
# TC = where the toolchains were unpacked/built in the run's container; override to relocate.
TC=${TC:-/tmp/tc}
export PATH="$TC/otp28/bin:$TC/src/elixir/bin:$TC/gleam:$TC/elm:$PATH"
export ELIXIR_ERL_OPTIONS="+fnu"
export GLEAM_STDLIB="${GLEAM_STDLIB:-$TC/src/stdlib}"
export BSC="${BSC:-$(cd "$(dirname "${BASH_SOURCE:-$0}")/../.." && pwd)/compiler/_build/default/bin/bsc}"
