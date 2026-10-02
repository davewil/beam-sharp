-module(uses_missing).
-export([go/0]).
go() -> 'Elixir.Req':new([]).
