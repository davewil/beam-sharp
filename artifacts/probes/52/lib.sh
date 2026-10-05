# Common setup for every probe. Source it; do not run it.
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. /tmp/claude-0/-home-user-beam-sharp/c0642514-f9d1-5f22-91e2-015f96c1f119/scratchpad/env.sh
SCRATCH=/tmp/claude-0/-home-user-beam-sharp/c0642514-f9d1-5f22-91e2-015f96c1f119/scratchpad
WORK=${WORK:-$SCRATCH/p52work}
export WORK ROOT
export MIX_HOME=$WORK/mixhome HEX_OFFLINE=1 MIX_ENV=dev
MYLIBS=$WORK/mixlib/mylib/_build/dev/lib      # ERL_LIBS dir holding the mix-built Elixir app `mylib`
ERLLIBS=$WORK/erllibs                          # plainerl-1.2.0 (OTP-style app), ghost-1.0.0 (.app only)
BS=$ROOT/fixtures/bs
PBSC=$WORK/patched/compiler/_build/default/bin/bsc   # built by 04-build-patched-bsc.sh
