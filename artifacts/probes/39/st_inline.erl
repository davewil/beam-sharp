-module(st_inline).
-export([f/1]).
-compile(inline).
h(X) -> X + 1.
g(X) -> h(X) * 2.
f(X) -> g(X) + 0.
