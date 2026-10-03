#!/usr/bin/env escript
%% usage: bench.escript OUTDIR FUN ITERS  -> prints ns per loop iteration (one timed rep after a warm-up)
main([Dir, Fun, NS]) ->
    N = list_to_integer(NS), F = list_to_atom(Fun),
    true = code:add_patha(Dir), {module, 'Bench'} = code:load_file('Bench'),
    Cart = #{'Kind' => 'Bench.Cart', 'Item' => #{'Kind' => 'Bench.Order', 'Id' => 1, 'Total' => 2}, 'N' => 3},
    _ = 'Bench':F(2000000, Cart, 0),
    erlang:garbage_collect(),
    T0 = erlang:monotonic_time(nanosecond),
    _ = 'Bench':F(N, Cart, 0),
    T1 = erlang:monotonic_time(nanosecond),
    io:format("~.4f~n", [(T1 - T0) / N]).
