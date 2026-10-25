%% usage: erl -noshell -pa EBIN -run cost_driver main TREE N OUT LABEL   (compiled with erlc -o scratch)
-module(cost_driver).
-export([main/1]).
main([Tree, NS, Out, Label]) ->
    N = list_to_integer(NS),
    Dirs = [Tree ++ "/Gen/M" ++ integer_to_list(I) || I <- lists:seq(0, N - 1)],
    Args = ["--src-root", Tree, "-o", Out] ++ Dirs,
    Once = fun() -> {T, _} = timer:tc(fun() -> 0 = bsc:status(Args, standalone) end), T div 1000 end,
    _ = Once(),                                   %% warm-up, discarded
    Ts = [Once() || _ <- lists:seq(1, 7)],
    io:format("~-36s ms: ~w  median=~p min=~p max=~p~n",
              [Label, Ts, lists:nth(4, lists:sort(Ts)), lists:min(Ts), lists:max(Ts)]),
    halt(0).
