-module(g_unknown).
-export([outer/1]).
%% the caller passes a value whose type the compiler does not know
outer(X) -> inner(erlang:element(1, X)).
inner(N) when is_integer(N) -> N + 1.
