-module(st).
-export([f/1]).
g(0) -> erlang:error(boom);
g(N) -> N + 1.
f(X) -> g(X) + 1.
