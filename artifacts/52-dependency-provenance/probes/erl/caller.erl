-module(caller).
-export([go/1]).
%% Calls a module that exists on no code path.
go(X) -> missing_dep_mod:run(X).
