-module(caller).
-export([go/0]).
go() -> 'Elixir.Req':get(<<"http://x">>).
