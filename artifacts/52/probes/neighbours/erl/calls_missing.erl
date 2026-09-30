-module(calls_missing).
-export([go/0]).
go() -> libdep:hello(<<"x">>).
