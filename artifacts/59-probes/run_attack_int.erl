-module(run_attack_int).
-export([main/0]).
main() ->
    Forged = #{'Payload' => <<"not an integer at all">>},
    io:format("Calling AttackInt:'Outer'(~p)~n", [Forged]),
    try 'AttackInt':'Outer'(Forged) of
        Result -> io:format("RETURNED (no crash): ~p~n", [Result])
    catch
        Class:Reason -> io:format("CRASHED: ~p:~p~n", [Class, Reason])
    end,
    Forged2 = #{'Payload' => 300.5},
    io:format("Calling AttackInt:'Outer'(~p)~n", [Forged2]),
    try 'AttackInt':'Outer'(Forged2) of
        Result2 -> io:format("RETURNED (no crash): ~p~n", [Result2])
    catch
        Class2:Reason2 -> io:format("CRASHED: ~p:~p~n", [Class2, Reason2])
    end,
    Good = #{'Payload' => 100},
    io:format("Calling AttackInt:'Outer'(~p)~n", [Good]),
    try 'AttackInt':'Outer'(Good) of
        Result3 -> io:format("RETURNED (no crash): ~p~n", [Result3])
    catch
        Class3:Reason3 -> io:format("CRASHED: ~p:~p~n", [Class3, Reason3])
    end,
    halt().
