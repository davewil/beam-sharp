-module(ent).
-export([pub/1, via_local/1, via_known/1, via_pub/1]).
%% pub/1: exported, guarded.  loc/1: local, guarded.
pub(X) when is_integer(X) -> X + 1.
loc(X) when is_integer(X) -> X + 1.
%% a local call from inside the module with a value erlc cannot type:
via_local(L) -> loc(hd(L)).
%% a local call with a value erlc CAN type (result of integer +):
via_known(L) -> loc(length(L)).
%% a LOCAL call to the EXPORTED, guarded pub/1:
via_pub(L) -> pub(hd(L)).
