#!/usr/bin/env bash
# p07b: Elixir's own "provenance check": mix compares the APPLICATION a called module belongs to against the
# app's declared deps.  libdep is reachable on ERL_LIBS in both runs; only the manifest differs.
# Needs /tmp/mixdeps52b (see brief.md Reproduce).  Uses `mix compile --force` so the warning is re-emitted.
export MIX_HOME=/tmp/mixdeps52b/.mix HEX_HOME=/tmp/mixdeps52b/.hex
echo '--- A. consumer_undeclared: deps: [], libdep on ERL_LIBS'
( cd /tmp/mixdeps52b/consumer_undeclared && ERL_LIBS=/tmp/mixdeps52b/consumer/_build/dev/lib mix compile --force 2>&1 )
echo '--- B. consumer: deps: [{:libdep, path: "../libdep"}]'
( cd /tmp/mixdeps52b/consumer && mix compile --force 2>&1 )
