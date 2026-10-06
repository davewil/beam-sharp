#!/usr/bin/env bash
# 59e driver: see 59e_platform_census.erl for the claim and the control.
set -uo pipefail
source "${ENV_SH:-/tmp/claude-0/-home-user-beam-sharp/5c54aeca-205c-5959-b98d-85886863a86f/scratchpad/env.sh}"
export ERL_CRASH_DUMP=/dev/null
W=$(mktemp -d); erlc -o "$W" "$(dirname "${BASH_SOURCE[0]}")/59e_platform_census.erl" && EB=$(dirname "$(dirname "$(readlink -f "$(which elixir)")")")/lib/elixir/ebin; erl -noshell -pa "$W" -pa "$EB" -eval "'59e_platform_census':main(), halt()."
