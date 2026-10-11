-module(ent3).
-export([a/1, b/1]).
%% two LOCAL guarded fns; loc_known is only called with values erlc can type, loc_unknown with one it cannot.
loc_known(X) when is_integer(X) -> X + 1.
loc_unknown(X) when is_integer(X) -> X + 1.
a(L) -> loc_known(length(L)).
b(L) -> loc_unknown(hd(L)).
