-module(literal).
-export([go/1]).
go(X) -> apply(callee, f, [X]).
