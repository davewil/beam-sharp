-module(st).
-export([f/1]).
h(X) when X > 0 -> X.
f(X) -> h(X) + 1.
