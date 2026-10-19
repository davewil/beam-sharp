-module(dead).
-export([f/1]).
f(_) -> 1;
f(#{'Kind' := a}) -> 2.
