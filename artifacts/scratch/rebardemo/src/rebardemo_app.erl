-module(rebardemo_app).
-behaviour(application).
-export([start/2, stop/1]).
start(_StartType, _StartArgs) ->
    io:format("~s~n", [rebarlib:greet("world")]),
    rebardemo_sup:start_link().
stop(_State) -> ok.
