%% Probe 14: per-call cost of an alias (tail call, local or remote) vs the original, 5M calls, 5 runs each.
-module('14_alias_call_cost').
-export([run/0]).
bench(F) -> lists:sort([element(1, timer:tc(fun() -> loop(F, 5000000) end)) || _ <- lists:seq(1, 5)]).
loop(_, 0) -> ok;
loop(F, N) -> F(N), loop(F, N - 1).
run() ->
    {module, _} = code:ensure_loaded('Shop'),
    O = 'Shop':'New'(1),
    io:format("original   'Amount'/1 us (5 runs sorted, 5M calls): ~p~n", [bench(fun(_) -> 'Shop':'Amount'(O) end)]),
    io:format("alias      amount/1   us: ~p~n", [bench(fun(_) -> 'Shop':amount(O) end)]).
