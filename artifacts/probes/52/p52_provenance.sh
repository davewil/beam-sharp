#!/usr/bin/env bash
# Ticket 52. What does a `.bs` file promise about its dependencies, and what happens on a machine that lacks them?
# A stand-in dependency (Hex is not reachable from this sandbox): an Elixir module `Demo` in an OTP application `demo-1.2.3`
# laid out exactly as rebar3 / mix leave it: lib/demo-1.2.3/ebin/{demo.app, Elixir.Demo.beam}.
. "$(dirname "$0")/../env.sh"
W=$(mktemp -d); LIBS=$W/libs; mkdir -p $LIBS/demo-1.2.3/ebin $W/src/Uses
printf 'defmodule Demo do\n  def double(n), do: n * 2\nend\n' > $W/demo.ex
(cd $W && elixirc -o $LIBS/demo-1.2.3/ebin demo.ex 2>&1 | grep -v 'native name')
cat > $LIBS/demo-1.2.3/ebin/demo.app <<'X'
{application, demo, [{description, "stand-in"}, {vsn, "1.2.3"}, {modules, ['Elixir.Demo']}, {registered, []}, {applications, [kernel, stdlib, elixir]}]}.
X
cat > $W/src/Uses/u.bs <<'X'
module Uses

using :'Elixir.Demo' {
    int double(int n)
}

public int Run(int n)
Run(n) -> :'Elixir.Demo'.double(n)
X
trim() { sed "s|$W/||g" | head -${1:-4} | cut -c1-170; }
for v in base Q; do
  e=$SCRATCH/ebin; [ $v = Q ] && e=$SCRATCH/v52/Q/ebin
  echo "######## compiler: $v   (Q = prototype: refuse at compile time a foreign module the code path cannot load)"
  echo "-- S1 build machine has the dependency (ERL_LIBS set)"
  ERL_LIBS=$LIBS BSC_EBIN=$e bsc -o $W/out-$v $W/src/Uses Run 21 2>&1 | trim 3; echo "   rc=${PIPESTATUS[0]}"
  echo "-- S2 a different machine: same source, ERL_LIBS unset, compile only"
  ( unset ERL_LIBS; BSC_EBIN=$e bsc -o $W/out2-$v $W/src/Uses 2>&1 | trim 4; echo "   rc=${PIPESTATUS[0]}" )
done
echo "-- S3 the .beam from S1 shipped to a VM without the dependency (what the user sees)"
env -u ERL_LIBS erl -noshell -pa $W/out-base -eval 'try '"'"'Uses'"'"':'"'"'Run'"'"'(21) catch C:R:S -> io:format("~p:~p~n  ~p~n", [C, R, hd(S)]) end, halt().'
echo "-- S4 can the compiler DERIVE the owning application from the module alone? (scan every ebin/*.app on the code path)"
ERL_LIBS=$LIBS erl -noshell -eval '
  M = '"'"'Elixir.Demo'"'"',
  io:format("code:which -> ~s~n", [code:which(M)]),
  Owners = [{App, proplists:get_value(vsn, Props)}
            || Dir <- code:get_path(), F <- filelib:wildcard(filename:join(Dir, "*.app")),
               {ok, [{application, App, Props}]} <- [file:consult(F)],
               lists:member(M, proplists:get_value(modules, Props, []))],
  io:format("applications on the code path whose modules list contains ~p -> ~p~n", [M, Owners]), halt().'
echo "-- S5 what the .beam records today about foreign modules it calls (attribute chunk)"
erl -noshell -eval '{ok, {_, [{attributes, A}]}} = beam_lib:chunks("'$W'/out-base/Uses.beam", [attributes]), io:format("~p~n", [A]), {ok,{_,[{imports,I}]}} = beam_lib:chunks("'$W'/out-base/Uses.beam",[imports]), io:format("imports: ~p~n",[I]), halt().'
