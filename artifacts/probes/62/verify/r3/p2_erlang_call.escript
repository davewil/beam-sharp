#!/usr/bin/env escript
%% PROBE 2 — a real B# module, built by the reference compiler, called from Erlang.
%% argv: ebin dir.
%% NOTE: first run FAILed only because the expected list was hand-written in the wrong sort order ('GetX' < 'Get_X' as 'X' < '_'); the observed exports matched the expectation as a set. Expectation now sorts.
%% EXPECTED (before run):
%%   exports (sorted, minus module_info) = 'Get_X'/1 'GetX'/1 'HTTPGet'/1 'New'/1 'Parse2Ints'/1 'Total'/1 'bs@type_atoms'/0
%%   'Api':'New'(1)  = #{'Id'=>1,'Kind'=>'Api.Order','Total'=>0}
%%   'Api':'GetX'(1) = 2 ; 'Get_X'(1) = 4 ; 'HTTPGet'(1) = 3
%%   Erlang needs no alias: no snake_case export exists ('Api':get_x(1) -> undef).
main([Ebin]) ->
    true = code:add_patha(Ebin),
    Ex = lists:sort([E || {N,_}=E <- 'Api':module_info(exports), N =/= module_info]),
    io:format("exports: ~p~n", [Ex]),
    io:format("New(1): ~p~n", ['Api':'New'(1)]),
    io:format("GetX(1): ~p Get_X(1): ~p HTTPGet(1): ~p~n",
              ['Api':'GetX'(1), 'Api':'Get_X'(1), 'Api':'HTTPGet'(1)]),
    io:format("get_x(1): ~p~n", [catch 'Api':get_x(1)]),
    Want = lists:sort([{'Get_X',1},{'GetX',1},{'HTTPGet',1},{'New',1},{'Parse2Ints',1},{'Total',1},{'bs@type_atoms',0}]),
    case Ex =:= Want andalso 'Api':'GetX'(1) =:= 2 andalso 'Api':'Get_X'(1) =:= 4
         andalso element(1, catch 'Api':get_x(1)) =:= 'EXIT' of
        true -> io:format("PASS p2~n"); false -> io:format("FAIL p2~n") end.
