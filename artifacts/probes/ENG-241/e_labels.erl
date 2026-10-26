-module(e_labels).
-export([pub/1, caller/1]).
pub(N) when is_integer(N) -> N + 1.
caller(X) -> pub(X).
