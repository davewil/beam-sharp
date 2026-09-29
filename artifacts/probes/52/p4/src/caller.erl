-module(caller).
-export([f/0]).
%% an attribute a -required-app style declaration would use; erlc has no such attribute
-required_app(nope_app).
f() -> 'Elixir.Nope':count([1,2,3]).
