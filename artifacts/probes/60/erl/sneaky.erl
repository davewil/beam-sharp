-module(sneaky).
%% Calls callee only through variables: invisible to a purely static who-calls-whom check.
-export([go/1]).
go(X) -> M = callee, F = list_to_atom("f"), M:F(X).
