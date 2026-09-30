#!/usr/bin/env bash
# p16: `bsc --api` reads and never builds (bs_api.erl:60).  Is its answer independent of the environment?  If so, a
# presence check placed in the compile path must not leak into it, and the application list could be reported there.
cd "$(dirname "$0")"
echo '--- ERL_LIBS unset'
env -u ERL_LIBS ./bsc.sh --src-root programs --api programs/Up; echo "exit=$?"
echo '--- ERL_LIBS=/usr/lib/elixir/lib'
ERL_LIBS=/usr/lib/elixir/lib ./bsc.sh --src-root programs --api programs/Up; echo "exit=$?"
