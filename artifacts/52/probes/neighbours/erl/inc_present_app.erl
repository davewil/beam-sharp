-module(inc_present_app).
-include_lib("stdlib/include/ms_transform.hrl").
-export([go/0]).
go() -> ets:fun2ms(fun({A, _}) -> A end).
