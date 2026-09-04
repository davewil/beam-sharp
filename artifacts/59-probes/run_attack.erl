-module(run_attack).
-export([main/0]).
main() ->
    %% A forged Wrapper whose Payload wears the WRONG tag: same field
    %% shape as Order (Id, Total both integers), tagged 'Attack.Invoice'.
    %% This is exactly what a raw Erlang / Elixir caller outside beam-sharp
    %% could construct and send in -- there is no beam-sharp type checker
    %% standing between it and `Outer/1`, which is exported.
    Forged = #{'Payload' => #{'Kind' => 'Attack.Invoice', 'Id' => 1, 'Total' => 999999}},
    io:format("Calling Attack:'Outer'(~p)~n", [Forged]),
    try 'Attack':'Outer'(Forged) of
        Result -> io:format("RETURNED (no crash): ~p~n", [Result])
    catch
        Class:Reason ->
            io:format("CRASHED: ~p:~p~n", [Class, Reason])
    end,
    %% Control: a legitimate Order payload, to show the domain still works.
    Good = #{'Payload' => #{'Kind' => 'Attack.Order', 'Id' => 1, 'Total' => 50}},
    io:format("Calling Attack:'Outer'(~p)~n", [Good]),
    try 'Attack':'Outer'(Good) of
        Result2 -> io:format("RETURNED (no crash): ~p~n", [Result2])
    catch
        Class2:Reason2 ->
            io:format("CRASHED: ~p:~p~n", [Class2, Reason2])
    end,
    halt().
