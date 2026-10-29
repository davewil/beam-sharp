-module(e).
-export([g/1, p/1, h/1, k/1]).
g(X) when X >= -5, X =< 5 -> in;
g(_) -> out.
p(-5) -> m5;
p(_) -> o.
h(X) when X >= 2 - 7 -> ok;     %% arithmetic comparand in a guard
h(_) -> no.
k(X) when X >= - -5 -> ok;
k(_) -> no.
