#!/usr/bin/env escript
%%! -pa ebin
-define(N, 20000000).
-define(R, 25).
main(_) ->
  Rec = #{'Kind' => 'M.Order', f1 => 1, f2 => 2},
  io:format("emu_flavor=~p otp=~s schedulers=~p~n",[erlang:system_info(emu_flavor),erlang:system_info(otp_release),erlang:system_info(schedulers_online)]),
  [begin
    io:format("== ~s~n",[Title]),
    [report(Label, M, F, Arg) || {Label,M,F,Arg} <- Rows]
   end || {Title, Rows} <-
   [{"record (tag test)",
     [{"u1  unguarded      local ",u1,loop_local,Rec},{"u2  unguarded(ctl) local ",u2,loop_local,Rec},{"gtag guarded       local ",gtag,loop_local,Rec},
      {"u1  unguarded      remote",u1,loop_remote,Rec},{"u2  unguarded(ctl) remote",u2,loop_remote,Rec},{"gtag guarded       remote",gtag,loop_remote,Rec}]},
    {"int (is_integer)",
     [{"i1  unguarded      local ",i1,loop_local,7},{"i2  unguarded(ctl) local ",i2,loop_local,7},{"gint guarded       local ",gint,loop_local,7},
      {"i1  unguarded      remote",i1,loop_remote,7},{"i2  unguarded(ctl) remote",i2,loop_remote,7},{"gint guarded       remote",gint,loop_remote,7}]}]],
  ok.
report(Label,M,F,Arg) ->
  M:F(1000000,Arg,0), %% warm
  Ts = lists:sort([begin
          erlang:garbage_collect(),
          T0 = erlang:monotonic_time(nanosecond),
          M:F(?N,Arg,0),
          (erlang:monotonic_time(nanosecond)-T0)/?N
       end || _ <- lists:seq(1,?R)]),
  io:format("~s  min=~.3f  median=~.3f  max=~.3f ns/op~n",[Label,hd(Ts),lists:nth((?R+1) div 2,Ts),lists:last(Ts)]).
