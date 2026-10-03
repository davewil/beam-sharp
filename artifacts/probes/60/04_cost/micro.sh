#!/bin/sh
# N=100 (default) or `N=500 ./micro.sh` for a 1001-module world.
# Probe 60/04b: the rule in isolation. Wall-clock above cannot resolve a few percent (noise is +-15%), so time the
# prototype's own functions: bs_check from proto2 rebuilt with +export_all, called on the real module names of the tree.
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
W=/tmp/claude-0/-home-user-beam-sharp/41c7fa9e-39c6-543b-8f3d-dee4a7daa0ba/scratchpad/proto60
rm -rf $W/micro; mkdir -p $W/micro; cp $W/proto2/ebin/*.beam $W/micro/
( cd $W/proto2/src && erlc +debug_info +export_all -o $W/micro bs_check.erl >/dev/null 2>&1 )
erl -noshell -pa $W/micro -eval '
  N = list_to_integer(os:getenv("N", "100")),
  Ms = [list_to_atom("Acme.Lib.Internal.I" ++ integer_to_list(I)) || I <- lists:seq(0, N-1)]
       ++ [list_to_atom("Acme.Lib.P" ++ integer_to_list(I)) || I <- lists:seq(0, N-1)],
  Self = list_to_atom("Acme.Lib.P50"),
  Loop = fun(Reps) -> fun() -> [[bs_check:internal_visible(M, Self) || M <- Ms] || _ <- lists:seq(1, Reps)], ok end end,
  _ = (Loop(10))(),
  Reps = 500,
  {US, ok} = timer:tc(Loop(Reps)),
  Calls = Reps * length(Ms),
  io:format("internal_visible/2: ~p calls in ~p ms = ~.2f us/call~n", [Calls, US div 1000, US / Calls]),
  Usings = 740,  % grep -rh '^using' tree100 | wc -l
  io:format("one tree compile has ~p using-lines (201 modules): ~.2f ms total at the using site~n", [Usings, Usings * US / Calls / 1000]),
  World = maps:from_list([{M, #{types => #{}}} || M <- Ms]),
  F = fun() -> maps:filter(fun(M, _) -> bs_check:internal_visible(M, Self) end, World) end,
  {US2, _} = timer:tc(fun() -> [F() || _ <- lists:seq(1, 200)] end),
  io:format("v2 world filter, one module, world of ~p: ~.1f us per module; x201 modules = ~.1f ms per compile~n",
            [map_size(World), US2 / 200, US2 / 200 * 201 / 1000]),
  halt().' 2>&1
