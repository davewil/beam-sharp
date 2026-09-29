%% usage: erl -noshell -pa EBIN -eval 'time:run("tree","tree/Shop/All",N)' -s init stop
%% Prints min and median wall ms of N in-VM compiles (plus one discarded warm-up).
-module(time).
-export([run/3]).
run(Root, Mod, N) ->
    Out = "/tmp/claude-0/p60time",
    Go = fun() -> {T, R} = timer:tc(fun() -> bsc:status(["--src-root", Root, "-o", Out, Mod], standalone) end),
                  {T, R} end,
    {_, R0} = Go(),
    Ts = lists:sort([element(1, Go()) || _ <- lists:seq(1, N)]),
    io:format("exit=~p N=~p min_ms=~.1f median_ms=~.1f max_ms=~.1f~n",
              [R0, N, hd(Ts)/1000, lists:nth((N div 2) + 1, Ts)/1000, lists:last(Ts)/1000]).
