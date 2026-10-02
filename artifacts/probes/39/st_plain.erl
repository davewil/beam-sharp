-module(st_plain).
-export([f/1]).
h(X) -> X + 1.
g(X) -> h(X) * 2.
f(X) -> g(X) + 0.
