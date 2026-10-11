#!/usr/bin/env bash
# Probe (b). Run: ./p2_presence.sh
H="$(cd "$(dirname "$0")" && pwd)"; FX="$H/fixtures/_fx"
[ -d "$FX/libA" ] || "$H/fixtures/build-fixtures.sh" >/dev/null
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
ELIXLIB=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/mm/root/envs/tc/lib/elixir/lib
echo "### machine 1: ERL_LIBS has dep apps + Elixir; orphan dir on -pa"
ERL_LIBS="$FX/libA:$ELIXLIB" ERL_FLAGS="-pa $FX/orphan/ebin" escript "$H/p2_presence.escript"
echo
echo "### machine 2 (NEGATIVE CONTROL: libB lacks the deps; same probe must now report absent): "
ERL_LIBS="$FX/libB:$ELIXLIB" escript "$H/p2_presence.escript" | grep -A3 -E '^(mix app|erlc app|elixir stdlib)'
