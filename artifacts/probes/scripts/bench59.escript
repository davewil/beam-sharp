#!/usr/bin/env escript
%% bench59 DIR_A DIR_B : time Q:'Loop'(Order, 20M, 0) with each variant's Q.beam, 15 interleaved runs
main([A,B]) ->
  O = #{'Kind'=>'Q.Order','Id'=>1,'Total'=>2},
  Run = fun(D) -> code:purge('Q'), code:delete('Q'), {module,'Q'}=code:load_abs(D++"/Q"),
            T0=erlang:monotonic_time(microsecond), 40000000 = 'Q':'Loop'(O,20000000,0),
            (erlang:monotonic_time(microsecond)-T0)/1000 end,
  Rs = [{Run(A),Run(B)} || _ <- lists:seq(1,15)],
  Stat = fun(L) -> S=lists:sort(L), {lists:min(L), lists:nth(8,S)} end,
  io:format("A(~s) min/med ms ~p~nB(~s) min/med ms ~p~n",[A,Stat([X||{X,_}<-Rs]),B,Stat([Y||{_,Y}<-Rs])]).
