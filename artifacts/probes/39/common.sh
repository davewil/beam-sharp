# Shared environment for the ticket-39 probes. Source it; do not run it.
# Toolchain per scratchpad ENV.md (OTP 29 / Elixir 1.20.4 / Gleam 1.18.1 under /tmp/otp).
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8 ELIXIR_ERL_OPTIONS="+fnu"
PROBES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$PROBES/../../.." && pwd)"
BENCH="$REPO/aoc/bench"
INPUT="$REPO/aoc/2025/Day01/input.txt"
# bsc built by hand (rebar3 broken on OTP 29); see ENV.md. Override with BSC=...
BSC="${BSC:-/tmp/claude-0/-home-user-beam-sharp/41c7fa9e-39c6-543b-8f3d-dee4a7daa0ba/scratchpad/bsc.sh}"
