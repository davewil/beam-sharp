#!/usr/bin/env bash
# Probe (a): does compiling against a different ERL_LIBS fail only at the call site, with error:undef?
# Run: ./p1_undef_only_at_call_site.sh
H="$(cd "$(dirname "$0")" && pwd)"; FX="$H/fixtures/_fx"
[ -d "$FX/libA" ] || "$H/fixtures/build-fixtures.sh" >/dev/null
BSC="${BSC:-$H/bsc.sh}"
ELIXLIB=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/mm/root/envs/tc/lib/elixir/lib
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
run() { # label ERL_LIBS fn arg
  echo "--- [$1] ERL_LIBS='${2//$FX/FX}'  bsc bs/Dep $3 $4"
  ERL_LIBS="$2" "$BSC" --src-root "$H/bs" "$H/bs/Dep" "$3" $4 2>&1 | sed 's/^/    /'
  echo "    exit=${PIPESTATUS[0]}"
}
echo "== machine 1: ERL_LIBS has the dep apps AND the Elixir install =="
run M1-exdep   "$FX/libA:$ELIXLIB" ViaExDep '<<"hi">>'
run M1-erl     "$FX/libA:$ELIXLIB" ViaErl 21
run M1-stdlib  "$FX/libA:$ELIXLIB" ViaStdlib '<<"hi">>'
echo "== machine 2: a DIFFERENT ERL_LIBS: has Elixir, lacks the dep apps (the ticket's scenario) =="
run M2-exdep   "$FX/libB:$ELIXLIB" ViaExDep '<<"hi">>'
run M2-erl     "$FX/libB:$ELIXLIB" ViaErl 21
run M2-stdlib  "$FX/libB:$ELIXLIB" ViaStdlib '<<"hi">>'
echo "== machine 3: ERL_LIBS has the dep apps but NOT Elixir (exdep's own dependency is missing) =="
run M3-exdep   "$FX/libA" ViaExDep '<<"hi">>'
echo "== NEGATIVE CONTROL: a function touching no foreign module, machine 2 (must succeed: compile did not fail, only the call site does) =="
run M2-pure    "$FX/libB:$ELIXLIB" Pure 41
echo "== compile alone (no function named) on machine 2: does bsc complain at compile time? =="
ERL_LIBS="$FX/libB:$ELIXLIB" "$BSC" -o "$FX/out-m2" --src-root "$H/bs" "$H/bs/Dep" 2>&1 | sed 's/^/    /'; echo "    exit=${PIPESTATUS[0]}  stderr+stdout shown above (empty = silent)"
ls "$FX/out-m2" | sed 's/^/    built: /'
echo "== the real stack, from an Erlang node on machine 2, calling the beam bsc just produced =="
ERL_LIBS="$FX/libB:$ELIXLIB" escript "$H/p1_stack.escript" "$FX/out-m2" | sed 's/^/    /'
echo "== same beam on machine 1 (control: the undef disappears when the dep is present) =="
ERL_LIBS="$FX/libA:$ELIXLIB" escript "$H/p1_stack.escript" "$FX/out-m2" | sed 's/^/    /'
