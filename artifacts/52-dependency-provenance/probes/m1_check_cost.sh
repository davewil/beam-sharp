#!/usr/bin/env bash
# (d) Run: ./m1_check_cost.sh   (25 fresh VMs for cold; 200k-call loops for warm; then a 300-app ERL_LIBS)
H="$(cd "$(dirname "$0")" && pwd)"; FX="$H/fixtures/_fx"
[ -d "$FX/libA" ] || "$H/fixtures/build-fixtures.sh" >/dev/null
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
ELIXLIB=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/mm/root/envs/tc/lib/elixir/lib
# a big ERL_LIBS: 300 extra apps (empty ebin + .app)
BIG="$FX/libBig"; rm -rf "$BIG"; mkdir -p "$BIG"
for i in $(seq 1 300); do d="$BIG/fakeapp$i-1.0.0/ebin"; mkdir -p "$d"; echo "{application,fakeapp$i,[{vsn,\"1.0.0\"},{modules,[]},{applications,[kernel,stdlib]}]}." > "$d/fakeapp$i.app"; done
T=$(mktemp)
echo "### cold: first call in a fresh VM, ERL_LIBS = libA + elixir (3 + ~8 app dirs)"
for i in $(seq 25); do ERL_LIBS="$FX/libA:$ELIXLIB" escript "$H/m1_check_cost.escript" cold; done > "$T"; python3 -I "$H/m1_summ.py" "$T"
echo "### cold: ERL_LIBS = libA + elixir + 300 fake apps"
for i in $(seq 25); do ERL_LIBS="$FX/libA:$ELIXLIB:$BIG" escript "$H/m1_check_cost.escript" cold; done > "$T"; python3 -I "$H/m1_summ.py" "$T"
echo "### warm (200k calls each)"
ERL_LIBS="$FX/libA:$ELIXLIB" escript "$H/m1_check_cost.escript" warm
echo "### warm, 300 extra apps on the path"
ERL_LIBS="$FX/libA:$ELIXLIB:$BIG" escript "$H/m1_check_cost.escript" warm
echo "### NEGATIVE CONTROL: the harness can see a slow call (a deliberate 1 ms sleep, expect >= 1,000,000 ns; the sleep granularity here is coarser, which is reported as measured)"
erl -noshell -eval '{US,_}=timer:tc(fun()->[timer:sleep(1)||_<-lists:seq(1,100)] end), io:format("   sleep(1ms) x100: ~.1f ns/call~n",[US*1000/100]), halt().'
