#!/usr/bin/env bash
# Run: ./p4_derivable.sh   -- is the module->app map derivable at compile time (so "app:" would be redundant for the check)?
H="$(cd "$(dirname "$0")" && pwd)"; FX="$H/fixtures/_fx"
[ -d "$FX/libA" ] || "$H/fixtures/build-fixtures.sh" >/dev/null
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
ELIXLIB=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/mm/root/envs/tc/lib/elixir/lib
[ -f "$FX/size-Dep/Dep.beam" ] || "$H/bsc.sh" -o "$FX/size-Dep" --src-root "$H/bs" "$H/bs/Dep" >/dev/null 2>&1
echo "### with the deps present (machine 1)"
ERL_LIBS="$FX/libA:$ELIXLIB" escript "$H/p4_derivable.escript" "$FX/size-Dep/Dep.beam"
echo "### NEGATIVE CONTROL: machine 2 (deps absent): derivation must fail, not guess"
ERL_LIBS="$FX/libB:$ELIXLIB" escript "$H/p4_derivable.escript" "$FX/size-Dep/Dep.beam"
echo "### orphan module (on -pa, no app) and a dir-without-.app: derive reports it honestly"
ERL_LIBS="$FX/libA" erl -noshell -pa "$FX/orphan/ebin" -eval '
  io:format("orphanmod -> ~p~n",[(fun() -> P=code:which(orphanmod), filelib:wildcard(filename:join(filename:dirname(P),"*.app")) end)()]),
  io:format("noappmod -> ~p~n",[(fun() -> P=code:which(noappmod), filelib:wildcard(filename:join(filename:dirname(P),"*.app")) end)()]),
  halt().'
