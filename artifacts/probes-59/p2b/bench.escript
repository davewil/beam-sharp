#!/usr/bin/env escript
%%! -pa ebin
-define(N, 20000000).
-define(R, 25).
main(_) ->
  Rec = #{'Kind' => 'M.Order', f1 => 1, f2 => 2},
  [begin
    M:loop(1000000,Rec,0),
    Ts = lists:sort([begin erlang:garbage_collect(), T0=erlang:monotonic_time(nanosecond), M:loop(?N,Rec,0), (erlang:monotonic_time(nanosecond)-T0)/?N end || _ <- lists:seq(1,?R)]),
    io:format("~-10s min=~.3f median=~.3f max=~.3f ns/op~n",[M,hd(Ts),lists:nth((?R+1) div 2,Ts),lists:last(Ts)])
   end || M <- [none_a, none_b, ex_only, every_fn]].
