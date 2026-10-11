#!/usr/bin/env bash
# (d) Run: ./m3_pipeline_cost.sh
H="$(cd "$(dirname "$0")" && pwd)"; FX="$H/fixtures/_fx"
[ -d "$FX/libA" ] || "$H/fixtures/build-fixtures.sh" >/dev/null
[ -d "$H/fixtures/_proto/ebin" ] || "$H/../prototype/build.sh" >/dev/null
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
ELIXLIB=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/mm/root/envs/tc/lib/elixir/lib
echo "### deps present, ERL_LIBS = libA + elixir"
ERL_LIBS="$FX/libA:$ELIXLIB" escript "$H/m3_pipeline_cost.escript" "$H/fixtures/_proto/ebin" "$H/bs/DeclA/decla.bs" "$FX/m3out"
